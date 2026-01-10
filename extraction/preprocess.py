import pandas as pd
import json

CSV_PATH = "/home/tplayer/Applications/Wow/Interface/AddOns/BetterQuest/data/all_npc_dialog.csv"
OUTPUT_JSON = "npc_metadata_seed.json"

SEX_MAP = {
    0: "male",
    1: "female",
}

def extract_unique_npcs(csv_path: str):
    df = pd.read_csv(csv_path)

    # Keep only what we need at this stage
    df = df[
        ["npc_id", "npc_name", "sex", "model_id", "dialog_type"]
    ].dropna(subset=["npc_name"])

    # Deduplicate by npc_id (authoritative)
    df = df.drop_duplicates(subset=["npc_id"])
    df = df[df["dialog_type"] != "item_text"]

    # Normalize fields
    df["npc_name"] = df["npc_name"].astype(str).str.strip()
    df["sex"] = df["sex"].map(SEX_MAP)

    records = []

    for _, row in df.iterrows():
        records.append({
            "npc_id": row.npc_id,
            "name": row.npc_name,
            "id": None,                 # filled later (quest_id, item_id, etc)
            "race": None,               # inferred later
            "sex": row.sex,
            "dialog_type": row.dialog_type,
            "zone": None,               # inferred later
            "narrator": "default",      # LLM may override
            "portrait": None,           # generic first
            "model_id": (
                int(row.model_id)
                if not pd.isna(row.model_id)
                else None
            ),
        })

    return sorted(records, key=lambda x: x["name"])


def write_json(data, output_path):
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    npc_data = extract_unique_npcs(CSV_PATH)
    write_json(npc_data, OUTPUT_JSON)
    print(f"Wrote {len(npc_data)} NPC entries to {OUTPUT_JSON}")
