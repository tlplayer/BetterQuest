import pandas as pd
import json

from collections import defaultdict
import yaml

# Example file paths (replace with your real files)
RACE_FILE = "../data/npc_race.yaml"
SEX_FILE = "../data/npc_sex.yaml"
ZONE_FILE = "../data/npc_zone.yaml"


MISSING_RACE_FILE = "missing_race.yaml"
MISSING_SEX_FILE = "missing_sex.yaml"
MISSING_ZONE_FILE = "missing_zone.yaml"

import yaml

# Path to your YAML file
MISSING_RACE_FIX_FILE = "missing_race_fix.yaml"

# Read the file as a dictionary
with open(MISSING_RACE_FIX_FILE, "r", encoding="utf-8") as f:
    missing_race_fixes = yaml.safe_load(f)

# Now missing_race_fixes is a dictionary you can use
print(type(missing_race_fixes))  # <class 'dict'>
print(missing_race_fixes.get("Angelas Moonbreeze"))  # night_elf

# Example: update your main race lookup

# Track missing values
missing_race = {}
missing_sex = {}
missing_zone = {}

def read_mapping(file_path):
    """
    Reads a YAML file of the format:
      key:
      - value1
      - value2
    Returns a dict mapping key -> list of values
    """
    with open(file_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data

CSV_PATH = "/home/tplayer/Applications/Wow/Interface/AddOns/BetterQuest/data/all_npc_dialog.csv"
OUTPUT_JSON = "npc_metadata_seed.json"

SEX_MAP = {
    0: "male",
    1: "female",
}

def extract_unique_npcs(csv_path: str, race_lookup, sex_lookup, zone_lookup):
    df = pd.read_csv(csv_path)

    # Keep only what we need
    df = df[["npc_id", "npc_name", "sex", "model_id", "dialog_type"]].dropna(subset=["npc_name"])
    df = df.drop_duplicates(subset=["npc_id"])
    df = df[df["dialog_type"] != "item_text"]  # remove item_text entries

    df["npc_name"] = df["npc_name"].astype(str)
    df["sex"] = df["sex"].map(SEX_MAP)

    records = []

    for _, row in df.iterrows():
        name = normalize_name(row.npc_name)
        race = race_lookup.get(name)
        sex = row.sex or sex_lookup.get(name)
        zone = zone_lookup.get(name)

        # Simplified narrator logic
        if race:
            narrator = race + ("_female" if sex == "female" else "")
        # Record missing
        if not race:
            missing_race[name] = None
        if not sex:
            missing_sex[name] = None
        if not zone:
            missing_zone[name] = None

        

        records.append({
            "npc_id": row.npc_id,
            "name": name,
            "id": None,                 
            "race": race,
            "sex": sex,
            "dialog_type": row.dialog_type,
            "zone": zone,
            "narrator": narrator,
            "portrait": narrator,
            "model_id": int(row.model_id) if not pd.isna(row.model_id) else None,
        })

    return sorted(records, key=lambda x: x["name"])


def read_mapping(file_path):
    """
    Reads a YAML file of the format:
      key:
      - value1
      - value2
    Returns a dict mapping key -> list of values
    """
    with open(file_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data

def normalize_name(name):
    """
    Remove leading/trailing spaces and quotes for matching
    """
    if not isinstance(name, str):
        return None
    return name.strip().replace('"', '').replace("'", "")

def invert_mapping(mapping):
    """
    Converts {category: [names]} into {normalized_name: category} for lookup
    """
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


def write_json(data, output_path):
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def write_yaml(data, output_path):
    with open(output_path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

if __name__ == "__main__":
     # Read and invert mappings for easy lookup
    npc_race = invert_mapping(read_mapping(RACE_FILE))
    npc_race.update(missing_race_fixes)
    npc_sex = invert_mapping(read_mapping(SEX_FILE))
    npc_zone = invert_mapping(read_mapping(ZONE_FILE))

    # Extract NPCs and fill race/sex/zone/narrator automatically
    npc_data = extract_unique_npcs(CSV_PATH, npc_race, npc_sex, npc_zone)    
    write_yaml(missing_race, MISSING_RACE_FILE)
    write_yaml(missing_sex, MISSING_SEX_FILE)
    write_yaml(missing_zone, MISSING_ZONE_FILE)
    write_json(npc_data, OUTPUT_JSON)
    print(f"Wrote {len(npc_data)} NPC entries to {OUTPUT_JSON}")
