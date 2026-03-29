# BetterQuest

Local voice generation and playback for WoW 1.12 (Vanilla) private servers.

| Feature | Preview |
|---|---|
| Quest dialog & NPC voice | [![Quest voices](https://img.youtube.com/vi/EvMl5aSn4VU/0.jpg)](https://www.youtube.com/watch?v=EvMl5aSn4VU) |
| Gossip, items & sound queue | [![Gossip & items](https://img.youtube.com/vi/DhcekpqKZiA/0.jpg)](https://www.youtube.com/watch?v=DhcekpqKZiA) |

**What it does:**
- In game narration: quests, speech bubbles, items, books, etc. 
- Generates NPC voices locally on CPU or GPU (1060) using [Chatterbox TTS](https://huggingface.co/resemble-ai/chatterbox)
- Sound queue with skip support
- Wide quest dialog with speaker portraits
- Syncs missing data from game back to a local csv for sharing/filling gaps 

---

**Requirements:** [pfUI](https://github.com/shagu/pfUI) a computer (intel CPU 2017 with 1060 GPU 6GB Vram )

---
**What it does NOT do:**

- Have voice lines included
- Have voice samples included

---

## Installation

### 1. Addon

Place the addon folder inside your WoW addons directory:

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── BetterQuest/
            ├── sounds/       ← generated .wav files go here
            ├── portraits/    ← .tga portrait files go here
            ├── samples/      ← .wav samples to be cloned human.wav human_female.wav etc. go here
            ├── scripts/      ← .py generator.py is what you call to generate voicelines go here
            └── data/         ← .csv and .yaml files for races + sex of NPCs and voice lines + who says them
```

Install [pfUI](https://github.com/shagu/pfUI) if you haven't already. BetterQuest requires it.

### 2. Python (pyenv)

open terminal

```sh
# install pyenv
curl https://pyenv.run | bash

# add to shell
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"

# install and pin python version
pyenv install 3.11
pyenv local 3.11

# create and activate venv
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Hugging Face

The Chatterbox model requires a free Hugging Face account.

1. Create an account at [huggingface.co](https://huggingface.co)
2. Generate a token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) (Read is sufficient)
3. Authenticate:

```sh
pip install --upgrade huggingface_hub
huggingface-cli login
```

### 4. FFmpeg

Required for audio conversion. Install via your package manager:

```sh
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg

```

---

## Quickstart

```sh
# activate env
source venv/bin/activate

# test generation (CPU, single file)
python generation/generator.py --limit 1 --device cpu

```

---

## Syncing Dialog from Your Server

The addonn scrapes dialogue from in game, saves it in a settings file, then the python reads it: 

```bash
~/Applications/wow/Interface/AddOns/BetterQuest$ ls ../../../WTF/Account/ADMIN/SavedVariables |grep BetterQuest.lua
BetterQuest.lua


```


---

## Voice Generation

Voice samples are selected by NPC race and sex. Priority order:

1. NPC-specific sample: `samples/bolvar.wav`
2. Race + sex: `samples/night_elf_female.wav`
3. Fallback (if configured)

**Generate for a specific NPC:**

```sh
python generation/generator.py --npc "Sentinel Aynasha" --cpu
```

**Generate by race:**

```sh
python generation/generator.py --race night_elf --cpu
```

**Test run (limit output):**

```sh
python generation/generator.py --race human --limit 1 --cpu
```

**Narrator voice (books, item flavor text):**

```sh
python generation/generator.py --race narrator --cpu
```

After generation, always run:

```sh
python extraction/sync.py
```

---

## Portraits

Portraits are matched by race and sex using the same logic as voice samples.

**Naming:** `race_sex.tga` — e.g., `night_elf_female.tga`, `orc_male.tga`

**Format requirements:**
- 256×256 resolution
- 24-bit RGB
- `.tga` extension

Wrong format causes silent failure in WoW — no error is shown.

**Batch convert from PNG:**

```sh
cd portraits/
for f in *.png; do
    ffmpeg -y -i "$f" -vf "scale=256:256" -pix_fmt rgb24 "${f%.*}.tga"
done
```

Place converted `.tga` files in `BetterQuest/portraits/`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| No audio in-game | Run `sync.py`. Check file is in `sounds/`. Check FFmpeg is installed. |
| Model download fails | Run `huggingface-cli login` |
| Audio cuts off early | Re-run `sync.py` to resync durations |
| Wrong voice for NPC | Check `data/npc_metadata.json` and `data/npc_race.yml` |

---

## Contributing

Most useful contributions:

- **Race/sex mappings** — fix incorrect or missing entries in `data/npc_race.yml`, `data/npc_sex.yml`, and `data/all_npc_dialog.csv`
- **UI** — the current UI is pfUI-dependent and not styled to match the classic WoW aesthetic
- **Speaker attribution** — identifying which NPC delivers which gossip/broadcast text is the hardest part of the data problem

---

## Support

- [Ko-fi (this project)](https://ko-fi.com/tlplayer)
- [Mr. Thinger's Ko-fi](https://github.com/mrthinger/wow-voiceover) — original inspiration

---

## Why

I've played WoW since I was six and couldn't read well. The game has a lot of text and a poor reading UX. Voice-over makes the stories accessible and encourages engagement with the writing.

One use case I care about: a parent cloning their voice for a child to hear in-game — something permanent and personal.
