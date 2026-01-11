import io
import os
import sys
from pathlib import Path

import argparse
import re
import pandas as pd
import soundfile as sf
from pydub import AudioSegment
ROOT = Path(__file__).resolve().parents[1]
NEUTTS_AIR = ROOT / "neutts-air"
sys.path.insert(0, str(NEUTTS_AIR))
from neuttsair.neutts import NeuTTSAir
import json






# =========================
# INITIALIZE TTS
# =========================



# All quest/gossip/text we narrate and what id is linked to that
NPC_DIALOG_CSV_PATH = "../data/all_npc_dialog.csv"
# How we link the npc to narrator traits:race, sex, zone for ambience /refinement
NPC_METADATA_JSON = "../data/npc_metadata.json"

with open(NPC_METADATA_JSON, "r", encoding="utf-8") as f:
    NPC_METADATA = json.load(f)

# Fast lookup by npc_name
NPC_LOOKUP = {
    npc["name"]: npc
    for npc in NPC_METADATA
}

tts = NeuTTSAir(
    backbone_repo="neuphonic/neutts-air-q8-gguf",
    backbone_device="cpu",
    codec_repo="neuphonic/neucodec",
    codec_device="cpu"
)

# =========================
# REFERENCE DATA
# =========================

# Map narrator keys to reference text
NARRATOR_REFS = {
    "dwarf": {
        "audio": "../samples/dwarf/dwarf.wav",
        "text": "../samples/dwarf/dwarf.txt"
    },
    "human": {
        "audio": "../samples/human/human.wav",
        "text": "../samples/human/human.txt"
    },
    "narrator": {
        "audio": "../samples/narrator/narrator.wav",
        "text": "../samples/narrator/narrator.txt"
    },
    # Add more narrators as needed
}

# Precompute reference codes
REF_CODES = {}
for narrator, paths in NARRATOR_REFS.items():
    ref_text = open(paths["text"], "r", encoding="utf-8").read().strip()
    ref_codes = tts.encode_reference(paths["audio"])
    REF_CODES[narrator] = {"codes": ref_codes, "text": ref_text}


# =========================
# UTILITY FUNCTIONS
# =========================

def chunk_text_robust(text, min_sentences=1, max_sentences=3, min_chars=30, max_chars=200):
    """
    Split text into sentence-based chunks that satisfy both min/max sentences
    and min/max characters. Combines short sentences and splits long sentences.
    """
    sentence_pattern = r'.*?(?:\.\.\.|[.?!;])'
    sentences = [s.strip() for s in re.findall(sentence_pattern, text, flags=re.DOTALL) if s.strip()]

    chunks, current_chunk, current_len = [], [], 0
    for s in sentences:
        s_len = len(s)
        if (len(current_chunk) >= max_sentences or current_len + s_len > max_chars) and current_chunk:
            chunks.append(" ".join(current_chunk))
            current_chunk, current_len = [], 0
        current_chunk.append(s)
        current_len += s_len
    if current_chunk:
        chunks.append(" ".join(current_chunk))

    # Merge very short chunks with previous
    final_chunks = []
    for chunk in chunks:
        if final_chunks:
            if len(chunk) < min_chars or sum(chunk.count(x) for x in ".!?") < min_sentences:
                final_chunks[-1] += " " + chunk
                continue
        final_chunks.append(chunk)
    return final_chunks

def get_narrator_from_metadata(row):
    name = row.get("npc_name")
    meta = NPC_LOOKUP.get(name)

    if not meta:
        return None

    narrator = meta.get("narrator")
    if narrator in REF_CODES:
        return narrator

    # Fallbacks
    if meta.get("race") == "human":
        return "human"

    return "narrator"


def sanitize_filename(name: str) -> str:
    """
    Make a string safe for filenames by removing/replacing problematic characters.
    """
    name = name.strip()
    name = re.sub(r"[^\w\s-]", "", name)  # remove special characters
    name = re.sub(r"\s+", "_", name)      # replace spaces with underscores
    return name.lower()
