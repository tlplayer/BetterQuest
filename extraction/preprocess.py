import pandas as pd
import json

from collections import defaultdict
import yaml

# Example file paths (replace with your real files)
RACE_FILE = "../data/npc_race.yaml"
SEX_FILE = "../data/npc_sex.yaml"
ZONE_FILE = "../data/npc_zone.yaml"

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

    df["npc_name"] = df["npc_name"].astype(str).str.strip()
    df["sex"] = df["sex"].map(SEX_MAP)

    records = []

    for _, row in df.iterrows():
        name = row.npc_name
        race = race_lookup.get(name)
        sex = row.sex or sex_lookup.get(name)
        zone = zone_lookup.get(name)

        # Simplified narrator logic
        if race:
            narrator = race + ("_female" if sex == "female" else "")
        else:
            narrator = "default"

        records.append({
            "npc_id": row.npc_id,
            "name": name,
            "id": None,                 
            "race": race,
            "sex": sex,
            "dialog_type": row.dialog_type,
            "zone": zone,
            "narrator": narrator,
            "portrait": None,
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

def invert_mapping(mapping):
    """
    Converts {category: [names]} into {name: category} for easy lookup
    """
    inverted = {}
    for key, names in mapping.items():
        for name in names:
            inverted[name.strip()] = key
    return inverted

def write_json(data, output_path):
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
     # Read and invert mappings for easy lookup
    npc_race = invert_mapping(read_mapping(RACE_FILE))
    npc_sex = invert_mapping(read_mapping(SEX_FILE))
    npc_zone = invert_mapping(read_mapping(ZONE_FILE))

    # Extract NPCs and fill race/sex/zone/narrator automatically
    npc_data = extract_unique_npcs(CSV_PATH, npc_race, npc_sex, npc_zone)    
    write_json(npc_data, OUTPUT_JSON)
    print(f"Wrote {len(npc_data)} NPC entries to {OUTPUT_JSON}")
