import io
import re
import pandas as pd
import soundfile as sf
from pydub import AudioSegment
from neuttsair.neutts import NeuTTSAir

# =========================
# INITIALIZE TTS
# =========================

tts = NeuTTSAir(
    backbone_repo="neuphonic/neutts-air-q4-gguf",
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
    "elf_female": {
    "audio": "../samples/elf_female/elf_female.wav",
    "text": "../samples/elf_female/elf_female.txt"
    },
    "elf": {
        "audio": "../samples/elf/elf.wav",
        "text": "../samples/elf/elf.txt"
    }
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


def assign_narrator(row):
    """
    Determine narrator based on NPC info (race_mask, sex, dialog_type, etc.)
    Returns:
        - narrator key (str) if unambiguous
        - None if missing/ambiguous
    """
    # Simple example: use race_mask or dialog_type
    race_map = {
        1: "human",
        2: "orc",
        3: "dwarf",
        # Add more mappings
    }
    if row.get("race_mask") in race_map:
        return race_map[row["race_mask"]]
    # fallback rules: by dialog_type or custom overrides
    if row.get("dialog_type") == "item_text":
        return "narrator"  # default narrator for items
    return None  # ambiguous


def generate_tts_for_row(row, output_dir="sounds"):
    """
    Generates TTS for a single row in the dataframe.
    Returns concatenated AudioSegment.
    """
    row_narrator = assign_narrator(row)
    if not row_narrator or row_narrator not in REF_CODES:
        return None  # skip or log missing narrator

    ref = REF_CODES[row_narrator]
    text_chunks = chunk_text_robust(row["text"])
    audio_segments = []

    for chunk in text_chunks:
        wav = tts.infer(chunk, ref["codes"], ref["text"])
        buf = io.BytesIO()
        sf.write(buf, wav, 24900, format="WAV")
        buf.seek(0)
        audio_segments.append(AudioSegment.from_file(buf, format="wav"))

    # Concatenate all chunks
    final_audio = AudioSegment.silent(duration=0)
    for seg in audio_segments:
        final_audio += seg
    return final_audio


# =========================
# PROCESS DATAFRAME
# =========================

def process_dataframe(df, output_dir="sounds"):
    """
    df: pandas DataFrame with columns:
        ["npc_id", "npc_name", "race_mask", "sex", "dialog_type", "quest_id", "text"]
    Generates TTS for each row, logs missing/ambiguous narrators.
    """
    missing_narrators = []
    for idx, row in df.iterrows():
        audio = generate_tts_for_row(row)
        if audio:
            filename = f"{output_dir}/{row['npc_id']}_{idx}.wav"
            audio.export(filename, format="wav")
        else:
            missing_narrators.append({
                "npc_id": row["npc_id"],
                "npc_name": row["npc_name"],
                "dialog_type": row["dialog_type"]
            })

    # Save missing/ambiguous narrators to CSV for later manual assignment
    if missing_narrators:
        pd.DataFrame(missing_narrators).to_csv(f"{output_dir}/missing_narrators.csv", index=False)
        print(f"Saved {len(missing_narrators)} rows with missing/ambiguous narrators.")


# =========================
# EXAMPLE USAGE
# =========================

# df = pd.read_csv("all_npc_dialog.csv")
# process_dataframe(df)
