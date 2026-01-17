import pandas as pd
import yaml
import json
from collections import defaultdict

# ---------- File paths ----------
CSV_PATH = "../data/all_npc_dialog.csv"
RACE_FILE = "../data/npc_race.yaml"
SEX_FILE = "../data/npc_sex.yaml"
ZONE_FILE = "../data/npc_zone.yaml"
MISSING_RACE = "../data/missing_race.yaml"
OUTPUT_JSON = "../data/npc_metadata.json"
OUTPUT_LUA = "../db/npc_metadata.lua"

SEX_MAP = {0: "male", 1: "female"}

# ---------- Helpers ----------
def normalize_name(name):
    if not isinstance(name, str):
        return None
    return name.strip().replace('"', '').replace("'", "")

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

def read_yaml(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)

# ---------- Load source mappings ----------
npc_race = invert_mapping(read_yaml(RACE_FILE))
npc_sex  = invert_mapping(read_yaml(SEX_FILE))
npc_zone = invert_mapping(read_yaml(ZONE_FILE))

# ---------- Extract unique NPCs ----------
df = pd.read_csv(CSV_PATH)
df = df[["npc_id", "npc_name", "sex", "model_id", "dialog_type"]].drop_duplicates(subset=["npc_id"])
df = df[df["dialog_type"] != "item_text"]  # skip item_text
df["npc_name"] = df["npc_name"].astype(str)
df["sex"] = df["sex"].map(SEX_MAP)

npc_data = {}
for _, row in df.iterrows():
    name = normalize_name(row.npc_name)
    race = npc_race.get(name)
    sex  = row.sex or npc_sex.get(name)
    zone = npc_zone.get(name)

    if race:
        portrait = race
    else:
        portrait = "default"

    npc_data[name] = {
        "race": race,
        "sex": sex,
        "portrait": portrait,
        "zone": zone,
        "model_id": int(row.model_id) if not pd.isna(row.model_id) else None
    }

# Find missing races
missing_race = {}
for _, row in df.iterrows():
    name = normalize_name(row.npc_name)
    if name and name not in npc_race:
        missing_race[name] = None  # Placeholder for future assignment

# Write missing_race.yaml
with open(MISSING_RACE, "w", encoding="utf-8") as f:
    yaml.dump(missing_race, f, default_flow_style=False, allow_unicode=True)

# ---------- Write JSON ----------
with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
    json.dump(npc_data, f, indent=2, ensure_ascii=False)

# ---------- Write Lua ----------
with open(OUTPUT_LUA, "w", encoding="utf-8") as f:
    f.write("NPC_DATA = {\n")
    for name, info in npc_data.items():
        f.write(f'  ["{name}"] = {{ race="{info["race"]}", sex={repr(info["sex"])}, portrait="{info["portrait"]}", zone={repr(info["zone"])}, model_id={repr(info["model_id"])} }},\n')
    f.write("}\n")

print(f"Wrote {len(npc_data)} NPCs to JSON and Lua")
