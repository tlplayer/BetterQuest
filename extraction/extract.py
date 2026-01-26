#!/usr/bin/env python3

import csv
import mysql.connector

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

# Add generic system/combat strings here to ignore them
# These are emotes and combat messages we don't want to narrate
EXCLUDED_SUBSTRINGS = [
    "attempts to run away in fear",
    "goes into a berserker rage",
    "is possessed",
    "is enraged",
    "begins to cast",
    "dies.",
    "flees in terror",
    "becomes enraged",
    "goes into a frenzy",
]

# =========================
# HELPERS
# =========================

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

def is_clean_text(text):
    """Checks if text is non-empty and doesn't contain generic combat noise."""
    if text is None:
        return False
    
    t = text.strip()
    if not t:
        return False
    
    # Check against the exclusion list (case-insensitive)
    for pattern in EXCLUDED_SUBSTRINGS:
        if pattern.lower() in t.lower():
            return False
            
    return True

# =========================
# EXTRACTION
# =========================

def extract_all_dialog():
    db = get_connection()
    cursor = db.cursor(dictionary=True)

    rows = []
    seen_broadcast_ids = set()

    # 1. BASE NPC METADATA
    cursor.execute("""
        SELECT
            ct.Entry        AS npc_id,
            ct.Name         AS npc_name,
            ct.GossipMenuId AS gossip_menu_id,
            ct.DisplayId1   AS model_id,
            cmi.gender      AS sex
        FROM creature_template ct
        LEFT JOIN creature_model_info cmi ON cmi.modelid = ct.DisplayId1
    """)
    npc_meta = {r["npc_id"]: r for r in cursor.fetchall()}

    # 2. BROADCAST TEXT - Multiple Sources
    # 2a. AI Scripts (action1, action2, action3)
    cursor.execute("""
        SELECT DISTINCT
            ct.Entry AS npc_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1,
            'ai_script' as dialog_type
        FROM creature_template ct
        JOIN creature_ai_scripts cas ON cas.creature_id = ct.Entry
        JOIN broadcast_text bt ON (
            (cas.action1_type = 1 AND bt.Id = cas.action1_param1) OR
            (cas.action2_type = 1 AND bt.Id = cas.action2_param1) OR
            (cas.action3_type = 1 AND bt.Id = cas.action3_param1)
        )
        WHERE bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "npc_id": row["npc_id"],
                "sex": npc["sex"] if npc else None,
                "dialog_type": row["dialog_type"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 2b. Gossip Text
    cursor.execute("""
        SELECT DISTINCT
            ct.Entry AS npc_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1,
            'gossip' as dialog_type
        FROM creature_template ct
        JOIN gossip_menu gm ON gm.entry = ct.GossipMenuId
        JOIN npc_text_broadcast_text ntbt ON ntbt.Id = gm.text_id
        JOIN broadcast_text bt ON bt.Id IN (
            ntbt.BroadcastTextId0, ntbt.BroadcastTextId1, ntbt.BroadcastTextId2,
            ntbt.BroadcastTextId3, ntbt.BroadcastTextId4, ntbt.BroadcastTextId5,
            ntbt.BroadcastTextId6, ntbt.BroadcastTextId7
        )
        WHERE bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "npc_id": row["npc_id"],
                "sex": npc["sex"] if npc else None,
                "dialog_type": row["dialog_type"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 2c. Quest Start Scripts
    cursor.execute("""
        SELECT DISTINCT
            cqr.id AS npc_id,
            qt.entry AS quest_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1,
            'quest_start_script' as dialog_type
        FROM dbscripts_on_quest_start dqs
        JOIN broadcast_text bt ON bt.Id = dqs.dataint
        JOIN creature_questrelation cqr ON cqr.quest = dqs.id
        JOIN quest_template qt ON qt.entry = dqs.id
        WHERE dqs.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "npc_id": row["npc_id"],
                "sex": npc["sex"] if npc else None,
                "dialog_type": row["dialog_type"],
                "quest_id": row["quest_id"],
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 2d. Quest End Scripts
    cursor.execute("""
        SELECT DISTINCT
            cir.id AS npc_id,
            qt.entry AS quest_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1,
            'quest_end_script' as dialog_type
        FROM dbscripts_on_quest_end dqe
        JOIN broadcast_text bt ON bt.Id = dqe.dataint
        JOIN creature_involvedrelation cir ON cir.quest = dqe.id
        JOIN quest_template qt ON qt.entry = dqe.id
        WHERE dqe.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "npc_id": row["npc_id"],
                "sex": npc["sex"] if npc else None,
                "dialog_type": row["dialog_type"],
                "quest_id": row["quest_id"],
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 2e. Event Scripts
    cursor.execute("""
        SELECT DISTINCT
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1,
            'event_script' as dialog_type
        FROM dbscripts_on_event dse
        JOIN broadcast_text bt ON bt.Id = dse.dataint
        WHERE dse.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": "Unknown",
                "npc_id": f"event_{row['bt_id']}",
                "sex": None,
                "dialog_type": row["dialog_type"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 3. QUEST TEXTS (Accept, Progress, Complete, Objectives)
    cursor.execute("""
        SELECT qt.entry AS quest_id, qt.Details, qt.RequestItemsText, qt.OfferRewardText, qt.Objectives,
               cqr.id AS accept_npc, cir.id AS complete_npc
        FROM quest_template qt
        LEFT JOIN creature_questrelation cqr ON qt.entry = cqr.quest
        LEFT JOIN creature_involvedrelation cir ON qt.entry = cir.quest
    """)
    for row in cursor.fetchall():
        fields = [
            (row["accept_npc"], "quest_accept", "Details"),
            (row["accept_npc"], "quest_progress", "RequestItemsText"),
            (row["complete_npc"], "quest_complete", "OfferRewardText"),
            (row["accept_npc"], "quest_objectives", "Objectives")
        ]
        for n_id, dialog_type, col in fields:
            npc = npc_meta.get(n_id)
            if npc and is_clean_text(row[col]):
                rows.append({
                    "npc_name": npc["npc_name"], 
                    "npc_id": npc["npc_id"], 
                    "sex": npc["sex"],
                    "dialog_type": dialog_type, 
                    "quest_id": row["quest_id"], 
                    "text": row[col].strip()
                })

    # 4. THE FINAL SWEEP (Orphans / Unlinked text)
    cursor.execute("SELECT Id, Text, Text1 FROM broadcast_text WHERE Id > 0")
    for row in cursor.fetchall():
        if row["Id"] not in seen_broadcast_ids:
            txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
            if is_clean_text(txt):
                rows.append({
                    "npc_name": "Unknown",
                    "npc_id": f"orphan_{row['Id']}",
                    "sex": None,
                    "dialog_type": "broadcast_orphan",
                    "quest_id": None,
                    "text": txt.strip(),
                })

    cursor.close()
    db.close()
    return rows

# =========================
# WRITE CSV
# =========================

if __name__ == "__main__":
    data = extract_all_dialog()
    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["npc_name", "npc_id", "sex", "dialog_type", "quest_id", "text"])
        writer.writeheader()
        writer.writerows(data)
    print(f"Extracted {len(data)} lines. Combat noise filtered.")