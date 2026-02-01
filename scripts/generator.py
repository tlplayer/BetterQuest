import io
import os
import sys
from pathlib import Path
import argparse
import re
import pandas as pd
import soundfile as sf
from pydub import AudioSegment
import json
from pydub.effects import normalize
import csv
import wave
import contextlib
import yaml

# =========================
# CONFIGURATION
# =========================

# CSV and data paths
NPC_DIALOG_CSV_PATH = "../data/all_npc_dialog.csv"
NPC_METADATA_JSON = "../data/npc_metadata.json"
RACE_FILE = "../data/npc_race.yaml"
SEX_FILE = "../data/npc_sex.yaml"
ZONE_FILE = "../data/npc_zone.yaml"
MISSING_RACE_FILE = "../data/missing_race.yaml"

# Output paths
OUTPUT_LUA = "../db/npc_database.lua"
SOUNDS_DIR = "../sounds"

# BetterQuest integration
BETTERQUEST_LUA = "../../../../WTF/Account/ADMIN/SavedVariables/BetterQuest.lua"

SEX_MAP = {0: "male", 1: "female"}

# =========================
# FILE DISCOVERY & MONITORING
# =========================

import glob
import time
from datetime import datetime

def find_betterquest_file(base_path="../../../../WTF"):
    """
    Find BetterQuest.lua file in WTF directory, account-name agnostic.
    Searches for any file matching pattern: WTF/*/SavedVariables/BetterQuest.lua
    
    Returns:
        Path to BetterQuest.lua if found, None otherwise
    """
    # Try multiple search patterns
    patterns = [
        os.path.join(base_path, "Account", "*", "SavedVariables", "BetterQuest.lua"),
        os.path.join(base_path, "*", "SavedVariables", "BetterQuest.lua"),
        os.path.join(base_path, "SavedVariables", "BetterQuest.lua"),
    ]
    
    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            # Return the first match (or most recently modified if multiple)
            if len(matches) > 1:
                matches.sort(key=lambda x: os.path.getmtime(x), reverse=True)
                print(f"[INFO] Found {len(matches)} BetterQuest.lua files, using most recent: {matches[0]}")
            return matches[0]
    
    return None

def monitor_file_changes(filepath, check_interval=5, callback=None):
    """
    Monitor a file for changes and execute callback when modified.
    
    Args:
        filepath: Path to file to monitor
        check_interval: Seconds between checks
        callback: Function to call when file changes (receives filepath as argument)
    """
    if not os.path.exists(filepath):
        print(f"[ERROR] File not found: {filepath}")
        return
    
    print(f"[DAEMON] Monitoring file: {filepath}")
    print(f"[DAEMON] Check interval: {check_interval}s")
    print(f"[DAEMON] Press Ctrl+C to stop\n")
    
    last_mtime = os.path.getmtime(filepath)
    last_processed = datetime.now()
    
    try:
        while True:
            time.sleep(check_interval)
            
            try:
                current_mtime = os.path.getmtime(filepath)
                
                if current_mtime > last_mtime:
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"\n{'='*60}")
                    print(f"[DAEMON] File modified at {timestamp}")
                    print(f"{'='*60}")
                    
                    last_mtime = current_mtime
                    
                    if callback:
                        try:
                            callback(filepath)
                        except Exception as e:
                            print(f"[ERROR] Callback failed: {e}")
                            import traceback
                            traceback.print_exc()
                    
                    last_processed = datetime.now()
                    print(f"\n[DAEMON] Waiting for next change...")
                
            except FileNotFoundError:
                print(f"[WARNING] File disappeared: {filepath}")
                print(f"[DAEMON] Waiting for file to reappear...")
                time.sleep(check_interval)
                
            except Exception as e:
                print(f"[ERROR] Monitoring error: {e}")
                time.sleep(check_interval)
                
    except KeyboardInterrupt:
        print(f"\n\n[DAEMON] Monitoring stopped by user")
        elapsed = (datetime.now() - last_processed).total_seconds() / 60
        print(f"[DAEMON] Last processed: {elapsed:.1f} minutes ago")

# =========================
# LOAD NPC METADATA
# =========================

def load_npc_metadata():
    """Load and normalize NPC metadata from JSON"""
    with open(NPC_METADATA_JSON, "r", encoding="utf-8") as f:
        metadata = json.load(f)
    
    # Normalize metadata to dict[name → meta]
    if isinstance(metadata, list):
        lookup = {npc["name"]: npc for npc in metadata}
    elif isinstance(metadata, dict):
        lookup = {
            name: {"name": name, **meta}
            for name, meta in metadata.items()
        }
    else:
        raise ValueError("npc_metadata.json has an unsupported format")
    
    return lookup

NPC_LOOKUP = load_npc_metadata()

# =========================
# INITIALIZE TTS
# =========================

import torch
import torchaudio as ta
from chatterbox.tts_turbo import ChatterboxTurboTTS

# TTS model will be initialized in main() after parsing args
tts = None

# =========================
# REFERENCE AUDIO DISCOVERY
# =========================

def discover_narrators(samples_root="../samples"):
    """
    Discover narrator reference files from the filesystem.
    Supports flat structure where .wav files are directly in samples_root.
    """
    narrators = {}

    for filename in os.listdir(samples_root):
        filepath = os.path.join(samples_root, filename)
        
        # Check if it's a .wav file directly in the samples directory
        if os.path.isfile(filepath) and filename.endswith('.wav'):
            narrator_name = filename[:-4]  # Remove .wav extension
            narrators[narrator_name] = {
                "audio": filepath,
            }

    return narrators

def build_ref_codes(samples_root="../samples"):
    narrator_refs = discover_narrators(samples_root)
    ref_codes = {}

    for narrator, paths in narrator_refs.items():
        ref_codes[narrator] = {
            "audio_path": paths["audio"],
        }

    return ref_codes

REF_CODES = build_ref_codes("../samples")

# =========================
# PART 1: SYNC GAME DATA (BetterQuest.lua)
# =========================

