import pandas as pd
import json
import re
import wave
import contextlib
from pathlib import Path
import yaml

# ---------- Configuration ----------
CSV_PATH = "../data/all_npc_dialog.csv"
RACE_FILE = "../data/npc_race.yaml"
SEX_FILE = "../data/npc_sex.yaml"
ZONE_FILE = "../data/npc_zone.yaml"
MISSING_RACE_FILE = "../data/missing_race.yaml"

OUTPUT_LUA = "../db/npc_database.lua"

# Sounds live in: Interface/AddOns/BetterQuest/sounds/

SEX_MAP = {0: "male", 1: "female"}

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

def read_yaml(path):
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

# ---------- Load source mappings ----------
npc_race = invert_mapping(read_yaml(RACE_FILE))
npc_sex = invert_mapping(read_yaml(SEX_FILE))
npc_zone = invert_mapping(read_yaml(ZONE_FILE))

# ---------- Load CSV ----------
df = pd.read_csv(CSV_PATH)
df = df[df["text"].notna()]

# ---------- Build gossip index map ----------
def build_gossip_index_map(df):
    """Pre-index all gossip lines per NPC from the CSV."""
    gossip_map = {}
    
    for _, row in df.iterrows():
        npc_name = normalize_name(row.get("npc_name"))
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

gossip_index_map = build_gossip_index_map(df)

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

# ---------- Build unified NPC database ----------
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
        
        # Track missing races
        if not race:
            missing_race[npc_name] = None
        
        # Determine narrator
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

    # Determine sound path
    if "gossip" in dialog_type:
        quest_id = None
        
        # Find index for this gossip text
        idx = 0
        if npc_name in gossip_index_map and text in gossip_index_map[npc_name]:
            idx = gossip_index_map[npc_name].index(text)
        
        sound_path = (
            f"Interface\\AddOns\\BetterQuest\\sounds\\"
            f"{narrator}\\{npc_dirname}\\gossip_{idx}.wav"
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

# ---------- Write missing races ----------
with open(MISSING_RACE_FILE, "w", encoding="utf-8") as f:
    yaml.dump(missing_race, f, default_flow_style=False, allow_unicode=True)

# ---------- Write unified Lua database ----------
with open(OUTPUT_LUA, "w", encoding="utf-8") as f:
    f.write("-- Auto-generated unified NPC database\n")
    f.write("-- Contains metadata + dialog mappings\n")
    f.write("-- DO NOT EDIT MANUALLY\n\n")
    f.write("NPC_DATABASE = {\n")

    for npc_name, data in sorted(npc_database.items()):
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

    # Utility functions
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

  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")

  text = string.lower(text)

  return string.sub(text, 1, 50)
end

local function NormalizeNPCName(name)
  if not name then return nil end
  name = string.gsub(name, "['']", "")
  return name
end

function GetNPCMetadata(npcName)
  if not npcName then return nil end
  local lookupName = NormalizeNPCName(npcName)
  local npc = NPC_DATABASE[lookupName]
  
  if npc then
    return {
      race = npc.race,
      sex = npc.sex,
      portrait = npc.portrait,
      zone = npc.zone,
      model_id = npc.model_id,
      narrator = npc.narrator
    }
  end
  
  return nil
end

function FindDialogSound(npcName, dialogText)
  if not npcName or not dialogText then return nil end

  local lookupName = NormalizeNPCName(npcName)
  local key = NormalizeDialogText(dialogText)
  if key == "" then return nil end

  -- 1) Normal lookup (expected case)
  local npc = NPC_DATABASE[lookupName]
  if npc and npc.dialogs and npc.dialogs[key] then
    local entry = npc.dialogs[key]
    return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
  end

  -- 2) Fallback: search all NPCs by text hash
  for otherNpcName, data in pairs(NPC_DATABASE) do
    if data.dialogs then
      local entry = data.dialogs[key]
      if entry then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffff8800[SoundQueue]|r NPC mismatch: '" ..
          lookupName .. "' → '" .. otherNpcName .. "'"
        )
        return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
      end
    end
  end

  return nil
end

""")

print(f"Generated unified database for {len(npc_database)} NPCs")
print(f"Total dialog entries: {sum(len(v['dialogs']) for v in npc_database.values())}")
print(f"Missing races: {len(missing_race)}")
print(f"Output written to: {OUTPUT_LUA}")