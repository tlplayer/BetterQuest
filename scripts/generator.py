"""
generator.py
------------
All TTS audio generation logic.  No Lua reading/writing, no CSV I/O.

Public API
----------
build_ref_codes(samples_root)  -> dict
generate_audio(df, tts, ref_codes, npc_lookup, config, opts)
"""

import gc
import os
import re
import time
from pathlib import Path

import pandas as pd
import soundfile as sf
import torch

from db_adapter import (
    get_wav_duration_seconds,
    update_lua_database_incremental,
)
from utils import (
    create_dialog_signature,
    create_text_hash,
    normalize_dialog_text,
    normalize_name,
    sanitize_filename,
)

# ---------------------------------------------------------------------------
# REFERENCE AUDIO DISCOVERY
# ---------------------------------------------------------------------------

def build_ref_codes(samples_root="../samples"):
    """
    Scan samples_root for .wav files.
    Returns { narrator_name: { "audio_path": str } }
    """
    ref_codes = {}
    if not os.path.isdir(samples_root):
        return ref_codes
    for filename in os.listdir(samples_root):
        if filename.endswith(".wav"):
            name = filename[:-4]
            ref_codes[name] = {"audio_path": os.path.join(samples_root, filename)}
    return ref_codes


# ---------------------------------------------------------------------------
# TEXT CHUNKING
# ---------------------------------------------------------------------------

def chunk_text_robust(text, min_chars=150, max_chars=300):
    """
    Split text into TTS-friendly chunks of roughly min_chars–max_chars characters.
    Respects sentence boundaries (.?!;…).  Merges short trailing sentences.
    """
    if not text:
        return []

    sentence_pattern = r'.*?(?:\.\.\.|[.?!;]|$)'
    sentences = [s.strip() for s in re.findall(sentence_pattern, text, flags=re.DOTALL) if s.strip()]

    chunks = []
    current = ""

    for sentence in sentences:
        if len(sentence) > max_chars:
            words = sentence.split()
            temp  = ""
            for word in words:
                if len(temp) + len(word) + 1 > max_chars:
                    if temp:
                        chunks.append(temp.strip())
                    temp = word
                else:
                    temp += (" " + word) if temp else word
            sentence = temp if temp else ""
            if not sentence:
                continue

        if len(current) + len(sentence) + 1 > max_chars:
            if current:
                chunks.append(current.strip())
            current = sentence
        else:
            current += (" " + sentence) if current else sentence

    if current:
        chunks.append(current.strip())

    # Merge short trailing chunks
    final = []
    for chunk in chunks:
        if final and len(chunk) < min_chars:
            final[-1] += " " + chunk
        else:
            final.append(chunk)

    return final


# ---------------------------------------------------------------------------
# GPU UTILITIES
# ---------------------------------------------------------------------------

def get_gpu_memory_info():
    """
    Return { allocated_gb, reserved_gb, total_gb, usage_percent } or None.
    """
    if not torch.cuda.is_available():
        return None
    allocated = torch.cuda.memory_allocated() / 1024**3
    reserved  = torch.cuda.memory_reserved()  / 1024**3
    total     = torch.cuda.get_device_properties(0).total_memory / 1024**3
    return {
        "allocated_gb":   allocated,
        "reserved_gb":    reserved,
        "total_gb":       total,
        "usage_percent":  allocated / total if total > 0 else 0,
    }


def wait_for_gpu_memory(threshold=0.85, wait_seconds=5, max_retries=10):
    """
    Block until GPU usage drops below threshold.
    Returns True if threshold met, False if max_retries exhausted.
    """
    if not torch.cuda.is_available():
        return True

    for attempt in range(max_retries):
        info = get_gpu_memory_info()
        if info["usage_percent"] < threshold:
            if attempt > 0:
                print(f"[GPU] Memory freed: {info['allocated_gb']:.2f}/{info['total_gb']:.2f} GB")
            return True
        print(f"[GPU] {info['allocated_gb']:.2f}/{info['total_gb']:.2f} GB  ({info['usage_percent']*100:.1f}%)  waiting {wait_seconds}s…")
        gc.collect()
        torch.cuda.empty_cache()
        time.sleep(wait_seconds)

    print("[GPU] WARNING: still high after max retries, proceeding anyway.")
    return False


