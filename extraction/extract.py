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

# =========================
# DB CONNECTION
# =========================

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

def non_empty(text):
    return text is not None and text.strip() != ""

# =========================
# EXTRACTION
# = ::::::::::::::::::::: =

def extract_all_dialog():
    db = get_connection()
    cursor = db.cursor(dictionary=True)

    rows = []
    seen_broadcast_ids = set()  # Track IDs to find orphans later

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

    # 2. BROADCAST TEXT (via gossip_menu)
    cursor.execute("""
        SELECT DISTINCT
            ct.Entry AS npc_id,
            bt.Id AS bt_id,
            bt.Text AS text,
            bt.Text1 AS text1
        FROM creature_template ct
        JOIN gossip_menu gm ON gm.entry = ct.GossipMenuId
        JOIN npc_text_broadcast_text ntbt ON ntbt.Id = gm.text_id
        JOIN broadcast_text bt ON bt.Id IN (
            ntbt.BroadcastTextId0, ntbt.BroadcastTextId1, ntbt.BroadcastTextId2, ntbt.BroadcastTextId3,
            ntbt.BroadcastTextId4, ntbt.BroadcastTextId5, ntbt.BroadcastTextId6, ntbt.BroadcastTextId7
        )
    """)
    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["text"] if non_empty(row["text"]) else row["text1"]
        if npc and non_empty(txt):
            rows.append({
                "npc_name": npc["npc_name"],
                "npc_id": npc["npc_id"],
                "sex": npc["sex"],
                "dialog_type": "gossip",
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 3. QUEST TEXTS (Accept, Progress, Complete, Objectives)
    # Using a combined query for efficiency
    cursor.execute("""
        SELECT qt.entry AS quest_id, qt.Details, qt.RequestItemsText, qt.OfferRewardText, qt.Objectives,
               cqr.id AS accept_npc, cir.id AS complete_npc
        FROM quest_template qt
        LEFT JOIN creature_questrelation cqr ON qt.entry = cqr.quest
        LEFT JOIN creature_involvedrelation cir ON qt.entry = cir.quest
    """)
    for row in cursor.fetchall():
        for n_id, d_type, field in [
            (row["accept_npc"], "quest_accept", "Details"),
            (row["accept_npc"], "quest_progress", "RequestItemsText"),
            (row["complete_npc"], "quest_complete", "OfferRewardText"),
            (row["accept_npc"], "quest_objectives", "Objectives")
        ]:
            npc = npc_meta.get(n_id)
            if npc and non_empty(row[field]):
                rows.append({
                    "npc_name": npc["npc_name"], "npc_id": npc["npc_id"], "sex": npc["sex"],
                    "dialog_type": d_type, "quest_id": row["quest_id"], "text": row[field].strip()
                })

    # 4. BROADCAST TEXT RESOLVER (Creature_AI_Scripts)
    cursor.execute("""
        SELECT DISTINCT
            ct.Entry AS npc_id, bt.Id AS bt_id, bt.Text AS t0, bt.Text1 AS t1
        FROM creature_ai_scripts cas
        JOIN creature_template ct ON cas.creature_id = ct.Entry
        JOIN broadcast_text bt ON (
            (cas.action1_type = 1 AND bt.Id = cas.action1_param1) OR
            (cas.action2_type = 1 AND bt.Id = cas.action2_param1) OR
            (cas.action3_type = 1 AND bt.Id = cas.action3_param1)
        )
    """)
    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["t0"] if row["t0"] else row["t1"]
        if non_empty(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown AI",
                "npc_id": row["npc_id"], "sex": npc["sex"] if npc else None,
                "dialog_type": "broadcast_ai", "quest_id": None, "text": txt.strip()
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 5. THE ORPHAN SWEEP (Everything else in broadcast_text)
    # This puts all unlinked text at the end of the file
    cursor.execute("SELECT Id, Text, Text1 FROM broadcast_text")
    for row in cursor.fetchall():
        if row["Id"] not in seen_broadcast_ids:
            txt = row["Text"] if non_empty(row["Text"]) else row["Text1"]
            if non_empty(txt):
                rows.append({
                    "npc_name": "Unknown",
                    "npc_id": f"orphan_bt_{row['Id']}",
                    "sex": None,
                    "dialog_type": "broadcast_orphan",
                    "quest_id": None,
                    "text": txt.strip(),
                })

    cursor.close()
    db.close()
    return rows

if __name__ == "__main__":
    data = extract_all_dialog()
    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["npc_name", "npc_id", "sex", "dialog_type", "quest_id", "text"])
        writer.writeheader()
        writer.writerows(data)
    print(f"Extracted {len(data)} rows. Check the end of the file for 'Unknown' orphans.")