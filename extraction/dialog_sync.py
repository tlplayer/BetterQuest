import pandas as pd
import json
import re
import wave
import contextlib
from pathlib import Path

# ---------- Configuration ----------
CSV_PATH = "../data/all_npc_dialog.csv"
NPC_METADATA_JSON = "../data/npc_metadata.json"
OUTPUT_LUA = "../db/npc_dialog_map.lua"

# Script runs from: Interface/AddOns/BetterQuest/extraction/
# Sounds live in:   Interface/AddOns/BetterQuest/sounds/

# ---------- Helpers ----------
def normalize_name(name):
    if not isinstance(name, str):
        return None
    return name.strip().replace('"', '').replace("'", "")

def sanitize_filename(name: str) -> str:
    name = name.strip()
    name = re.sub(r"[^\w\s-]", "", name)
    name = re.sub(r"\s+", "_", name)
    return name.lower()

def normalize_text_for_matching(text: str) -> str:
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
    normalized = normalize_text_for_matching(text)
    return normalized[:50] if normalized else ""

# ---------- Path + audio helpers ----------
def sound_path_to_fs(sound_path: str) -> Path | None:
    """
    Converts:
      Interface\\AddOns\\BetterQuest\\sounds\\human\\npc\\file.wav
    To:
      ../sounds/human/npc/file.wav
    """
    parts = sound_path.split("BetterQuest\\", 1)
    if len(parts) != 2:
        return None
    return Path("..") / parts[1].replace("\\", "/")

def get_wav_duration_seconds(path: Path) -> float | None:
    try:
        with contextlib.closing(wave.open(str(path), "rb")) as wf:
            return round(wf.getnframes() / wf.getframerate(), 3)
    except Exception:
        return None

# ---------- Load NPC metadata ----------
with open(NPC_METADATA_JSON, "r", encoding="utf-8") as f:
    npc_metadata = json.load(f)

npc_to_narrator = {}
for npc_name, data in npc_metadata.items():
    race = data.get("race")
    sex = data.get("sex")

    if not race:
        continue

    narrator = f"{race}_female" if sex == "female" else race
    npc_to_narrator[npc_name] = narrator

# ---------- Load CSV ----------
df = pd.read_csv(CSV_PATH)
df = df[df["text"].notna()]

# ---------- Merge item_text blocks ----------
item_text_rows = df[df["dialog_type"].str.lower() == "item_text"]
merged_rows = []
seen_text_blocks = set()

for _, group in item_text_rows.groupby("npc_id"):
    merged = []
    for text in group["text"]:
        if text not in seen_text_blocks:
            merged.append(text)
            seen_text_blocks.add(text)

    if not merged:
        continue

    row = group.iloc[0].copy()
    row["text"] = " ".join(merged).strip()
    merged_rows.append(row)

df = df[df["dialog_type"].str.lower() != "item_text"]
if merged_rows:
    df = pd.concat([df, pd.DataFrame(merged_rows)], ignore_index=True)

# ---------- Build dialog map ----------
dialog_map = {}

for _, row in df.iterrows():
    npc_name = normalize_name(row.get("npc_name"))
    if not npc_name:
        continue

    narrator = npc_to_narrator.get(npc_name, "narrator")
    npc_dirname = sanitize_filename(npc_name)
    dialog_type = str(row.get("dialog_type", "gossip")).lower()
    text = row.get("text", "")

    if dialog_type == "gossip":
        quest_id = None
        sound_path = (
            f"Interface\\AddOns\\BetterQuest\\sounds\\"
            f"{narrator}\\{npc_dirname}\\gossip.wav"
        )

    elif dialog_type == "item_text":
        quest_id = None
        sound_path = (
            f"Interface\\AddOns\\BetterQuest\\sounds\\narrator\\"
            f"{npc_dirname}.wav"
        )

    else:
        qid = row.get("quest_id")
        nid = row.get("npc_id")

        if pd.notna(qid):
            quest_id = int(qid)
        elif pd.notna(nid):
            quest_id = int(nid)
        else:
            quest_id = 0

        sound_path = (
            f"Interface\\AddOns\\BetterQuest\\sounds\\"
            f"{narrator}\\{npc_dirname}\\{quest_id}_{dialog_type}.wav"
        )

    fs_path = sound_path_to_fs(sound_path)
    if not fs_path or not fs_path.exists():
        continue

    seconds = get_wav_duration_seconds(fs_path)
    if seconds is None:
        continue

    text_hash = create_text_hash(text)
    if not text_hash:
        continue

    dialog_map.setdefault(npc_name, {})[text_hash] = {
        "path": sound_path,
        "dialog_type": dialog_type,
        "quest_id": quest_id,
        "seconds": seconds,
    }

# ---------- Write Lua ----------
with open(OUTPUT_LUA, "w", encoding="utf-8") as f:
    f.write("-- Auto-generated NPC dialog to sound file mapping\n")
    f.write("-- DO NOT EDIT MANUALLY\n\n")
    f.write("NPC_DIALOG_MAP = {\n")

    for npc_name, entries in sorted(dialog_map.items()):
        f.write(f'  ["{npc_name}"] = {{\n')
        for text_hash, info in sorted(entries.items()):
            path = info["path"].replace("\\", "\\\\")
            quest_id = info["quest_id"] if info["quest_id"] is not None else "nil"

            f.write(
                f'    ["{text_hash}"] = {{ '
                f'path="{path}", '
                f'dialog_type="{info["dialog_type"]}", '
                f'quest_id={quest_id}, '
                f'seconds={info["seconds"]} '
                f'}},\n'
            )
        f.write("  },\n")

    f.write("}\n\n")

    f.write("""
function NormalizeDialogText(text)
  if not text then return "" end

  text = string.gsub(text, "%$B+", " ")
  text = string.gsub(text, "%$[nNrRcC]", "adventurer")
  text = string.gsub(text, "%$g[^;]*;", "adventurer")
  text = string.gsub(text, "%$%w+", "")
  text = string.gsub(text, "%b[]", "")
  text = string.gsub(text, "%b()", "")
  text = string.gsub(text, "%b<>", "")
  text = string.gsub(text, "%*[^%*]+%*", "")
  text = string.gsub(text, "[^%w%s]", "")
  text = string.gsub(text, "%s+", " ")

  -- TRIM (this was missing)
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")

  text = string.lower(text)

  -- BYTE-BASED slice (matches Lua reality)
  return string.sub(text, 1, 50)
end

local function NormalizeNPCName(name)
  if not name then return nil end
  name = string.gsub(name, "['’]", "")
  return name
end

function FindDialogSound(npcName, dialogText)
  if not npcName or not dialogText then return nil end

  local lookupName = NormalizeNPCName(npcName)
  local key = NormalizeDialogText(dialogText)
  if key == "" then return nil end

  -- 1) Normal lookup (expected case)
  local npc = NPC_DIALOG_MAP[lookupName]
  if npc and npc[key] then
    local entry = npc[key]
    return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
  end

  -- 2) Fallback: search all NPCs by text hash
  for otherNpcName, entries in pairs(NPC_DIALOG_MAP) do
    local entry = entries[key]
    if entry then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffff8800[SoundQueue]|r NPC mismatch: '" ..
        lookupName .. "' → '" .. otherNpcName .. "'"
      )
      return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
    end
  end

  return nil
end

""")

print(f"Generated dialog map for {len(dialog_map)} NPCs")
print(f"Total entries: {sum(len(v) for v in dialog_map.values())}")
print(f"Output written to: {OUTPUT_LUA}")
