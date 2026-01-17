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

import torch
import torchaudio as ta
from chatterbox.tts_turbo import ChatterboxTurboTTS

tts = ChatterboxTurboTTS.from_pretrained(device="cuda")



# =========================
# REFERENCE DATA
# =========================

# Map narrator keys to reference text
def discover_narrators(samples_root="../samples"):
    """
    Discover narrator reference files from the filesystem.
    """
    narrators = {}

    for name in os.listdir(samples_root):
        narrator_dir = os.path.join(samples_root, name)
        if not os.path.isdir(narrator_dir):
            continue

        audio_path = os.path.join(narrator_dir, f"{name}.wav")

        if os.path.isfile(audio_path):
            narrators[name] = {
                "audio": audio_path,
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
# UTILITY FUNCTIONS
# =========================


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


def get_narrator_from_metadata(row):
    name = row.get("npc_name")
    meta = NPC_LOOKUP.get(name)

    if not meta:
        return None

    narrator = meta.get("narrator")
    if narrator in REF_CODES:
        return narrator

    return None


def sanitize_filename(name: str) -> str:
    """
    Make a string safe for filenames by removing/replacing problematic characters.
    """
    name = name.strip()
    name = re.sub(r"[^\w\s-]", "", name)  # remove special characters
    name = re.sub(r"\s+", "_", name)      # replace spaces with underscores
    return name.lower()

def remove_audio_cues(text: str) -> str:
    """
    Remove non-spoken audio / onomatopoeia cues that break TTS.
    """
    if not isinstance(text, str):
        return text

    patterns = [
        # Bracketed or parenthetical audio directions
        r"\[[^\]]*\]",          # [laughs]
        r"\([^\)]*\)",          # (sighs)
        r"<[^>]*>",              # <roars>
        r"\*[^*]+\*",            # *chuckles*

        # Explicit audio labels
        r"\b(?:sfx|audio|sound)\s*:\s*[^\n]+",

        # Standalone onomatopoeia words (conservative)
        r"""\b(?: 
        ah+ | eh+ | uh+ | oh+ | um+ | erm+ | hmm+ | hrr+ |
        mmm+ | nng+ | ngh+ |
        ugh+ | agh+ | argh+ | grr+ |
        ach+ | auch+ | och+ |
        oof+ | uff+ | pff+ | pfft+ |
        hah+ | hehe+ | heh+ | hoh+ |
        huh+ | eek+ | eeek+ |
        whew+ | wheee+ |
        sniff+ | snrk+ | snort+ |
        gasp+ | cough+ | choke+ |
        groan+ | grunt+ | sigh+
        )\b[.!?,…]*"""
    ]
    # Remove leftover short interjections (1–4 chars) on their own line
    text = re.sub(r"(?m)^\s*[a-z]{1,4}[.!?…]*\s*$", "", text, flags=re.IGNORECASE)


    for pattern in patterns:
        text = re.sub(pattern, "", text, flags=re.IGNORECASE | re.VERBOSE)

    return text


def normalize_dialog_text(text: str) -> str:
    """
    Normalize WoW dialog tokens so TTS output is stable and natural.
    """
    if not isinstance(text, str):
        return text

    # Line breaks ($B, $BB, etc.)
    text = re.sub(r"\$B+", "\n", text, flags=re.IGNORECASE)
    text = remove_audio_cues(text)

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

def generate_tts_for_row(row, output_dir="../sounds", regenerate=False):
    race = get_narrator_from_metadata(row)
    if not race or race not in REF_CODES:
        return None

    npc_name = row.get("npc_name") or "narrator"
    npc_dirname = sanitize_filename(npc_name)
    dialog_type = row.get("dialog_type", "gossip").lower()

    base_dir = os.path.join(output_dir, race, npc_dirname)
    os.makedirs(base_dir, exist_ok=True)

    if dialog_type == "gossip":
        filename = "gossip.wav"
    else:
        qid = row.get("quest_id")
        nid = row.get("npc_id")

        if pd.notna(qid):
            quest_id = str(int(qid))
        elif pd.notna(nid):
            quest_id = str(int(nid))
        else:
            quest_id = "0"

        filename = f"{quest_id}_{dialog_type}.wav"

    print(f"Generating {base_dir}/{filename}")
    filepath = os.path.join(base_dir, filename)

    if os.path.exists(filepath) and not regenerate:
        return filepath

    ref = REF_CODES[race]
    text_chunks = chunk_text_robust(row["text"])
    SAMPLE_RATE = 24000

    if not text_chunks:
        return None

    with sf.SoundFile(
        filepath,
        mode="w",
        samplerate=SAMPLE_RATE,
        channels=1,
        subtype="PCM_16",
    ) as f, torch.no_grad():

        for chunk in text_chunks:
            wav = tts.generate(
                chunk,
                audio_prompt_path=ref["audio_path"]
            )

            if isinstance(wav, torch.Tensor):
                wav = wav.detach().cpu().numpy()

            wav = wav.squeeze()

            # float → int16
            wav = (wav * 32767).clip(-32768, 32767).astype("int16")

            f.write(wav)

            # HARD MEMORY RELEASE
            del wav
            torch.cuda.empty_cache()

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
def process_dataframe(df, output_dir="../sounds"):
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

    for _, row in df.iterrows():
        generate_tts_for_row(
            row,
            output_dir="../sounds",
            regenerate=args.regenerate
        )