# ---------------------------------------------------------------------------
# NARRATOR SELECTION
# ---------------------------------------------------------------------------

def get_narrator_for_row(row, npc_lookup, ref_codes, narrator_override=None):
    """
    Resolve the narrator key for a row.
    Returns a key present in ref_codes, or None if no match.
    """
    if narrator_override and narrator_override in ref_codes:
        return narrator_override

    dialog_type = str(row.get("dialog_type", "")).lower()

    if dialog_type in ("book", "item_text") and npc_lookup == None:
        if "narrator" in ref_codes:
            return "narrator"
        print("[SKIP] No 'narrator' voice sample.")
        return None

    npc_name = row.get("npc_name")
    if npc_name:
        npc_name = npc_name.replace("'", "").replace("\u2019", "")
    meta = npc_lookup.get(npc_name)

    if not meta:
        print(f"[SKIP] No metadata for NPC: {npc_name}")
        return None

    race = meta.get("race")
    sex  = meta.get("sex")

    if not race:
        print(f"[SKIP] Missing race/sex for NPC: {npc_name}")
        return None


    narrator = f"{race}".lower()

    if sex:
        narrator += f"_{sex}"

    if narrator in ref_codes:
        return narrator

    if race.lower() in ref_codes:
        return race.lower()

    print(f"[SKIP] No voice sample for narrator '{narrator}' ({npc_name})")
    return None


# ---------------------------------------------------------------------------
# DEDUPLICATION (pre-generation pass)
# ---------------------------------------------------------------------------

def deduplicate_dialogs(df, npc_lookup):
    """
    Mark rows that share (original_text, race, sex) with an earlier row.
    Adds columns: skip_generation (bool), link_to_npc (str | None).
    """
    print("[DEDUP] Scanning for duplicate dialogs…")

    df = df.copy()
    df["skip_generation"] = False
    df["link_to_npc"]     = None

    seen = {}  # sig_hash → npc_name

    for idx, row in df.iterrows():
        npc_name = row.get("npc_name")
        if not npc_name:
            continue
        meta = npc_lookup.get(npc_name)
        if not meta:
            continue
        race = meta.get("race")
        sex  = meta.get("sex")
        if not race or not sex:
            continue

        text = row.get("text", "").strip()
        if not text:
            continue

        h = create_dialog_signature(text, race, sex)

        if h in seen:
            df.at[idx, "skip_generation"] = True
            df.at[idx, "link_to_npc"]     = seen[h]
        else:
            seen[h] = npc_name

    dupes  = df["skip_generation"].sum()
    unique = len(seen)
    print(f"[DEDUP] {unique} unique  |  {dupes} duplicates skipped")
    return df


# ---------------------------------------------------------------------------
# GOSSIP INDEX  (used to look up gossip line positions)
# ---------------------------------------------------------------------------

def build_gossip_index_map(df):
    """
    Return { npc_name: [text, ...] } for all gossip-type rows.
    """
    gossip_map = {}
    for _, row in df.iterrows():
        npc_name = row.get("npc_name")
        if not npc_name:
            continue
        if "gossip" not in str(row.get("dialog_type", "")).lower():
            continue
        text = row.get("text", "")
        if not text:
            continue
        gossip_map.setdefault(npc_name, [])
        if text not in gossip_map[npc_name]:
            gossip_map[npc_name].append(text)
    return gossip_map


# ---------------------------------------------------------------------------
# ITEM-TEXT MERGING
# ---------------------------------------------------------------------------

