from neuttsair.neutts import NeuTTSAir
import soundfile as sf
import io
from pydub import AudioSegment
import re

# --- Initialize TTS ---
tts = NeuTTSAir(
    backbone_repo="neuphonic/neutts-air-q4-gguf",
    backbone_device="cpu",
    codec_repo="neuphonic/neucodec",
    codec_device="cpu"
)

# --- Input text ---
input_text = "As a member of the Senate and the Explorers' League, I've taken it upon myself to take care of this part of the trogg infestation that has gripped our lands. They've certainly made a mess of Gol'Bolar quarry, and for no reason. As we dug deep into the earth, they poured out, destroying our equipment and driving the miners out. There's not much for us to do but to exterminate the lot of them, rebuild, then get back to work. If you help me with the troggs, I'll gladly recompense you for your time."
'''
(

    "Through study of various fossilized creatures I have deduced that in ancient times, "
    "a great plague swept through the waters of Lake Lordamere. What caused this? We might never know. "
    "But the rate of contamination appears to be extremely high based on dense concentrations of remains distributed across the lake bed. "
    "In an attempt to uncover the past, I have begun to examine the creatures of the present in hopes of finding the missing clue to this mystery. "
    "The Lake Skulkers and Lake Creepers are ancient beasts who inhabit the islands in the center of Lake Lordamere. "
    "There is a moss which grows on them that resembles trace materials on some of the fossils. "
    "More research needs to be done before I can speculate as to what this connection means. "
    "While trying to collect moss samples I came across the scene of a bloody battle. "
    "The Vile Fin tribe of Murlocs had come under siege by a marauding band of Gnolls. "
    "There were both Gnoll and Murloc corpses littering the battlefield. "
    "As I passed a mangled Murloc body I noticed a strange hardened tumor protruding from the wound. "
    "As I began to study the tumor it became clear it held similar properties to the moss I was collecting. "
    "Unfortunately, I could find no other tumors besides the one."
)

'''

# --- Reference audio and text ---
ref_audio_path = "../samples/audio/dwarf/dwarf.wav"
ref_text_path = "../samples/text/dwarf/dwarf.txt"

ref_text = open(ref_text_path, "r").read().strip()
ref_codes = tts.encode_reference(ref_audio_path)

## --- Robust sentence-based chunking ---
def chunk_text_robust(text,
                      min_sentences=1, max_sentences=3,
                      min_chars=30, max_chars=200):
    """
    Split text into sentence-based chunks that satisfy both min/max sentences
    and min/max characters. Combines short sentences and splits long sentences.
    """
    # Match sentences ending with ., ?, !, ; or ...
    sentence_pattern = r'.*?(?:\.\.\.|[.?!;])'
    sentences = re.findall(sentence_pattern, text, flags=re.DOTALL)
    sentences = [s.strip() for s in sentences if s.strip()]

    chunks = []
    current_chunk = []
    current_len = 0

    for s in sentences:
        s_len = len(s)
        # If adding this sentence exceeds max_chars or max_sentences, finalize current chunk
        if (len(current_chunk) >= max_sentences or current_len + s_len > max_chars) and current_chunk:
            chunks.append(" ".join(current_chunk))
            current_chunk = []
            current_len = 0

        current_chunk.append(s)
        current_len += s_len

    # Add remaining chunk
    if current_chunk:
        chunks.append(" ".join(current_chunk))

    # Merge very short chunks with previous to meet min_chars/min_sentences
    final_chunks = []
    for chunk in chunks:
        if final_chunks:
            if len(chunk) < min_chars or chunk.count('.') + chunk.count('!') + chunk.count('?') < min_sentences:
                # merge with previous
                final_chunks[-1] += " " + chunk
                continue
        final_chunks.append(chunk)
    print(chunks)
    return final_chunks

# --- Split text into robust chunks ---
chunks = chunk_text_robust(input_text)

# --- Generate TTS for each chunk and write each to a separate WAV ---
audio_segments = []
for idx, chunk in enumerate(chunks):
    print(f"Generating chunk {idx+1}/{len(chunks)}: {chunk[:60]}...")
    wav_chunk = tts.infer(chunk, ref_codes, ref_text)

    # Convert NumPy array to pydub AudioSegment for later concatenation
    buf = io.BytesIO()
    sf.write(buf, wav_chunk, 24410, format='WAV')
    buf.seek(0)
    seg = AudioSegment.from_file(buf, format="wav")
    audio_segments.append(seg)

# --- Concatenate all segments in order ---
final_audio = AudioSegment.silent(duration=0)  # start with empty segment
for seg in audio_segments:
    final_audio += seg  # append without adding silence

final_audio.export("narrator.wav", format="wav")
print("Generated narrator.wav successfully!")
