"""
adapter_db.py
-------------
Owns all metadata I/O:
  - Loading NPC_LOOKUP from npc_metadata.json + YAML overrides
  - Building and writing npc_database.lua (sync_metadata)
  - Incremental (per-file) Lua DB updates during live generation

Public API
----------
load_npc_metadata(json_path, race_file, sex_file, zone_file) -> dict
sync_metadata(df, npc_lookup, config)
update_lua_database_incremental(npc_name, dialog_text, audio_filepath,
                                 dialog_type, quest_id, npc_lookup, config)
load_existing_lua_database(output_lua) -> dict
get_wav_duration_seconds(path) -> float | None
"""

import contextlib
import fcntl
import json
import os
import re
import wave
from pathlib import Path

import pandas as pd
import yaml

from utils import (
    create_dialog_signature,
    create_text_hash,
    normalize_name,
    sanitize_filename,
)

# ---------------------------------------------------------------------------
# CONSTANTS  (callers may override via config dict)
# ---------------------------------------------------------------------------

SEX_MAP = {0: "male", 1: "female"}

_DEFAULT_CONFIG = {
    "npc_metadata_json": "../data/npc_metadata.json",
    "race_file":         "../data/npc_race.yaml",
    "sex_file":          "../data/npc_sex.yaml",
    "zone_file":         "../data/npc_zone.yaml",
    "missing_race_file": "../data/missing_race.yaml",
    "output_lua":        "../db/npc_database.lua",
    "sounds_dir":        "../sounds",
}


# ---------------------------------------------------------------------------
# WAV UTILITIES
# ---------------------------------------------------------------------------

def get_wav_duration_seconds(path):
    """Return WAV duration in seconds, or None on error."""
    try:
        with contextlib.closing(wave.open(str(path), "rb")) as wf:
            return round(wf.getnframes() / wf.getframerate(), 3)
    except Exception:
        return None


# ---------------------------------------------------------------------------
# YAML HELPERS
# ---------------------------------------------------------------------------