def merge_item_text_rows(df):
    """
    Collapse multiple item_text rows for the same NPC into a single row.
    Leaves all other dialog types untouched.
    """
    item_mask  = df["dialog_type"].str.lower() == "item_text"
    item_rows  = df[item_mask]
    merged     = []
    seen_texts = set()

    for _, group in item_rows.groupby("npc_name"):
        texts = [t for t in group["text"] if t not in seen_texts]
        for t in texts:
            seen_texts.add(t)
        if not texts:
            continue
        row = group.iloc[0].copy()
        row["text"] = " ".join(texts).strip()
        merged.append(row)

    df = df[~item_mask]
    if merged:
        df = pd.concat([df, pd.DataFrame(merged)], ignore_index=True)
    return df


# ---------------------------------------------------------------------------
# SINGLE-ROW GENERATION
# ---------------------------------------------------------------------------

# Module-level dedup set shared across all rows in a single pipeline run.
# Reset by generate_audio() at the start of each run.
_seen_quest_id_dialog_type = set()

SAMPLE_RATE = 24000


def generate_tts_for_row(
    row,
    tts,
    ref_codes,
    npc_lookup,
    sounds_dir,
    *,
    narrator_override=None,
    regenerate=False,
    cutoff_dt=None,
    incremental_sync=False,
    max_retries=3,
    retry_wait=10,
    config=None,
):
    """
    Generate and write a single WAV file for one dialog row.

    Returns:
        filepath  – path to the written file (may be an existing file if skipped)
        None      – no narrator resolved or generation failed
        'SKIPPED_DUPLICATE' – row marked skip_generation by deduplicate_dialogs()
    """
    global _seen_quest_id_dialog_type

    if row.get("skip_generation", False):
        #print(f"[SKIP-DEDUP] {row['npc_name']} → {row.get('link_to_npc', '?')}")
        return "SKIPPED_DUPLICATE"

    narrator_voice = get_narrator_for_row(row, npc_lookup, ref_codes, narrator_override)
    if not narrator_voice:
        return None

    # folder_race uses the natural voice (ignoring narrator_override) for path structure
    folder_race = get_narrator_for_row(row, npc_lookup, ref_codes, narrator_override=None) or narrator_voice

    npc_name    = row.get("npc_name") or "narrator"
    dialog_type = row.get("dialog_type", "gossip").lower()

    # ------------------------------------------------------------------
    # Resolve output filepath (must mirror sync_metadata path logic)
    # ------------------------------------------------------------------
    quest_id     = None
    has_quest_id = False

    if dialog_type in ("book", "item_text"):
        base_dir = os.path.join(sounds_dir, folder_race)
        filename = f"{sanitize_filename(npc_name)}.wav"
    else:
        npc_dirname = sanitize_filename(npc_name)
        base_dir    = os.path.join(sounds_dir, folder_race, npc_dirname)

        qid = row.get("quest_id")
        has_quest_id = (
            pd.notna(qid)
            and str(qid).replace(".", "").isdigit()
            and int(qid) > 0
        )

        if has_quest_id and dialog_type != "gossip":
            quest_id  = int(qid)
            dedup_key = f"{folder_race}_{quest_id}_{dialog_type}.wav"
            if dedup_key not in _seen_quest_id_dialog_type:
                _seen_quest_id_dialog_type.add(dedup_key)
                filename = f"{quest_id}_{dialog_type}.wav"
            else:
                # Downgrade: second occurrence of same quest_id+dialog_type
                quest_id    = None
                dialog_type = "gossip"
                clean       = sanitize_filename(row["text"])
                filename    = f"{clean[:50]}.wav" if clean else None
                if not filename:
                    return None
        else:
            clean    = sanitize_filename(row["text"])
            filename = f"{clean[:50]}.wav" if clean else None
            if not filename:
                return None

    os.makedirs(base_dir, exist_ok=True)
    filepath = os.path.join(base_dir, filename)


    # ------------------------------------------------------------------
    # Decide whether to (re)generate
    # ------------------------------------------------------------------
    if os.path.exists(filepath):
        if os.path.getsize(filepath) == 0:
            os.remove(filepath)
            print(f"[REGEN] Removed zero-byte file: {filepath}")
        elif cutoff_dt is not None:
            import datetime as _dt
            mtime = _dt.datetime.fromtimestamp(os.path.getmtime(filepath))
            if mtime >= cutoff_dt:
                _maybe_incremental_sync(
                    incremental_sync, npc_name, row, filepath, dialog_type, quest_id, has_quest_id, npc_lookup, config
                )
                return filepath
            else:
                os.remove(filepath)
                print(f"[REGEN] Older than cutoff ({mtime.date()}): {filepath}")
        elif not regenerate:
            _maybe_incremental_sync(
                incremental_sync, npc_name, row, filepath, dialog_type, quest_id, has_quest_id, npc_lookup, config
            )
            return filepath
        # else: regenerate=True and no cutoff — fall through

    # ------------------------------------------------------------------
    # TTS generation with retry logic
    # ------------------------------------------------------------------
    print(f"[GEN] {filepath}  (voice: {narrator_voice})")
    ref        = ref_codes[narrator_voice]
    text_chunks = chunk_text_robust(row["text"])
    if not text_chunks:
        return None

    for attempt in range(max_retries):
        try:
            with sf.SoundFile(filepath, mode="w", samplerate=SAMPLE_RATE, channels=1, subtype="PCM_16") as f:
                with torch.no_grad():
                    for chunk_idx, chunk in enumerate(text_chunks):
                        wav = tts.generate(chunk, audio_prompt_path=ref["audio_path"])
                        if isinstance(wav, torch.Tensor):
                            wav = wav.detach().cpu().numpy()
                        wav = wav.squeeze()
                        wav = (wav * 32767).clip(-32768, 32767).astype("int16")
                        f.write(wav)
                        del wav
                        torch.cuda.empty_cache()

            if incremental_sync:
                quest_id_for_sync = quest_id if (has_quest_id and dialog_type != "gossip") else None
                update_lua_database_incremental(
                    npc_name=npc_name,
                    dialog_text=row.get("text", ""),
                    audio_filepath=filepath,
                    dialog_type=dialog_type,
                    quest_id=quest_id_for_sync,
                    npc_lookup=npc_lookup,
                    config=config,
                )

            return filepath

        except RuntimeError as e:
            is_oom = "out of memory" in str(e).lower() or "cuda" in str(e).lower()
            if is_oom and attempt < max_retries - 1:
                print(f"[RETRY] OOM on attempt {attempt+1}/{max_retries}. Waiting {retry_wait}s…")
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                    torch.cuda.synchronize()
                gc.collect()
                time.sleep(retry_wait)
                if os.path.exists(filepath):
                    os.remove(filepath)
                continue
            print(f"[ERROR] Generation failed after {attempt+1} attempts: {e}")
            if os.path.exists(filepath):
                os.remove(filepath)
            return None

        except Exception as e:
            print(f"[ERROR] Unexpected error: {e}")
            if os.path.exists(filepath):
                os.remove(filepath)
            return None

    return None