def _find_matching_brace(s, start_idx):
    """
    Given s[start_idx] == '{', return index of matching '}'.
    Skips over quoted strings and handles nested braces.
    Returns -1 on failure.
    """
    i = start_idx
    n = len(s)
    if i >= n or s[i] != "{":
        return -1
    depth = 0
    while i < n:
        ch = s[i]
        if ch == '"' or ch == "'":
            # skip quoted string
            quote = ch
            i += 1
            while i < n:
                if s[i] == "\\":
                    i += 2  # skip escaped char
                elif s[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1

def _parse_lua_string(s, start_idx):
    """
    Parse a Lua string literal starting at start_idx where s[start_idx] is a quote.
    Returns (unescaped_python_string, idx_after_closing_quote) or (None, start_idx) on failure.
    Handles \" and \\ escapes.
    """
    n = len(s)
    if start_idx >= n or s[start_idx] not in ('"', "'"):
        return None, start_idx
    quote = s[start_idx]
    i = start_idx + 1
    out_chars = []
    while i < n:
        ch = s[i]
        if ch == "\\":
            # handle escape
            i += 1
            if i >= n:
                break
            esc = s[i]
            # keep common escapes; otherwise keep the escaped char
            if esc == "n":
                out_chars.append("\n")
            elif esc == "t":
                out_chars.append("\t")
            elif esc == "r":
                out_chars.append("\r")
            else:
                out_chars.append(esc)
            i += 1
        elif ch == quote:
            return "".join(out_chars), i + 1
        else:
            out_chars.append(ch)
            i += 1
    return None, start_idx

def _extract_missing_npcs_from_lua(lua_text):
    """
    Parse the BetterQuestDB.lua text and extract a dict:
      { npc_name: [ { 'text':..., 'dialog_type':..., 'count':... , 'originalName':... }, ... ] }
    """
    result = {}
    marker = '["missingNPCs"]'
    idx = lua_text.find(marker)
    if idx == -1:
        return result

    # find the '=' after the marker, then the opening '{'
    eq_idx = lua_text.find("=", idx)
    if eq_idx == -1:
        return result
    brace_idx = lua_text.find("{", eq_idx)
    if brace_idx == -1:
        return result
    end_brace = _find_matching_brace(lua_text, brace_idx)
    if end_brace == -1:
        return result

    block = lua_text[brace_idx:end_brace+1]

    i = 0
    L = len(block)
    # iterate through entries like ["Kaltunk"] = { ... },
    while i < L:
        # find next ["<name>"]
        start_key = block.find('["', i)
        if start_key == -1:
            break
        key_start = start_key + 2
        key_end = block.find('"]', key_start)
        if key_end == -1:
            break
        npc_key = block[key_start:key_end]
        # find '=' after key_end
        eq = block.find("=", key_end)
        if eq == -1:
            i = key_end + 2
            continue
        # find opening brace for this npc table
        npc_brace = block.find("{", eq)
        if npc_brace == -1:
            i = eq + 1
            continue
        npc_end = _find_matching_brace(block, npc_brace)
        if npc_end == -1:
            break
        npc_block = block[npc_brace:npc_end+1]

        # find originalName inside npc_block (optional)
        original_name = None
        on = npc_block.find('["originalName"]')
        if on != -1:
            # find '=' and string after it
            on_eq = npc_block.find("=", on)
            if on_eq != -1:
                # find first quote
                qpos = npc_block.find('"', on_eq)
                if qpos == -1:
                    qpos = npc_block.find("'", on_eq)
                if qpos != -1:
                    parsed, after = _parse_lua_string(npc_block, qpos)
                    if parsed is not None:
                        original_name = parsed

        # find dialogs table inside npc_block
        dialogs_marker = '["dialogs"]'
        dpos = npc_block.find(dialogs_marker)
        dialogs = []
        if dpos != -1:
            d_eq = npc_block.find("=", dpos)
            if d_eq != -1:
                d_brace = npc_block.find("{", d_eq)
                if d_brace != -1:
                    d_end = _find_matching_brace(npc_block, d_brace)
                    if d_end != -1:
                        dialogs_block = npc_block[d_brace:d_end+1]
                        # parse individual dialog entries: ["key"] = { ... },
                        j = 0
                        M = len(dialogs_block)
                        while j < M:
                            kstart = dialogs_block.find('["', j)
                            if kstart == -1:
                                break
                            k_s = kstart + 2
                            k_e = dialogs_block.find('"]', k_s)
                            if k_e == -1:
                                break
                            dialog_hash = dialogs_block[k_s:k_e]

                            # find '=' and then opening brace for this dialog entry
                            keq = dialogs_block.find("=", k_e)
                            if keq == -1:
                                j = k_e + 2
                                continue
                            kbrace = dialogs_block.find("{", keq)
                            if kbrace == -1:
                                j = keq + 1
                                continue
                            k_end = _find_matching_brace(dialogs_block, kbrace)
                            if k_end == -1:
                                break
                            entry_block = dialogs_block[kbrace:k_end+1]

                            # extract fields dialog_text, dialogType, count
                            def _find_field_string(block, fieldname):
                                marker = '["' + fieldname + '"]'
                                pos = block.find(marker)
                                if pos == -1:
                                    return None
                                eqpos = block.find("=", pos)
                                if eqpos == -1:
                                    return None
                                # find first quote after eqpos
                                q = block.find('"', eqpos)
                                if q == -1:
                                    q = block.find("'", eqpos)
                                if q == -1:
                                    return None
                                parsed, after = _parse_lua_string(block, q)
                                return parsed

                            def _find_field_token(block, fieldname):
                                # simple numeric or word token after =
                                marker = '["' + fieldname + '"]'
                                pos = block.find(marker)
                                if pos == -1:
                                    return None
                                eqpos = block.find("=", pos)
                                if eqpos == -1:
                                    return None
                                # read token until comma or brace
                                tstart = eqpos + 1
                                while tstart < len(block) and block[tstart].isspace():
                                    tstart += 1
                                tend = tstart
                                while tend < len(block) and block[tend] not in [",", "}"]:
                                    tend += 1
                                token = block[tstart:tend].strip()
                                return token or None

                            dialog_text = _find_field_string(entry_block, "dialog_text")
                            dialog_type = _find_field_string(entry_block, "dialogType")
                            if dialog_type is None:
                                dt_tok = _find_field_token(entry_block, "dialogType")
                                if dt_tok:
                                    dialog_type = dt_tok.strip('"').strip("'")
                            count_tok = _find_field_token(entry_block, "count")
                            count = None
                            if count_tok:
                                try:
                                    count = int(count_tok)
                                except Exception:
                                    count = None

                            dialogs.append({
                                "hash": dialog_hash,
                                "dialog_text": dialog_text,
                                "dialogType": dialog_type or "gossip",
                                "count": count or 1,
                            })

                            j = k_end + 1

        # add to result using originalName if available, otherwise npc_key
        npc_name_key = original_name or npc_key
        npc_name_key = npc_name_key.strip() if isinstance(npc_name_key, str) else npc_key

        if dialogs:
            result[npc_name_key] = dialogs

        i = npc_end + 1

    return result

def _load_csv_index(csv_path):
    """Load existing CSV into a set of tuples: (npc_name, dialog_type, quest_id, text)"""
    existing = set()
    if not os.path.exists(csv_path):
        return existing
    with open(csv_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            key = (
                (r.get("npc_name") or "").strip(),
                (r.get("dialog_type") or "").strip(),
                (r.get("quest_id") or "").strip() if r.get("quest_id") is not None else "",
                (r.get("text") or "").strip()
            )
            existing.add(key)
    return existing

def sync_game_data(csv_path=NPC_DIALOG_CSV_PATH, lua_path=BETTERQUEST_LUA):
    """
    Parse BetterQuestDB.lua and append any missing dialog lines to CSV.
    Returns number of rows appended.
    """
    print("\n=== STEP 1: Syncing game data from BetterQuest.lua ===")
    
    if not os.path.exists(lua_path):
        print(f"BetterQuest DB not found at: {lua_path}")
        return 0

    with open(lua_path, "r", encoding="utf-8") as f:
        lua_text = f.read()

    missing = _extract_missing_npcs_from_lua(lua_text)
    if not missing:
        print("No missingNPCs found in BetterQuestDB.lua")
        return 0

    existing = _load_csv_index(csv_path)

    to_append = []
    for npc_name, dialogs in missing.items():
        for d in dialogs:
            text = (d.get("dialog_text") or "").strip()
            if not text:
                continue
            dialog_type = (d.get("dialogType") or "gossip").lower()
            key = (npc_name.strip(), dialog_type, "", text)
            if key not in existing:
                to_append.append({
                    "npc_name": npc_name.strip(),
                    "sex": "",
                    "dialog_type": dialog_type,
                    "quest_id": "",
                    "text": text
                })
                existing.add(key)

    if not to_append:
        print("No new missingNPC dialogs to add.")
        return 0

    # Ensure CSV exists with header
    write_header = not os.path.exists(csv_path)
    os.makedirs(os.path.dirname(csv_path), exist_ok=True)

    with open(csv_path, "a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["npc_name", "sex", "dialog_type", "quest_id", "text"])
        if write_header:
            writer.writeheader()
        for row in to_append:
            writer.writerow(row)

    print(f"✓ Appended {len(to_append)} missingNPC dialog rows to {csv_path}")
    return len(to_append)

# =========================
# PART 2: GENERATE AUDIO
# =========================

def get_gpu_memory_info():
    """
    Get current GPU memory usage information.
    Returns dict with allocated, reserved, total (in GB) and usage percentage.
    Returns None if CUDA is not available.
    """
    if not torch.cuda.is_available():
        return None
    
    allocated = torch.cuda.memory_allocated() / (1024**3)  # Convert to GB
    reserved = torch.cuda.memory_reserved() / (1024**3)
    total = torch.cuda.get_device_properties(0).total_memory / (1024**3)
    usage_percent = allocated / total if total > 0 else 0
    
    return {
        "allocated_gb": allocated,
        "reserved_gb": reserved,
        "total_gb": total,
        "usage_percent": usage_percent
    }

def wait_for_gpu_memory(threshold=0.85, wait_seconds=5, max_retries=10):
    """
    Wait for GPU memory to drop below threshold.
    
    Args:
        threshold: Memory usage percentage threshold (0.0-1.0)
        wait_seconds: Seconds to wait between checks
        max_retries: Maximum number of wait attempts before giving up
    
    Returns:
        True if memory is below threshold, False if max retries exceeded
    """
    if not torch.cuda.is_available():
        return True  # No GPU to monitor
    
    import time
    
    for attempt in range(max_retries):
        mem_info = get_gpu_memory_info()
        
        if mem_info["usage_percent"] < threshold:
            if attempt > 0:
                print(f"[GPU] Memory freed: {mem_info['allocated_gb']:.2f}GB / {mem_info['total_gb']:.2f}GB ({mem_info['usage_percent']*100:.1f}%)")
            return True
        
        print(f"[GPU] High memory usage: {mem_info['allocated_gb']:.2f}GB / {mem_info['total_gb']:.2f}GB ({mem_info['usage_percent']*100:.1f}%)")
        print(f"[GPU] Waiting {wait_seconds}s for memory to free up... (attempt {attempt+1}/{max_retries})")
        
        # Force garbage collection
        import gc
        gc.collect()
        torch.cuda.empty_cache()
        
        time.sleep(wait_seconds)
    
    print(f"[GPU] WARNING: Memory still high after {max_retries} attempts. Proceeding anyway...")
    return False

def chunk_text_robust(text, min_chars=150, max_chars=300):
    """
    Split text into TTS-friendly chunks of roughly 150-300 characters.
    - Uses sentence boundaries: .?!; and ...
    - Handles final sentence without punctuation
    - Merges short sentences into previous chunk
    - Splits overly long sentences
    """
    if not text:
        return []

    # 1. Split into sentences (including final sentence without punctuation)
    sentence_pattern = r'.*?(?:\.\.\.|[.?!;]|$)'
    sentences = [s.strip() for s in re.findall(sentence_pattern, text, flags=re.DOTALL) if s.strip()]

    chunks = []
    current_chunk = ""

    for sentence in sentences:
        # If sentence itself is too long, split by whitespace
        if len(sentence) > max_chars:
            words = sentence.split()
            temp = ""
            for word in words:
                if len(temp) + len(word) + 1 > max_chars:
                    if temp:
                        chunks.append(temp.strip())
                    temp = word
                else:
                    temp += " " + word if temp else word
            if temp:
                sentence = temp
            else:
                continue

        # Decide whether to append to current chunk or start new
        if len(current_chunk) + len(sentence) + 1 > max_chars:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = sentence
        else:
            current_chunk += " " + sentence if current_chunk else sentence

    if current_chunk:
        chunks.append(current_chunk.strip())

    # Merge too-short chunks with previous (to satisfy min_chars)
    final_chunks = []
    for chunk in chunks:
        if final_chunks and len(chunk) < min_chars:
            final_chunks[-1] += " " + chunk
        else:
            final_chunks.append(chunk)

    return final_chunks

def get_narrator_from_metadata(row, narrator_override=None):
    """
    Determine which narrator/voice to use for a given row.
    """
    # If narrator override is specified, use it if it exists
    if narrator_override:
        if narrator_override in REF_CODES:
            return narrator_override
        else:
            print(f"[WARNING] Narrator override '{narrator_override}' not found in samples. Falling back to default logic.")
    
    dialog_type = str(row.get("dialog_type", "")).lower()

    # ✅ BOOKS / ITEM TEXT
    if dialog_type in ("book", "item_text"):
        if "narrator" in REF_CODES:
            return "narrator"
        print("[SKIP] No narrator voice sample found")
        return None

    # ---------- existing NPC logic ----------
    name = row.get("npc_name")
    name = name.replace("'", "").replace("'", "")
    meta = NPC_LOOKUP.get(name)

    if not meta:
        print(f"[SKIP] No metadata for NPC: {name}")
        return None

    race = meta.get("race")
    sex = meta.get("sex")

    if not race or not sex:
        print(f"[SKIP] Missing race/sex for NPC: {name}")
        return None

    narrator = f"{race}_{sex}".lower()

    if narrator in REF_CODES:
        return narrator

    if race.lower() in REF_CODES:
        return race.lower()

    print(f"[SKIP] No voice sample for narrator '{narrator}' ({name})")
    return None

def sanitize_filename(name: str) -> str:
    """Make a string safe for filenames by removing/replacing problematic characters."""
    name = name.strip()
    name = re.sub(r"[^\w\s-]", "", name)  # remove special characters
    name = re.sub(r"\s+", "_", name)      # replace spaces with underscores
    return name.lower()

def remove_audio_cues(text: str) -> str:
    """Remove non-spoken audio / onomatopoeia cues that break TTS."""
    if not isinstance(text, str):
        return text

    patterns = [
        r"\[[^\]]*\]",
        r"\([^\)]*\)",
        r"<[^>]*>",
        r"\*[^*]+\*",
        r"\b(?:sfx|audio|sound)\s*:\s*[^\n]+",
    ]

    text = re.sub(r"(?m)^\s*[a-z]{1,4}[.!?…]*\s*$", "", text, flags=re.IGNORECASE)

    for pattern in patterns:
        text = re.sub(pattern, "", text, flags=re.IGNORECASE | re.VERBOSE)

    return text

def normalize_dialog_text(text: str) -> str:
    """Normalize WoW dialog tokens so TTS output is stable and natural."""
    if not isinstance(text, str):
        return text

    # Line breaks ($B, $BB, etc.)
    text = re.sub(r"\$B+", "\n", text, flags=re.IGNORECASE)
    text = remove_audio_cues(text)

    replacements = [
        (r"\$(lad|lass)\b[^.?!;\n]*", "adventurer"),
        (r"\$(n|N|r|R|c|C)\b", "adventurer"),
        (r"\$g[^;]*;", "adventurer"),
        (r"\$\w+", ""),
    ]

    for pattern, repl in replacements:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)

    # Cleanup whitespace (preserve paragraph breaks)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()

def build_gossip_index_map(df):
    """
    Pre-index all gossip lines per NPC from the CSV.
    Returns dict: {npc_name: [text1, text2, ...]}
    """
    gossip_map = {}
    
    for _, row in df.iterrows():
        npc_name = row.get("npc_name")
        if not npc_name:
            continue
        
        dialog_type = str(row.get("dialog_type", "")).lower()
        if "gossip" not in dialog_type:
            continue
        
        text = row.get("text", "")
        if not text:
            continue
        
        if npc_name not in gossip_map:
            gossip_map[npc_name] = []
        
        if text not in gossip_map[npc_name]:
            gossip_map[npc_name].append(text)
    
    return gossip_map

def generate_tts_for_row(row, output_dir=SOUNDS_DIR, regenerate=False, gossip_map=None, narrator_override=None, 
                         max_retries=3, retry_wait=10):
    """
    Generate TTS audio for a single row with retry logic for memory errors.
    
    Args:
        row: DataFrame row with dialog data
        output_dir: Output directory for audio files
        regenerate: Whether to regenerate existing files
        gossip_map: Pre-built gossip index map
        narrator_override: Optional narrator voice override
        max_retries: Maximum number of retries on memory errors
        retry_wait: Seconds to wait between retries
    """
    narrator_voice = get_narrator_from_metadata(row, narrator_override=narrator_override)
    if not narrator_voice or narrator_voice not in REF_CODES:
        print(f"[SKIP] No narrator metadata for NPC: {row['npc_name']}")
        return None

    # Get the original race/sex for folder structure
    folder_race = get_narrator_from_metadata(row, narrator_override=None)
    if not folder_race:
        folder_race = narrator_voice

    npc_name = row.get("npc_name") or "narrator"
    dialog_type = row.get("dialog_type", "gossip").lower()

    # ✅ BOOKS
    if dialog_type in ("book", "item_text"):
        base_dir = os.path.join(output_dir, folder_race)
        os.makedirs(base_dir, exist_ok=True)
        filename = f"{sanitize_filename(npc_name)}.wav"

    # ---------- NPCs ----------
    else:
        npc_dirname = sanitize_filename(npc_name)
        base_dir = os.path.join(output_dir, folder_race, npc_dirname)
        os.makedirs(base_dir, exist_ok=True)

        qid = row.get("quest_id")
        has_quest_id = pd.notna(qid) and str(qid).replace('.', '').isdigit() and int(qid) > 0

        if has_quest_id and dialog_type != "gossip":
            quest_id = str(int(qid))
            filename = f"{quest_id}_{dialog_type}.wav"
        else:
            clean_text = sanitize_filename(row["text"])
            if not clean_text:
                clean_text = "unknown_dialog"
            filename = f"{clean_text[:50]}.wav"

    print(f"Generating {base_dir}/{filename} (using voice: {narrator_voice})")
    filepath = os.path.join(base_dir, filename)

    if os.path.exists(filepath) and not regenerate:
        print(f"[SKIP] File already exists: {filepath}")
        return filepath

    ref = REF_CODES[narrator_voice]
    text_chunks = chunk_text_robust(row["text"])
    SAMPLE_RATE = 24000

    if not text_chunks:
        return None

    # Retry logic for TTS generation
    for attempt in range(max_retries):
        try:
            with sf.SoundFile(
                filepath,
                mode="w",
                samplerate=SAMPLE_RATE,
                channels=1,
                subtype="PCM_16",
            ) as f, torch.no_grad():

                for chunk_idx, chunk in enumerate(text_chunks):
                    try:
                        wav = tts.generate(
                            chunk,
                            audio_prompt_path=ref["audio_path"]
                        )

                        if isinstance(wav, torch.Tensor):
                            wav = wav.detach().cpu().numpy()

                        wav = wav.squeeze()
                        wav = (wav * 32767).clip(-32768, 32767).astype("int16")
                        f.write(wav)

                        del wav
                        torch.cuda.empty_cache()
                    
                    except RuntimeError as e:
                        if "out of memory" in str(e).lower() or "cuda" in str(e).lower():
                            print(f"[ERROR] GPU memory error on chunk {chunk_idx+1}/{len(text_chunks)}: {e}")
                            raise  # Re-raise to trigger outer retry logic
                        else:
                            raise  # Re-raise non-memory errors

            # Success - return the filepath
            return filepath

        except RuntimeError as e:
            error_msg = str(e).lower()
            is_memory_error = "out of memory" in error_msg or "cuda" in error_msg
            
            if is_memory_error and attempt < max_retries - 1:
                print(f"[RETRY] Memory error on attempt {attempt + 1}/{max_retries}")
                print(f"[RETRY] Waiting {retry_wait}s for memory to free up...")
                
                # Aggressive memory cleanup
                import gc
                import time
                
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                    torch.cuda.synchronize()
                
                gc.collect()
                time.sleep(retry_wait)
                
                # Check memory status before retry
                if torch.cuda.is_available():
                    mem_info = get_gpu_memory_info()
                    print(f"[RETRY] GPU memory after cleanup: {mem_info['allocated_gb']:.2f}GB / {mem_info['total_gb']:.2f}GB ({mem_info['usage_percent']*100:.1f}%)")
                
                # Remove partial file if it exists
                if os.path.exists(filepath):
                    os.remove(filepath)
                    print(f"[RETRY] Removed partial file, retrying...")
                
                continue  # Retry
            else:
                # Final attempt failed or non-memory error
                print(f"[ERROR] Failed to generate audio after {attempt + 1} attempts: {e}")
                # Remove partial file
                if os.path.exists(filepath):
                    os.remove(filepath)
                return None
        
        except Exception as e:
            # Non-CUDA errors
            print(f"[ERROR] Unexpected error generating audio: {e}")
            # Remove partial file
            if os.path.exists(filepath):
                os.remove(filepath)
            return None
    
    # Should not reach here, but just in case
    return None

def merge_item_text_rows(df):
    """Only merge item_text rows"""
    item_rows = df[df["dialog_type"].str.lower() == "item_text"]

    merged_rows = []
    seen_text_blocks = set()

    for item_id, group in item_rows.groupby("npc_name"):
        merged_texts = []
        for text in group["text"]:
            if text not in seen_text_blocks:
                merged_texts.append(text)
                seen_text_blocks.add(text)

        if not merged_texts:
            continue

        merged_text = " ".join(merged_texts).strip()
        row = group.iloc[0].copy()
        row["text"] = merged_text
        merged_rows.append(row)

    df = df[df["dialog_type"].str.lower() != "item_text"]

    if merged_rows:
        df = pd.concat([df, pd.DataFrame(merged_rows)], ignore_index=True)

    return df

def generate_audio(df, output_dir=SOUNDS_DIR, regenerate=False, narrator_override=None, 
                   gpu_threshold=0.85, gpu_wait=5, gpu_check_interval=10, max_retries=3, retry_wait=10):
    """
    Generate TTS audio for all rows in dataframe.
    
    Args:
        df: DataFrame with dialog data
        output_dir: Output directory for audio files
        regenerate: Whether to regenerate existing files
        narrator_override: Optional narrator voice override
        gpu_threshold: GPU memory usage threshold (0.0-1.0) before waiting
        gpu_wait: Seconds to wait when GPU memory is high
        gpu_check_interval: Check GPU memory every N files
        max_retries: Maximum retries for failed TTS generation
        retry_wait: Seconds to wait before retrying failed generation
    """
    print("\n=== STEP 2: Generating TTS audio ===")
    
    # Display GPU info at start
    if torch.cuda.is_available():
        mem_info = get_gpu_memory_info()
        print(f"[GPU] Initial memory: {mem_info['allocated_gb']:.2f}GB / {mem_info['total_gb']:.2f}GB ({mem_info['usage_percent']*100:.1f}%)")
        print(f"[GPU] Memory threshold: {gpu_threshold*100:.0f}%")
        print(f"[GPU] Check interval: every {gpu_check_interval} files")
        print(f"[GPU] Retry settings: max {max_retries} retries, {retry_wait}s wait")
    
    gossip_map = build_gossip_index_map(df)
    missing_narrators = []
    files_processed = 0
    
    for idx, row in df.iterrows():
        # Check GPU memory periodically
        if torch.cuda.is_available() and files_processed > 0 and files_processed % gpu_check_interval == 0:
            mem_info = get_gpu_memory_info()
            print(f"\n[GPU] Status check ({files_processed} files): {mem_info['allocated_gb']:.2f}GB / {mem_info['total_gb']:.2f}GB ({mem_info['usage_percent']*100:.1f}%)")
            
            if mem_info['usage_percent'] >= gpu_threshold:
                wait_for_gpu_memory(threshold=gpu_threshold, wait_seconds=gpu_wait)
        
        result = generate_tts_for_row(
            row,
            output_dir=output_dir,
            regenerate=regenerate,
            gossip_map=gossip_map,
            narrator_override=narrator_override,
            max_retries=max_retries,
            retry_wait=retry_wait
        )
        
        if result:
            files_processed += 1
        else:
            missing_narrators.append({
                "npc_name": row["npc_name"],
                "dialog_type": row["dialog_type"]
            })

    if missing_narrators:
        missing_csv = os.path.join(output_dir, "missing_narrators.csv")
        pd.DataFrame(missing_narrators).to_csv(missing_csv, index=False)
        print(f"✓ Saved {len(missing_narrators)} rows with missing narrators → {missing_csv}")
    
    # Final GPU memory report
    if torch.cuda.is_available():
        mem_info = get_gpu_memory_info()
        print(f"\n[GPU] Final memory: {mem_info['allocated_gb']:.2f}GB / {mem_info['total_gb']:.2f}GB ({mem_info['usage_percent']*100:.1f}%)")
    
    print(f"✓ Audio generation complete ({files_processed} files processed)")

# =========================
# PART 3: SYNC METADATA
# =========================

def normalize_name(name):
    """Normalize NPC name for metadata lookup"""
    if not isinstance(name, str):
        return None
    return name.strip().replace('"', '').replace("'", "")

def normalize_text_for_matching(text: str) -> str:
    """Used for the Lua lookup key (text_hash), not the filename."""
    if not isinstance(text, str):
        return ""

    text = re.sub(r"\$B+", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"\$(lad|lass)\b[^.?!;\n]*", "adventurer", text, flags=re.IGNORECASE)
    text = re.sub(r"\$(n|N|r|R|c|C)\b", "adventurer", text)
    text = re.sub(r"\$g[^;]*;", "adventurer", text, flags=re.IGNORECASE)
    text = re.sub(r"\$\w+", "", text, flags=re.IGNORECASE)

    for pattern in [r"\[[^\]]*\]", r"\([^\)]*\)", r"<[^>]*>", r"\*[^*]+\*"]:
        text = re.sub(pattern, "", text)

    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+", " ", text)

    return text.strip().lower()

def create_text_hash(text: str) -> str:
    """Create a hash key for text matching"""
    normalized = normalize_text_for_matching(text)
    return normalized[:50] if normalized else ""

def sound_path_to_fs(sound_path: str) -> Path | None:
    """Convert Lua path to filesystem path"""
    parts = sound_path.split("BetterQuest\\", 1)
    if len(parts) != 2:
        return None
    return Path("..") / parts[1].replace("\\", "/")

def get_wav_duration_seconds(path: Path) -> float | None:
    """Get duration of WAV file in seconds"""
    try:
        with contextlib.closing(wave.open(str(path), "rb")) as wf:
            return round(wf.getnframes() / wf.getframerate(), 3)
    except Exception:
        return None

def read_yaml(path):
    """Read YAML file"""
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)

def invert_mapping(mapping):
    """Convert {category: [names]} -> {normalized_name: category}"""
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

def sync_metadata(df, output_lua=OUTPUT_LUA):
    """Build and write unified NPC database to Lua"""
    print("\n=== STEP 3: Syncing metadata to Lua database ===")
    
    # Load YAML mappings
    npc_race = invert_mapping(read_yaml(RACE_FILE))
    npc_sex = invert_mapping(read_yaml(SEX_FILE))
    npc_zone = invert_mapping(read_yaml(ZONE_FILE))

    # Merge item_text blocks (books/items are split into multiple rows in DB but generated as one file)
    item_text_rows = df[df["dialog_type"].str.lower().isin(["item_text", "book"])]
    merged_rows = []
    seen_text_blocks = set()

    for _, group in item_text_rows.groupby("npc_name"):
        merged = []
        for text in group["text"]:
            if text not in seen_text_blocks:
                merged.append(text)
                seen_text_blocks.add(text)

        if not merged:
            continue

        # Create a single merged row
        row = group.iloc[0].copy()
        row["text"] = " ".join(merged).strip()
        merged_rows.append(row)

    # Remove original item rows and append merged ones
    df = df[~df["dialog_type"].str.lower().isin(["item_text", "book"])]
    if merged_rows:
        df = pd.concat([df, pd.DataFrame(merged_rows)], ignore_index=True)

    npc_database = {}
    missing_race = {}

    for _, row in df.iterrows():
        npc_name = normalize_name(row.get("npc_name"))
        if not npc_name:
            continue

        # Initialize NPC entry if not exists
        if npc_name not in npc_database:
            race = npc_race.get(npc_name)
            sex = row.get("sex")
            if pd.notna(sex):
                sex = SEX_MAP.get(int(sex))
            if not sex:
                sex = npc_sex.get(npc_name, "male")
            
            zone = npc_zone.get(npc_name, "")
            model_id = int(row.get("model_id")) if pd.notna(row.get("model_id")) else None
            
            if not race:
                missing_race[npc_name] = None
            
            # Determine narrator info
            if race:
                narrator = f"{race}_female" if sex == "female" else race
                portrait = race
            else:
                narrator = "narrator"
                portrait = "default"
            
            npc_database[npc_name] = {
                "race": race,
                "sex": sex,
                "portrait": portrait,
                "zone": zone,
                "model_id": model_id,
                "narrator": narrator,
                "dialogs": {}
            }

        # Add dialog entry
        dialog_type = str(row.get("dialog_type", "gossip")).lower()
        text = row.get("text", "")
        text_hash = create_text_hash(text)
        
        if not text_hash:
            continue

        narrator = npc_database[npc_name]["narrator"]
        npc_dirname = sanitize_filename(npc_name)
        quest_id = None

        # Path generation logic (must match TTS script)
        if dialog_type in ("book", "item_text"):
            filename = f"{npc_dirname}.wav"
            sound_path = (
                f"Interface\\AddOns\\BetterQuest\\sounds\\"
                f"{narrator}\\{filename}"
            )
        else:
            qid = row.get("quest_id")
            has_quest_id = pd.notna(qid) and str(qid).replace('.', '').isdigit() and int(qid) > 0

            if has_quest_id:
                quest_id = int(qid)
                filename = f"{quest_id}_{dialog_type}.wav"
            else:
                clean_text = sanitize_filename(text)
                if not clean_text:
                    continue
                filename = f"{clean_text[:50]}.wav"

            sound_path = (
                f"Interface\\AddOns\\BetterQuest\\sounds\\"
                f"{narrator}\\{npc_dirname}\\{filename}"
            )

        # Check if file exists
        fs_path = sound_path_to_fs(sound_path)
        if not fs_path or not fs_path.exists():
            continue

        seconds = get_wav_duration_seconds(fs_path)
        if seconds is None:
            continue

        # Add to dialogs
        npc_database[npc_name]["dialogs"][text_hash] = {
            "path": sound_path,
            "dialog_type": dialog_type,
            "quest_id": quest_id,
            "seconds": seconds,
        }

    # Write missing races
    with open(MISSING_RACE_FILE, "w", encoding="utf-8") as f:
        yaml.dump(missing_race, f, default_flow_style=False, allow_unicode=True)

    # Write Lua database
    with open(output_lua, "w", encoding="utf-8") as f:
        f.write("-- Auto-generated unified NPC database\n")
        f.write("-- Contains metadata + dialog mappings\n")
        f.write("-- DO NOT EDIT MANUALLY\n\n")
        f.write("NPC_DATABASE = {\n")

        for npc_name, data in sorted(npc_database.items()):
            if not data["dialogs"]:
                continue

            f.write(f'  ["{npc_name}"] = {{\n')
            
            # Metadata
            f.write(f'    race = "{data["race"] or ""}",\n')
            f.write(f'    sex = "{data["sex"]}",\n')
            f.write(f'    portrait = "{data["portrait"]}",\n')
            f.write(f'    zone = "{data["zone"]}",\n')
            f.write(f'    model_id = {data["model_id"] if data["model_id"] else "nil"},\n')
            f.write(f'    narrator = "{data["narrator"]}",\n')
            
            # Dialogs
            f.write('    dialogs = {\n')
            for text_hash, info in sorted(data["dialogs"].items()):
                path = info["path"].replace("\\", "\\\\")
                quest_id = info["quest_id"] if info["quest_id"] is not None else "nil"
                
                f.write(
                    f'      ["{text_hash}"] = {{ '
                    f'path="{path}", '
                    f'dialog_type="{info["dialog_type"]}", '
                    f'quest_id={quest_id}, '
                    f'seconds={info["seconds"]} '
                    f'}},\n'
                )
            f.write('    },\n')
            f.write('  },\n')

        f.write("}\n\n")

    print(f"✓ Generated unified database for {len(npc_database)} NPCs")
    print(f"✓ Total dialog entries linked: {sum(len(v['dialogs']) for v in npc_database.values())}")
    print(f"✓ Missing races: {len(missing_race)}")
    print(f"✓ Output written to: {output_lua}")

# =========================
# MAIN PIPELINE
# =========================

def parse_args():
    parser = argparse.ArgumentParser(description="Unified TTS Pipeline: Sync → Generate → Link")
    parser.add_argument("--race", type=str, help="Filter by NPC race")
    parser.add_argument("--sex", type=str, help="Filter by NPC sex (male/female)")
    parser.add_argument("--npc", type=str, help="Filter by specific NPC name")
    parser.add_argument("--narrator", type=str, help="Voice override (wav filename without .wav)")
    parser.add_argument("--zone", type=str, help="Filter by zone")
    parser.add_argument("--type", type=str, help="Filter by dialog type")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of rows to process")
    parser.add_argument("--regenerate", action="store_true", help="Regenerate existing audio files")
    parser.add_argument("--skip-sync", action="store_true", help="Skip game data sync step")
    parser.add_argument("--skip-audio", action="store_true", help="Skip audio generation step")
    parser.add_argument("--skip-metadata", action="store_true", help="Skip metadata sync step")
    parser.add_argument("--device", type=str, choices=["cpu", "cuda"], default="cuda", 
                        help="Device to use for TTS model (default: cuda)")
    parser.add_argument("--gpu-threshold", type=float, default=0.85, 
                        help="GPU memory usage threshold (0.0-1.0) before waiting (default: 0.85)")
    parser.add_argument("--gpu-wait", type=int, default=5, 
                        help="Seconds to wait when GPU memory is high (default: 5)")
    parser.add_argument("--gpu-check-interval", type=int, default=10, 
                        help="Check GPU memory every N files (default: 10)")
    parser.add_argument("--max-retries", type=int, default=3, 
                        help="Maximum retries for failed TTS generation (default: 3)")
    parser.add_argument("--retry-wait", type=int, default=10, 
                        help="Seconds to wait before retrying failed generation (default: 10)")
    parser.add_argument("--daemon", action="store_true", 
                        help="Run in daemon mode, monitoring BetterQuest.lua for changes")
    parser.add_argument("--daemon-interval", type=int, default=5, 
                        help="Seconds between file checks in daemon mode (default: 5)")
    parser.add_argument("--wtf-path", type=str, default="../../../../WTF", 
                        help="Path to WTF directory for finding BetterQuest.lua (default: ../../../../WTF)")
    return parser.parse_args()

def filter_dataframe(df, args):
    """Apply command-line filters to dataframe"""
    if args.npc:
        df = df[df["npc_name"] == args.npc]

    if args.type:
        df = df[df["dialog_type"] == args.type]

    if args.race:
        allowed = {
            name for name, meta in NPC_LOOKUP.items()
            if meta.get("race") == args.race
        }
        df = df[df["npc_name"].isin(allowed)]

    if args.sex:
        allowed = {
            name for name, meta in NPC_LOOKUP.items()
            if meta.get("sex") == args.sex
        }
        df = df[df["npc_name"].isin(allowed)]

    if args.zone:
        allowed = {
            name for name, meta in NPC_LOOKUP.items()
            if meta.get("zone") == args.zone
        }
        df = df[df["npc_name"].isin(allowed)]

    if args.limit:
        df = df.head(args.limit)

    return df

def run_pipeline(args, betterquest_path=None):
    """
    Execute the full TTS pipeline.
    
    Args:
        args: Parsed command-line arguments
        betterquest_path: Optional override for BetterQuest.lua path
    """
    # Use provided path or default
    lua_path = betterquest_path or BETTERQUEST_LUA
    
    # Step 1: Sync game data
    if not args.skip_sync:
        sync_game_data(lua_path=lua_path)
    else:
        print("\n=== STEP 1: Syncing game data [SKIPPED] ===")
    
    # Load full dataframe
    df_full = pd.read_csv(NPC_DIALOG_CSV_PATH)
    df_full = df_full[df_full["text"].notna()]
    
    # Apply filters for audio generation
    df_filtered = filter_dataframe(df_full.copy(), args)
    df_filtered = df_filtered.drop_duplicates(subset=["npc_name", "text"])
    df_filtered["text"] = df_filtered["text"].apply(normalize_dialog_text)
    df_filtered = merge_item_text_rows(df_filtered)
    
    # Step 2: Generate audio (uses filtered dataframe)
    if not args.skip_audio:
        generate_audio(
            df_filtered, 
            regenerate=args.regenerate, 
            narrator_override=args.narrator,
            gpu_threshold=args.gpu_threshold,
            gpu_wait=args.gpu_wait,
            gpu_check_interval=args.gpu_check_interval,
            max_retries=args.max_retries,
            retry_wait=args.retry_wait
        )
    else:
        print("\n=== STEP 2: Generating TTS audio [SKIPPED] ===")
    
    # Step 3: Sync metadata (uses FULL dataframe to include all existing audio)
    if not args.skip_metadata:
        # Prepare full dataframe for metadata sync (apply same transformations)
        df_for_metadata = df_full.copy()
        df_for_metadata = df_for_metadata.drop_duplicates(subset=["npc_name", "text"])
        df_for_metadata["text"] = df_for_metadata["text"].apply(normalize_dialog_text)
        # Note: merge_item_text_rows is called INSIDE sync_metadata, so don't call it here
        
        print(f"\n[INFO] Syncing metadata for ALL rows from CSV (not just filtered {len(df_filtered)})")
        sync_metadata(df_for_metadata)
    else:
        print("\n=== STEP 3: Syncing metadata [SKIPPED] ===")
    
    print("\n" + "=" * 60)
    print("PIPELINE COMPLETE")
    print("=" * 60)

def main():
    global tts
    
    args = parse_args()
    
    print("=" * 60)
    print("UNIFIED TTS PIPELINE")
    print("=" * 60)
    
    # Validate narrator override if provided
    if args.narrator:
        if args.narrator not in REF_CODES:
            print(f"[ERROR] Narrator '{args.narrator}' not found in ../samples/")
            print(f"Available narrators: {', '.join(sorted(REF_CODES.keys()))}")
            sys.exit(1)
        print(f"[INFO] Using narrator override: {args.narrator}")
    
    # Daemon mode
    if args.daemon:
        print(f"\n[DAEMON MODE ENABLED]")
        
        # Find BetterQuest.lua file
        betterquest_path = find_betterquest_file(args.wtf_path)
        
        if not betterquest_path:
            print(f"[ERROR] Could not find BetterQuest.lua in {args.wtf_path}")
            print(f"[ERROR] Searched patterns:")
            print(f"  - {args.wtf_path}/Account/*/SavedVariables/BetterQuest.lua")
            print(f"  - {args.wtf_path}/*/SavedVariables/BetterQuest.lua")
            print(f"  - {args.wtf_path}/SavedVariables/BetterQuest.lua")
            sys.exit(1)
        
        print(f"[DAEMON] Found BetterQuest.lua: {betterquest_path}")
        
        # Initialize TTS model once if not skipping audio
        if not args.skip_audio:
            print(f"\n[INFO] Initializing TTS model on device: {args.device}")
            tts = ChatterboxTurboTTS.from_pretrained(device=args.device)
            print(f"[INFO] TTS model loaded successfully")
        
        # Define callback for file changes
        def on_file_changed(filepath):
            print(f"[DAEMON] Processing changes from: {filepath}")
            run_pipeline(args, betterquest_path=filepath)
        
        # Start monitoring
        monitor_file_changes(
            betterquest_path, 
            check_interval=args.daemon_interval,
            callback=on_file_changed
        )
        
        return
    
    # Normal mode (single run)
    # Initialize TTS model with selected device
    if not args.skip_audio:
        print(f"\n[INFO] Initializing TTS model on device: {args.device}")
        tts = ChatterboxTurboTTS.from_pretrained(device=args.device)
        print(f"[INFO] TTS model loaded successfully")
    
    # Run pipeline once
    run_pipeline(args)

if __name__ == "__main__":
    main()