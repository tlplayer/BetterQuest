# BetterQuest

Local voice generation and playback for WoW 1.12 (Vanilla) private servers.

| Feature | Preview |
|---|---|
| Overall Demo of Features| [![Overall Showcase](https://img.youtube.com/vi/o_XpBgDgaQM/0.jpg)](https://www.youtube.com/watch?v=o_XpBgDgaQM)
| Quest dialog & NPC voice | [![Quest voices](https://img.youtube.com/vi/EvMl5aSn4VU/0.jpg)](https://www.youtube.com/watch?v=EvMl5aSn4VU) |
| Gossip, items & sound queue | [![Gossip & items](https://img.youtube.com/vi/DhcekpqKZiA/0.jpg)](https://www.youtube.com/watch?v=DhcekpqKZiA) |
| Explainer LONG | [![Gossip & items](https://img.youtube.com/vi/k3VKKurGKqk/0.jpg)](https://www.youtube.com/watch?v=k3VKKurGKqk) |

**What it does:**
- In game narration: quests, speech bubbles, items, books, etc. 
- Generates NPC voices locally on CPU or GPU using [OmniVoice](https://huggingface.co/k2-fsa/OmniVoice)
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
            ├── scripts/      ← .py core.py is what you call to generate voicelines go here
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

### 3. OmniVoice model

The first audio run downloads `k2-fsa/OmniVoice` from Hugging Face. The model is
public, so authentication is normally unnecessary. You can still run `hf auth
login` if you need authenticated Hugging Face downloads.

### 4. FFmpeg (OPTIONAL)

for audio conversion. Install via your package manager:

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

cd scripts

# test generation (CPU, single file)
python core.py --limit 1 --device cpu

```

---

## Syncing Dialog from Your Server

The addonn scrapes dialogue from in game, saves it in a settings file, then the python reads it: 

```bash
~/Applications/wow/Interface/AddOns/BetterQuest$ ls ../../../WTF/Account/ADMIN/SavedVariables |grep BetterQuest.lua
BetterQuest.lua

# This looks like the following:

```


---

## Voice Generation

Voice samples are selected by NPC race and sex. Priority order:

1. NPC-specific sample: `samples/bolvar.wav`
2. Race + sex: `samples/night_elf_female.wav`
3. Fallback (if configured)

OmniVoice works best with a clean 3–10 second reference sample. To avoid loading
an ASR model, place an exact transcript beside a sample using the same basename:

```text
samples/orc_male.wav
samples/orc_male.txt
```

If the `.txt` file is absent, BetterQuest transcribes the sample once with
`openai/whisper-tiny.en` and caches the resulting voice prompt for the run.
Generation defaults to 16 diffusion steps for speed; use `--tts-steps 32` when
you prefer the higher-quality setting. `--tts-speed` controls speaking speed.

**Generate for a specific NPC:**

```sh
python core.py --npc "Sentinel Aynasha" --device cpu
```

**Generate by race:**

```sh
python core.py --race night_elf --device cpu
```

**Test run (limit output):**

```sh
python core.py --race human --limit 1 --device cpu
```

**Generate only selected expansion and zone content:**

```sh
python core.py --expansion vanilla --zone "Elwynn Forest" --device cpu
python core.py --expansion tbc,wotlk --zone "Outland" --zone "Northrend" --device cpu
```

`--zone` and `--expansion` may be repeated or given comma-separated values.
Captured row-level zones take priority; older rows fall back to `data/npc_zone.yaml`.

**Narrator voice (books, item flavor text):**

```sh
python core.py --race object --device cpu
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

## Contributing

Most useful contributions:

- **Race/sex mappings** — fix incorrect or missing entries in `data/npc_race.yml`, `data/npc_sex.yml`, and `data/all_npc_dialog.csv`
- **UI** — the current UI is pfUI-dependent and not styled to match the classic WoW aesthetic
- **Speaker attribution** — identifying which NPC delivers which gossip/broadcast text is the hardest part of the data problem
- **Share your sync'd data** - When you contribute to the all_npc_dialog.csv everyone can then use the underlying data 

---

## Support

- [Ko-fi (this project)](https://ko-fi.com/tlplayer)

---

## Why

- I've played WoW since I was six and I love this game.
- Getting fixes/patches that improve the game improves my enjoyment aswell as yours
- Contributions to the database npc makes the addon better
- I have a ko-fi and getting tips is always nice
