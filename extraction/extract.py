#!/usr/bin/env python3

import csv
import mysql.connector
import os

# =========================
# CONFIG
# =========================

DB_CONFIG = {
    "host": "localhost",
    "user": "mangos",
    "password": "mangos",
    "database": "classicmangos",
    "charset": "utf8mb4",
    "use_unicode": True,
}

OUTPUT_CSV = "../data/all_npc_dialog.csv"

EXCLUDED_SUBSTRINGS = [
    "attempts to run away in fear",
    "goes into a berserker rage",
    "is possessed",
    "is enraged",
    "begins to cast",
    "dies.",
]

# =========================
# HELPERS
# =========================

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

def is_clean_text(text):
    if text is None: return False
    t = text.strip()
    if not t: return False
    for pattern in EXCLUDED_SUBSTRINGS:
        if pattern.lower() in t.lower(): return False
    return True

def load_existing_corrections(filepath):
    """Maps text content to manual NPC names/IDs from previous runs."""
    corrections = {}
    if not os.path.exists(filepath):
        return corrections
    
    with open(filepath, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            txt = row["text"].strip()
            if row["npc_name"] != "Unknown":
                corrections[txt] = {
                    "npc_name": row["npc_name"],
                    "npc_id": row["npc_id"],
                    "sex": row.get("sex"),
                    "quest_id": row.get("quest_id")
                }
    return corrections

# =========================
# EXTRACTION
# =========================

def extract_all_dialog():
    # 1. Load manual work first
    manual_map = load_existing_corrections(OUTPUT_CSV)
    
    db = get_connection()
    cursor = db.cursor(dictionary=True)

    # Use a dictionary keyed by TEXT to deduplicate and preserve manual fixes
    final_output = {}
    seen_broadcast_ids = set()

    # 2. Get Metadata
    cursor.execute("SELECT Entry, Name, DisplayId1 FROM creature_template")
    npc_meta = {r["Entry"]: r for r in cursor.fetchall()}

    # 3. Define a helper to add rows with preservation logic
    def add_to_final(npc_id, npc_name, sex, d_type, q_id, text, bt_id=None):
        if not is_clean_text(text):
            return
        
        txt_key = text.strip()
        
        # Priority 1: Manual Correction from CSV
        if txt_key in manual_map:
            npc_name = manual_map[txt_key]["npc_name"]
            npc_id = manual_map[txt_key]["npc_id"]
        
        # Priority 2: Don't overwrite a named entry with an 'Unknown' entry
        if txt_key in final_output:
            if final_output[txt_key]["npc_name"] != "Unknown" and npc_name == "Unknown":
                return 

        final_output[txt_key] = {
            "npc_name": npc_name,
            "npc_id": npc_id,
            "sex": sex,
            "dialog_type": d_type,
            "quest_id": q_id,
            "text": txt_key,
        }
        if bt_id: seen_broadcast_ids.add(bt_id)

    # --- START DATA GATHERING ---

    # A. Broadcast Text (Gossip/AI)
    cursor.execute("""
        SELECT DISTINCT ct.Entry, ct.Name, bt.Id as bt_id, bt.Text, bt.Text1
        FROM creature_template ct
        LEFT JOIN gossip_menu gm ON gm.entry = ct.GossipMenuId
        LEFT JOIN npc_text_broadcast_text ntbt ON ntbt.Id = gm.text_id
        LEFT JOIN creature_ai_scripts cas ON cas.creature_id = ct.Entry
        JOIN broadcast_text bt ON (
            bt.Id IN (ntbt.BroadcastTextId0, ntbt.BroadcastTextId1, ntbt.BroadcastTextId2) OR
            (cas.action1_type = 1 AND bt.Id = cas.action1_param1)
        )
    """)
    for r in cursor.fetchall():
        txt = r["Text"] if r["Text"] else r["Text1"]
        add_to_final(r["Entry"], r["Name"], None, "broadcast", None, txt, r["bt_id"])

    # B. Quest Text
    cursor.execute("""
        SELECT qt.entry, qt.Details, qt.RequestItemsText, qt.OfferRewardText, cqr.id as npc_id
        FROM quest_template qt 
        JOIN creature_questrelation cqr ON qt.entry = cqr.quest
    """)
    for r in cursor.fetchall():
        meta = npc_meta.get(r["npc_id"], {"Name": "Unknown"})
        add_to_final(r["npc_id"], meta["Name"], None, "quest", r["entry"], r["Details"])

    # C. The Orphan Sweep
    cursor.execute("SELECT Id, Text, Text1 FROM broadcast_text WHERE Id > 0")
    for r in cursor.fetchall():
        if r["Id"] not in seen_broadcast_ids:
            txt = r["Text"] if r["Text"] else r["Text1"]
            add_to_final(f"orphan_{r['Id']}", "Unknown", None, "orphan", None, txt)

    cursor.close()
    db.close()
    return list(final_output.values())

# =========================
# WRITE CSV
# =========================

if __name__ == "__main__":
    data = extract_all_dialog()
    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["npc_name", "npc_id", "sex", "dialog_type", "quest_id", "text"])
        writer.writeheader()
        writer.writerows(data)
    print(f"Extraction complete. {len(data)} unique lines processed.")