import re

def normalize_dialog_text(text: str) -> str:
    """
    Normalize WoW dialog tokens so TTS output is stable and natural.
    """
    if not isinstance(text, str):
        return text

    # Line breaks ($B, $BB, etc.)
    text = re.sub(r"\$B+", "\n", text, flags=re.IGNORECASE)

    replacements = [
        # Gendered address — consume phrase until punctuation
        (r"\$(lad|lass)\b[^.?!;\n]*", "hero"),

        # Player references
        (r"\$(n|N|r|R|c|C)\b", "hero"),

        # Gender switch token: $g he:she; etc → hero
        (r"\$g[^;]*;", "hero"),

        # Any remaining $tokens (failsafe)
        (r"\$\w+", ""),
    ]

    for pattern, repl in replacements:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)

    # Cleanup whitespace (preserve paragraph breaks)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


def generate_tts_for_row(row, output_dir="sounds", regenerate=False):
    narrator = get_narrator_from_metadata(row)
    if not narrator or narrator not in REF_CODES:
        return None

    narrator_dir = os.path.join(output_dir, narrator)
    os.makedirs(narrator_dir, exist_ok=True)

    quest_id = row.get("quest_id") or row.get("npc_id") or 0
    npc_name = row.get("npc_name") or "unknown"
    dialog_type = row.get("dialog_type")
    filename_safe = sanitize_filename(f"{dialog_type}/{npc_name}")+ ".wav"
    filepath = os.path.join(narrator_dir, filename_safe)

    if os.path.exists(filepath) and not regenerate:
        print(f"Skipping existing file: {filepath}")
        return filepath

    ref = REF_CODES[narrator]
    text_chunks = chunk_text_robust(row["text"])
    audio_segments = []

    for chunk in text_chunks:
        wav = tts.infer(chunk, ref["codes"], ref["text"])
        buf = io.BytesIO()
        sf.write(buf, wav, 24850, format="WAV")
        buf.seek(0)
        audio_segments.append(AudioSegment.from_file(buf, format="wav"))

    final_audio = AudioSegment.empty()
    for seg in audio_segments:
        final_audio += seg

    final_audio.export(filepath, format="wav")
    print(f"Generated: {filepath}")
    return filepath


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--race", type=str)
    parser.add_argument("--npc", type=str)
    parser.add_argument("--zone", type=str)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--regenerate", action="store_true")
    return parser.parse_args()


def filter_dataframe(df, args):
    if args.npc:
        df = df[df["npc_name"] == args.npc]

    if args.race:
        allowed = {
            name for name, meta in NPC_LOOKUP.items()
            if meta.get("race") == args.race
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


# =========================
# PROCESS DATAFRAME
# =========================
def process_dataframe(df, output_dir="sounds"):
    """
    Process the dataframe row-by-row, generate TTS files.
    """
    missing_narrators = []
    for idx, row in df.iterrows():
        result = generate_tts_for_row(row, output_dir=output_dir)
        if not result:
            missing_narrators.append({
                "npc_id": row["npc_id"],
                "npc_name": row["npc_name"],
                "dialog_type": row["dialog_type"]
            })

    if missing_narrators:
        missing_csv = os.path.join(output_dir, "missing_narrators.csv")
        pd.DataFrame(missing_narrators).to_csv(missing_csv, index=False)
        print(f"Saved {len(missing_narrators)} rows with missing/ambiguous narrators → {missing_csv}")

# =========================
# EXAMPLE USAGE
# =========================
if __name__ == "__main__":
    args = parse_args()

    df = pd.read_csv(NPC_DIALOG_CSV_PATH)
    df = df[df["text"].notna()]

    df = filter_dataframe(df, args)
    df = df.drop_duplicates(subset=["npc_name", "text"])
    df["text"] = df["text"].apply(normalize_dialog_text)
    print(df.head(10))

    for _, row in df.iterrows():
        generate_tts_for_row(
            row,
            output_dir="sounds",
            regenerate=args.regenerate
        )

