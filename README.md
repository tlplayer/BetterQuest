[![Video title](https://img.youtube.com/vi/EvMl5aSn4VU/0.jpg)](https://www.youtube.com/watch?v=EvMl5aSn4VU)
[![Video title](https://img.youtube.com/vi/DhcekpqKZiA/0.jpg)](https://www.youtube.com/watch?v=DhcekpqKZiA)


# Features

1. Fully functioning local voice cloning for quests, items, gossip, and NPC in-game speech
2. Sound queue for controlling and skipping sounds
3. Wide, centered quest dialog with a left pane for customizable portraits based on speaker race and sex

> **Note**
> This addon assumes and requires **pfUI**: [https://github.com/shagu/pfUI](https://github.com/shagu/pfUI)

---

## BetterQuest Voice Generation Pipeline

This guide explains how to use the Python tools to generate NPC voices and synchronize them with the WoW addon.

---

## 🛠 Prerequisites

* **GPU**: Preferably an NVIDIA GPU. This was tested on a GTX 1060 (6GB VRAM). The Chatterbox model is very lightweight.
* **Hugging Face Account**: Required to download the Chatterbox model (free, no payment required).
* **Authentication**: You must authenticate via the Hugging Face CLI before downloading models.

### Hugging Face Authentication

Before you can download private or gated models (e.g., Llama 3) or upload your own work, authenticate your machine.

1. **Get your token**
   Visit: [https://huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)

2. **Create a new token**
   Select **Write** if you plan on uploading models; otherwise, **Read** is sufficient.

3. **Install and log in via CLI**

```sh
pip install --upgrade huggingface_hub
huggingface-cli login
```

4. **Enter your token**
   Paste your token when prompted (it will not be visible while typing).

5. **Git credentials**
   When asked whether to add the token as a Git credential, answering `Y` is usually recommended.

---

### Python Environment

```sh
source venv/bin/activate
pip install mysql-connector-python slpp pyyaml
```

### Additional Requirements

* **FFmpeg**: Required for audio conversion and fixing sample rates
* **Database**: A local C-MaNGOS or TrinityCore database running on MySQL or MariaDB

---

## 🚀 Workflow

### 1. Data Extraction & Preprocessing

> **Optional**: Skip this section if you only want to generate voices.

NPC metadata (race, sex, and dialog) has been extracted, but some entries are incomplete. The database queries used were not fully comprehensive, so missing values are expected.

You can modify `extract.py` and supply your own database with:

* `name`
* `dialog_type` (quest, gossip, item_text, etc.)

As long as the generator can find the corresponding `samples/*.wav` files, the pipeline should still work.

```sh
cd extraction/
python extract.py                   # Extracts quest, gossip, and broadcast text
python npc_metadata_extractor.py    # Maps NPCs to their race and gender
```

This updates `data/npc_metadata.json` and ensures NPCs are mapped according to `data/npc_race.yml`.

---

### 2. Voice Generation (`generator.py`)

Use the generator to create `.wav` files. The script uses the NPC's race and gender (`npc_race.yml` + `npc_sex.yml` → `npc_metadata.json`) to select the appropriate voice sample.

**Generate voices for a specific NPC:**

```sh
python generation/generator.py --npc "Sentinel Aynasha"
```

**Generate voices for a specific race:**

```sh
python generation/generator.py --race night_elf
```

**Limit generation (for testing):**

```sh
python generation/generator.py --race human --limit 5
```

**Generate narrator voices (books and items):**

```sh
python generation/generator.py --race narrator
```

---

### 3. Synchronization (`sync.py`)

After generating new audio files, you must sync them so the Lua addon knows which files exist and how long they play.

```sh
cd extraction/
python sync.py
```

This updates the Lua database files and maps file durations (e.g., `334_quest_accept.wav`) so the in-game sound queue functions correctly.

---

## 🎨 Portrait Management

If you add new NPC portraits, they must be converted to Blizzard-compatible TGA format:

* 256×256 resolution
* 24-bit color depth

Portraits follow the same lookup logic as voices (race + sex). For example:

* `night_elf_female.tga`

### Batch Convert Images to TGA

```sh
cd portraits/
for f in *.png; do
    ffmpeg -y -i "$f" -vf "scale=256:256" -pix_fmt rgb24 "${f%.*}.tga"
done
```

---

## 🤝 Contributing

Help is very welcome, especially in the following areas:

### UI

* The current UI relies on pfUI and does not look very "classic"
* UI improvements or redesigns are highly encouraged

### Race & Sex Fixes

* Some NPCs have incorrect or missing race, sex, or dialog mappings
* These can be fixed manually or systematically in the YAML files
* Identifying the correct speakers for quest, gossip, broadcast, and item text is difficult in the source databases
* Improving `all_npc_dialog.csv` with accurate mappings would be a huge help

---

## 💖 Show Gratitude

If you’d like to support this project:

* Check out my [Ko-fi](https://ko-fi.com/tlplayer)
* Also check out Mr. Thinger’s [Ko-fi](https://github.com/mrthinger/wow-voiceover)

This addon was inspired by Mr. Thinger’s work, though that project has been inactive for about three years at the time of writing.

---

## Motivation

> **Why did you do this?**

I’ve been playing WoW since I was six years old and didn’t know how to read very well at that time. WoW has a lot of text and not the best UI for reading, and sometimes you just want to vibe.

My ultimate goal is to use voice-over to motivate people to engage with the game’s stories and read more.

It could even be something personal—like a parent cloning their voice for their child or grandchild, giving them something meaningful to remember them by.