def _maybe_incremental_sync(incremental_sync, npc_name, row, filepath, dialog_type, quest_id, has_quest_id, npc_lookup, config):
    if not incremental_sync:
        return
    quest_id_for_sync = quest_id if (has_quest_id and dialog_type != "gossip") else None
    update_lua_database_incremental(
        npc_name=npc_name,
        dialog_text=row.get("text", ""),
        audio_filepath=filepath,
        dialog_type=dialog_type,
        quest_id=quest_id_for_sync,
        npc_lookup=npc_lookup,
        config=config,
    )


# ---------------------------------------------------------------------------
# BATCH GENERATION
# ---------------------------------------------------------------------------

def generate_audio(
    df,
    tts,
    ref_codes,
    npc_lookup,
    sounds_dir,
    *,
    regenerate=False,
    narrator_override=None,
    gpu_threshold=0.85,
    gpu_wait=5,
    gpu_check_interval=1000,
    max_retries=3,
    retry_wait=10,
    incremental_sync=False,
    time_cutoff=None,
    config=None,
):
    """
    Generate TTS audio for every row in df.

    Parameters
    ----------
    df               : DataFrame with columns npc_name, dialog_type, text, quest_id, …
    tts              : Initialized ChatterboxTurboTTS instance
    ref_codes        : { narrator: { audio_path } } from build_ref_codes()
    npc_lookup       : { npc_name: meta } from load_npc_metadata()
    sounds_dir       : Root directory for audio output
    regenerate       : Overwrite all existing files
    narrator_override: Force a specific narrator key
    gpu_threshold    : Fraction of VRAM before we pause
    gpu_wait         : Seconds to sleep when VRAM is high
    gpu_check_interval: Check VRAM every N rows
    max_retries      : Per-row retry attempts on OOM
    retry_wait       : Seconds between retries
    incremental_sync : Update Lua DB after each file (live VO)
    time_cutoff      : 'YYYY-MM-DD' string; regenerate files older than this date
    config           : Config dict forwarded to adapter_db helpers
    """
    print("\n=== STEP 2: Generating TTS audio ===")
    

    # Reset per-run dedup state
    global _seen_quest_id_dialog_type
    _seen_quest_id_dialog_type = set()

    # Parse time cutoff once
    cutoff_dt = None
    if time_cutoff:
        import datetime as _dt
        try:
            cutoff_dt = _dt.datetime.strptime(time_cutoff, "%Y-%m-%d")
            print(f"[TIME] Regenerating files older than: {cutoff_dt.date()}")
        except ValueError:
            print(f"[ERROR] Invalid --time value '{time_cutoff}'. Ignoring.")

    if torch.cuda.is_available():
        info = get_gpu_memory_info()
        print(
            f"[GPU] {info['allocated_gb']:.2f}/{info['total_gb']:.2f} GB  "
            f"threshold={gpu_threshold*100:.0f}%  "
            f"check_interval={gpu_check_interval}"
        )

    missing_narrators = []
    files_processed   = 0

    for idx, row in df.iterrows():
        if torch.cuda.is_available() and files_processed > 0 and files_processed % gpu_check_interval == 0:
            info = get_gpu_memory_info()
            print(f"[GPU] {files_processed} files  {info['allocated_gb']:.2f}/{info['total_gb']:.2f} GB")
            if info["usage_percent"] >= gpu_threshold:
                wait_for_gpu_memory(threshold=gpu_threshold, wait_seconds=gpu_wait)

        result = generate_tts_for_row(
            row,
            tts,
            ref_codes,
            npc_lookup,
            sounds_dir,
            narrator_override=narrator_override,
            regenerate=regenerate,
            cutoff_dt=cutoff_dt,
            incremental_sync=incremental_sync,
            max_retries=max_retries,
            retry_wait=retry_wait,
            config=config,
        )

        if result and result != "SKIPPED_DUPLICATE":
            files_processed += 1
        elif result is None:
            missing_narrators.append({
                "npc_name":    row.get("npc_name"),
            })

    if missing_narrators:
        import pandas as _pd
        missing_csv = os.path.join("../data", "missing_narrators.csv")
        _pd.DataFrame(missing_narrators).drop_duplicates(subset=["npc_name"]).to_csv(missing_csv, index=False)
        print(f"[WARN] {len(missing_narrators)} rows with no narrator → {missing_csv}")

    if torch.cuda.is_available():
        info = get_gpu_memory_info()
        print(f"[GPU] Final: {info['allocated_gb']:.2f}/{info['total_gb']:.2f} GB")

    print(f"[OK] Audio generation complete ({files_processed} files written)")