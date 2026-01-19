import pandas as pd
import json
import re

# ---------- Configuration ----------
CSV_PATH = "../data/all_npc_dialog.csv"
NPC_METADATA_JSON = "../data/npc_metadata.json"
OUTPUT_LUA = "../db/npc_dialog_map.lua"

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

# ---------- Load NPC metadata ----------
with open(NPC_METADATA_JSON, "r", encoding="utf-8") as f:
    npc_metadata = json.load(f)

# ---------- Build narrator lookup (RACE + SEX) ----------
npc_to_narrator = {}
for npc_name, data in npc_metadata.items():
    race = data.get("race")
    sex  = data.get("sex")  # "male" / "female"

    if not race:
        continue

    if sex == "female":
        narrator = f"{race}_female"
    else:
        narrator = race

    npc_to_narrator[npc_name] = narrator

# ---------- Build dialog map ----------
df = pd.read_csv(CSV_PATH)
df = df[df["text"].notna()]

dialog_map = {}

for _, row in df.iterrows():
    npc_name = normalize_name(row.get("npc_name"))
    if not npc_name:
        continue

    narrator = npc_to_narrator.get(npc_name)
    if not narrator:
        continue

    npc_dirname = sanitize_filename(npc_name)
    dialog_type = str(row.get("dialog_type", "gossip")).lower()
    text = row.get("text", "")

    if dialog_type == "gossip":
        filename = "gossip.wav"
        quest_id = None
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

    sound_path = (
        f"Interface\\AddOns\\BetterQuest\\sounds\\"
        f"{narrator}\\{npc_dirname}\\{filename}"
    )

    text_hash = create_text_hash(text)
    if not text_hash:
        continue

    dialog_map.setdefault(npc_name, {})[text_hash] = {
        "path": sound_path,
        "dialog_type": dialog_type,
        "quest_id": quest_id
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
            dialog_type = info["dialog_type"]
            quest_id = info["quest_id"] if info["quest_id"] else "nil"

            f.write(
                f'    ["{text_hash}"] = {{ '
                f'path="{path}", dialog_type="{dialog_type}", quest_id={quest_id} }},\n'
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
  text = string.lower(text)
  return string.sub(text, 1, 50)
end

function FindDialogSound(npcName, dialogText)
  local npc = NPC_DIALOG_MAP[npcName]
  if not npc then return nil end

  local key = NormalizeDialogText(dialogText)
  if key == "" then return nil end

  local entry = npc[key]
  if entry then
    return entry.path, entry.dialog_type, entry.quest_id
  end
end
""")

print(f"Generated dialog map for {len(dialog_map)} NPCs")
print(f"Total entries: {sum(len(v) for v in dialog_map.values())}")
print(f"Output written to: {OUTPUT_LUA}")