def _read_yaml(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def invert_mapping(mapping):
    """
    Convert { category: [name, ...] } → { normalized_name: category }.
    Handles both list and bare-string values.
    """
    inverted = {}
    for key, names in mapping.items():
        if isinstance(names, list):
            for name in names:
                n = normalize_name(name)
                if n:
                    inverted[n] = key
        elif isinstance(names, str):
            n = normalize_name(names)
            if n:
                inverted[n] = key
    return inverted


# ---------------------------------------------------------------------------
# METADATA LOADING
# ---------------------------------------------------------------------------

def _merge_yaml_into_lookup(lookup, yaml_path, field):
    """Merge a race/sex/zone YAML file into the lookup dict (in-place)."""
    if not os.path.exists(yaml_path):
        return
    mapping = _read_yaml(yaml_path)
    for value, npc_names in mapping.items():
        if isinstance(npc_names, str):
            npc_names = [npc_names]
        if not isinstance(npc_names, list):
            continue
        for raw in npc_names:
            normalized = raw.strip().replace('"', '').replace("'", "")
            if normalized not in lookup:
                lookup[normalized] = {"name": normalized}
            lookup[normalized][field] = value


def load_npc_metadata(
    json_path=None,
    race_file=None,
    sex_file=None,
    zone_file=None,
    config=None,
):
    """
    Build and return the NPC lookup dict:  { npc_name: { race, sex, zone, ... } }

    YAML files are applied after JSON and act as source of truth for their fields.
    Accepts explicit paths or pulls defaults from config/_DEFAULT_CONFIG.
    """
    cfg = {**_DEFAULT_CONFIG, **(config or {})}
    json_path = json_path or cfg["npc_metadata_json"]
    race_file  = race_file  or cfg["race_file"]
    sex_file   = sex_file   or cfg["sex_file"]
    zone_file  = zone_file  or cfg["zone_file"]

    with open(json_path, "r", encoding="utf-8") as f:
        metadata = json.load(f)

    if isinstance(metadata, list):
        lookup = {npc["name"]: npc for npc in metadata}
    elif isinstance(metadata, dict):
        lookup = {name: {"name": name, **meta} for name, meta in metadata.items()}
    else:
        raise ValueError("npc_metadata.json has an unsupported format")

    _merge_yaml_into_lookup(lookup, race_file, "race")
    _merge_yaml_into_lookup(lookup, sex_file,  "sex")
    _merge_yaml_into_lookup(lookup, zone_file, "zone")

    return lookup


# ---------------------------------------------------------------------------
# LUA DB — CACHE LOAD
# ---------------------------------------------------------------------------

def load_existing_lua_database(output_lua=None, config=None):
    """
    Parse the existing npc_database.lua and return:
        { npc_name: set(dialog_hash, ...) }
    Returns {} if file does not exist or parsing fails.
    """
    cfg = {**_DEFAULT_CONFIG, **(config or {})}
    output_lua = output_lua or cfg["output_lua"]

    if not os.path.exists(output_lua):
        return {}

    print("[CACHE] Loading existing Lua database...")
    db_cache = {}

    try:
        with open(output_lua, "r", encoding="utf-8") as f:
            content = f.read()

        npc_pattern = r'\["([^"]+)"\]\s*=\s*\{'
        for match in re.finditer(npc_pattern, content):
            npc_name  = match.group(1)
            npc_start = match.end()

            dialogs_pos = content.find("dialogs = {", npc_start)
            if dialogs_pos == -1:
                continue
            dialogs_start = dialogs_pos + len("dialogs = {")
            dialogs_end   = content.find("},", dialogs_start)
            if dialogs_end == -1:
                continue

            hashes = set(re.findall(r'\["([^"]+)"\]\s*=', content[dialogs_start:dialogs_end]))
            if hashes:
                db_cache[npc_name] = hashes

        print(f"[CACHE] {len(db_cache)} NPCs loaded")
    except Exception as e:
        print(f"[CACHE] Load failed: {e}")

    return db_cache


# ---------------------------------------------------------------------------
# PATH CONVERSION
# ---------------------------------------------------------------------------

def sound_path_to_fs(sound_path):
    """Convert Interface\\AddOns\\BetterQuest\\… Lua path to a filesystem Path."""
    parts = sound_path.split("BetterQuest\\", 1)
    if len(parts) != 2:
        return None
    return Path("..") / parts[1].replace("\\", "/")


def _fs_path_to_lua(filepath, sounds_dir):
    """
    Convert a filesystem path like ../sounds/human/guard/halt.wav
    to Interface\\AddOns\\BetterQuest\\sounds\\human\\guard\\halt.wav (double-escaped).
    """
    rel = os.path.relpath(filepath, start=os.path.dirname(sounds_dir))
    parts = Path(rel).parts
    # Drop the leading '..' that relpath may introduce
    if parts and parts[0] == "..":
        parts = parts[1:]
    return "Interface\\\\AddOns\\\\BetterQuest\\\\sounds\\\\" + "\\\\".join(parts[1:])


# ---------------------------------------------------------------------------
# INCREMENTAL LUA DB UPDATE
# ---------------------------------------------------------------------------

def update_lua_database_incremental(
    npc_name,
    dialog_text,
    audio_filepath,
    dialog_type,
    quest_id,
    npc_lookup,
    config=None,
):
    """
    Append a single new dialog entry to npc_database.lua immediately after
    audio generation, enabling in-game /reload access without a full sync.

    Uses file locking to prevent corruption under concurrent writes.
    """
    cfg = {**_DEFAULT_CONFIG, **(config or {})}
    output_lua   = cfg["output_lua"]
    race_file    = cfg["race_file"]
    sex_file     = cfg["sex_file"]
    zone_file    = cfg["zone_file"]

    normalized_name = normalize_name(npc_name)
    meta = npc_lookup.get(npc_name)
    if not meta:
        return

    npc_race = invert_mapping(_read_yaml(race_file)) if os.path.exists(race_file) else {}
    npc_sex  = invert_mapping(_read_yaml(sex_file))  if os.path.exists(sex_file)  else {}
    npc_zone = invert_mapping(_read_yaml(zone_file)) if os.path.exists(zone_file) else {}

    race     = npc_race.get(normalized_name) or meta.get("race")
    sex      = meta.get("sex") or npc_sex.get(normalized_name, "male")
    zone     = npc_zone.get(normalized_name, "")
    model_id = meta.get("model_id")

    narrator = f"{race}_female" if (race and sex == "female") else (race or "narrator")
    portrait = race or "default"

    text_hash      = create_text_hash(dialog_text)
    lua_sound_path = _fs_path_to_lua(audio_filepath, cfg["sounds_dir"])

    seconds = 0.0
    try:
        dur = get_wav_duration_seconds(Path(audio_filepath))
        if dur is not None:
            seconds = dur
    except Exception:
        pass

    lock_file = output_lua + ".lock"

    try:
        with open(lock_file, "w") as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)

            if os.path.exists(output_lua):
                with open(output_lua, "r", encoding="utf-8") as f:
                    lua_content = f.read()
            else:
                lua_content = (
                    "-- Auto-generated unified NPC database\n"
                    "-- DO NOT EDIT MANUALLY\n\n"
                    "NPC_DATABASE = {\n}\n"
                )

            npc_marker = f'["{normalized_name}"] = {{'

            if npc_marker in lua_content:
                npc_start     = lua_content.find(npc_marker)
                dialogs_start = lua_content.find("dialogs = {", npc_start)
                if dialogs_start != -1:
                    dialogs_content_start = dialogs_start + len("dialogs = {")
                    dialogs_end = lua_content.find("},", dialogs_content_start)
                    quest_id_str = str(quest_id) if quest_id is not None else "nil"
                    entry = (
                        f'      ["{text_hash}"] = {{ '
                        f'path="{lua_sound_path}", '
                        f'dialog_type="{dialog_type}", '
                        f'quest_id={quest_id_str}, '
                        f'seconds={seconds} }},\n'
                    )
                    lua_content = lua_content[:dialogs_end] + entry + lua_content[dialogs_end:]
            else:
                quest_id_lua = quest_id if quest_id is not None else "nil"
                npc_entry = (
                    f'  ["{normalized_name}"] = {{\n'
                    f'    race = "{race or ""}",\n'
                    f'    sex = "{sex}",\n'
                    f'    portrait = "{portrait}",\n'
                    f'    zone = "{zone}",\n'
                    f'    model_id = {model_id if model_id else "nil"},\n'
                    f'    narrator = "{narrator}",\n'
                    f'    dialogs = {{\n'
                    f'      ["{text_hash}"] = {{ '
                    f'path="{lua_sound_path}", '
                    f'dialog_type="{dialog_type}", '
                    f'quest_id={quest_id_lua}, '
                    f'seconds={seconds} }},\n'
                    f'    }},\n'
                    f'  }},\n'
                )
                insert_pos  = lua_content.rfind("}")
                lua_content = lua_content[:insert_pos] + npc_entry + lua_content[insert_pos:]

            with open(output_lua, "w", encoding="utf-8") as f:
                f.write(lua_content)

            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)

        os.remove(lock_file)
        print(f"[LIVE-VO] {normalized_name} → {text_hash[:16]}... ready")

    except Exception as e:
        print(f"[LIVE-VO] Failed: {e}")
        if os.path.exists(lock_file):
            try:
                os.remove(lock_file)
            except Exception:
                pass


# ---------------------------------------------------------------------------
# FULL METADATA SYNC  (end-of-pipeline batch write)
# ---------------------------------------------------------------------------

def sync_metadata(df, npc_lookup, config=None):
    """
    Build and write npc_database.lua from the full dialog CSV dataframe.

    Includes ALL NPCs from npc_lookup (even those without generated audio)
    so the game client has complete metadata.  Dialog entries are only added
    when the corresponding .wav file exists on disk.

    Deduplicates dialogs that share the same text+race+sex by setting a
    linked_to pointer to the first NPC's audio path.
    """
    print("\n=== STEP 3: Syncing metadata to Lua database ===")

    cfg = {**_DEFAULT_CONFIG, **(config or {})}
    output_lua        = cfg["output_lua"]
    race_file         = cfg["race_file"]
    sex_file          = cfg["sex_file"]
    zone_file         = cfg["zone_file"]
    missing_race_file = cfg["missing_race_file"]

    npc_race = invert_mapping(_read_yaml(race_file)) if os.path.exists(race_file) else {}
    npc_sex  = invert_mapping(_read_yaml(sex_file))  if os.path.exists(sex_file)  else {}
    npc_zone = invert_mapping(_read_yaml(zone_file)) if os.path.exists(zone_file) else {}

    # Merge item_text rows into a single entry per NPC/item
    item_mask = df["dialog_type"].str.lower().isin(["item_text", "book"])
    item_rows = df[item_mask]
    merged_rows = []
    seen_text_blocks = set()
    for _, group in item_rows.groupby("npc_name"):
        merged = [t for t in group["text"] if t not in seen_text_blocks]
        for t in merged:
            seen_text_blocks.add(t)
        if not merged:
            continue
        row = group.iloc[0].copy()
        row["text"] = " ".join(merged).strip()
        merged_rows.append(row)

    df = df[~item_mask]
    if merged_rows:
        df = pd.concat([df, pd.DataFrame(merged_rows)], ignore_index=True)

    # ------------------------------------------------------------------
    # Build NPC database skeleton from ALL metadata entries
    # ------------------------------------------------------------------
    npc_database  = {}
    missing_races = {"unknown": []}

    def _make_npc_entry(name_key, race, sex, zone, model_id):
        narrator = f"{race}_female" if (race and sex == "female") else (race or "narrator")
        portrait = race or "default"
        return {
            "race":     race,
            "sex":      sex,
            "portrait": portrait,
            "zone":     zone,
            "model_id": model_id,
            "narrator": narrator,
            "dialogs":  {},
        }

    for npc_name, meta in npc_lookup.items():
        key = normalize_name(npc_name)
        if not key:
            continue
        race     = npc_race.get(key) or meta.get("race")
        sex      = meta.get("sex") or npc_sex.get(key, "male")
        zone     = npc_zone.get(key, "")
        model_id = meta.get("model_id")
        if not race:
            missing_races["unknown"].append(npc_name)
        npc_database[key] = _make_npc_entry(key, race, sex, zone, model_id)

    # ------------------------------------------------------------------
    # Populate dialogs from CSV rows
    # ------------------------------------------------------------------
    dialog_signature_map = {}        # sig → (npc_name, text_hash, sound_path)
    seen_quest_id_dialog_type = set()  # mirrors TTS generator's dedup key

    for _, row in df.iterrows():
        npc_name = normalize_name(row.get("npc_name"))
        if not npc_name:
            continue

        # Add entry for NPCs not in metadata
        if npc_name not in npc_database:
            race = npc_race.get(npc_name)
            raw_sex = row.get("sex")
            sex = (
                SEX_MAP.get(int(raw_sex))
                if (pd.notna(raw_sex) and str(raw_sex).isdigit())
                else npc_sex.get(npc_name, "male")
            )
            zone     = npc_zone.get(npc_name, "")
            raw_mid  = row.get("model_id")
            model_id = int(raw_mid) if (pd.notna(raw_mid)) else None
            if not race:
                missing_races["unknown"].append(npc_name)
            npc_database[npc_name] = _make_npc_entry(npc_name, race, sex, zone, model_id)

        entry    = npc_database[npc_name]
        narrator = entry["narrator"]
        race     = entry["race"]
        sex      = entry["sex"]

        dialog_type = str(row.get("dialog_type", "gossip")).lower()
        text        = row.get("text", "")
        text_hash   = create_text_hash(text)
        npc_dirname = sanitize_filename(npc_name)

        if not text_hash:
            continue

        # Build expected filesystem / Lua path (mirrors generator logic)
        quest_id    = None
        if dialog_type in ("book", "item_text"):
            filename   = f"{npc_dirname}.wav"
            sound_path = (
                f"Interface\\AddOns\\BetterQuest\\sounds\\"
                f"{narrator}\\{filename}"
            )
        else:
            qid         = row.get("quest_id")
            has_quest_id = (
                pd.notna(qid)
                and str(qid).replace(".", "").isdigit()
                and int(qid) > 0
            )
            if has_quest_id and dialog_type != "gossip":
                quest_id    = int(qid)
                dedup_key   = f"{narrator}_{quest_id}_{dialog_type}.wav"
                if dedup_key not in seen_quest_id_dialog_type:
                    seen_quest_id_dialog_type.add(dedup_key)
                    filename = f"{quest_id}_{dialog_type}.wav"
                else:
                    quest_id    = None
                    dialog_type = "gossip"
                    clean       = sanitize_filename(text)
                    if not clean:
                        continue
                    filename = f"{clean[:50]}.wav"
            else:
                clean = sanitize_filename(text)
                if not clean:
                    continue
                filename = f"{clean[:50]}.wav"

            sound_path = (
                f"Interface\\AddOns\\BetterQuest\\sounds\\"
                f"{narrator}\\{npc_dirname}\\{filename}"
            )

        fs_path = sound_path_to_fs(sound_path)
        if not fs_path or not fs_path.exists():
            continue

        seconds = get_wav_duration_seconds(fs_path)
        if seconds is None:
            continue

        # Deduplication: link to first NPC with same text+race+sex
        original_text = row.get("text", "")
        sig = create_dialog_signature(original_text, race, sex)

        if sig in dialog_signature_map:
            existing_npc, _, existing_path = dialog_signature_map[sig]
            entry["dialogs"][text_hash] = {
                "path":        existing_path,
                "dialog_type": dialog_type,
                "quest_id":    quest_id,
                "seconds":     seconds,
                "linked_to":   existing_npc,
            }
        else:
            dialog_signature_map[sig] = (npc_name, text_hash, sound_path)
            entry["dialogs"][text_hash] = {
                "path":        sound_path,
                "dialog_type": dialog_type,
                "quest_id":    quest_id,
                "seconds":     seconds,
            }

    # ------------------------------------------------------------------
    # Write YAML for missing races
    # ------------------------------------------------------------------
    with open(missing_race_file, "w", encoding="utf-8") as f:
        yaml.dump(missing_races, f, default_flow_style=False, allow_unicode=True)

    # ------------------------------------------------------------------
    # Write Lua database
    # ------------------------------------------------------------------
    os.makedirs(os.path.dirname(output_lua), exist_ok=True)

    npcs_with_dialogs    = 0
    npcs_without_dialogs = 0
    total_dialogs        = 0
    linked_dialogs       = 0

    with open(output_lua, "w", encoding="utf-8") as f:
        f.write("-- Auto-generated unified NPC database\n")
        f.write("-- Contains metadata + dialog mappings\n")
        f.write("-- DO NOT EDIT MANUALLY\n\n")
        f.write("NPC_DATABASE = {\n")

        for npc_name, data in sorted(npc_database.items()):
            if data["dialogs"]:
                npcs_with_dialogs += 1
                total_dialogs     += len(data["dialogs"])
                linked_dialogs    += sum(1 for d in data["dialogs"].values() if "linked_to" in d)
            else:
                npcs_without_dialogs += 1

            f.write(f'  ["{npc_name}"] = {{\n')
            f.write(f'    race = "{data["race"] or ""}",\n')
            f.write(f'    sex = "{data["sex"]}",\n')
            f.write(f'    portrait = "{data["portrait"]}",\n')
            f.write(f'    zone = "{data["zone"]}",\n')
            f.write(f'    model_id = {data["model_id"] if data["model_id"] else "nil"},\n')
            f.write(f'    narrator = "{data["narrator"]}",\n')
            f.write('    dialogs = {\n')

            for text_hash, info in sorted(data["dialogs"].items()):
                path         = info["path"].replace("\\", "\\\\")
                quest_id_str = str(info["quest_id"]) if info["quest_id"] is not None else "nil"
                linked_to    = info.get("linked_to")

                if linked_to:
                    f.write(
                        f'      ["{text_hash}"] = {{ '
                        f'path="{path}", '
                        f'dialog_type="{info["dialog_type"]}", '
                        f'quest_id={quest_id_str}, '
                        f'seconds={info["seconds"]}, '
                        f'linked_to="{linked_to}" '
                        f'}},\n'
                    )
                else:
                    f.write(
                        f'      ["{text_hash}"] = {{ '
                        f'path="{path}", '
                        f'dialog_type="{info["dialog_type"]}", '
                        f'quest_id={quest_id_str}, '
                        f'seconds={info["seconds"]} '
                        f'}},\n'
                    )

            f.write('    },\n')
            f.write('  },\n')

        f.write("}\n")

    unique_dialogs = total_dialogs - linked_dialogs
    print(f"[OK] {len(npc_database)} NPCs written")
    print(f"     with dialogs:    {npcs_with_dialogs}")
    print(f"     without dialogs: {npcs_without_dialogs}")
    print(f"     total entries:   {total_dialogs}  ({linked_dialogs} linked, {unique_dialogs} unique audio)")
    print(f"[OK] Output: {output_lua}")