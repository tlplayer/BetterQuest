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
            bt.Text1
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
                "sex": npc["sex"] if npc else None,
                "dialog_type": "gossip",
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
            bt.Text1
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
                "sex": npc["sex"] if npc else None,
                "dialog_type": "gossip",
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
            bt.Text1
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
                "sex": npc["sex"] if npc else None,
                "dialog_type": "quest_start_script",
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
            bt.Text1
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
                "sex": npc["sex"] if npc else None,
                "dialog_type": "quest_end_script",
                "quest_id": row["quest_id"],
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 2e-j. All other dbscripts (gossip-type dialogue)
    dbscript_tables = [
        ("dbscripts_on_event", "dse"),
        ("dbscripts_on_creature_movement", "dscm"),
        ("dbscripts_on_gossip", "dsg"),
        ("dbscripts_on_relay", "dsr"),
        ("dbscripts_on_go_template_use", "dsgt"),
        ("dbscripts_on_creature_death", "dscd"),
    ]
    
    for table, alias in dbscript_tables:
        cursor.execute(f"""
            SELECT DISTINCT
                bt.Id AS bt_id,
                bt.Text,
                bt.Text1
            FROM {table} {alias}
            JOIN broadcast_text bt ON bt.Id = {alias}.dataint
            WHERE {alias}.command = 0 AND bt.Id > 0
        """)
        
        for row in cursor.fetchall():
            txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
            
            if is_clean_text(txt):
                rows.append({
                    "npc_name": "Unknown",
                    "sex": None,
                    "dialog_type": "gossip",
                    "quest_id": None,
                    "text": txt.strip(),
                })
                seen_broadcast_ids.add(row["bt_id"])
    
# -------------------------------------------------
    # OBJECT TEXT (plaques, graves, books on the ground etc)
    # -------------------------------------------------

    cursor.execute("""
        SELECT
            got.entry AS go_id,
            got.name  AS go_name,
            got.data0 AS page_id
        FROM gameobject_template got
        WHERE got.type = 9
        AND got.data0 IS NOT NULL
    """)

    gameobjects = cursor.fetchall()

    # page_text lookup (reuse existing dict)
    cursor.execute("SELECT entry, text, next_page FROM page_text")
    page_dict = {r["entry"]: r for r in cursor.fetchall()}

    for go in gameobjects:
        page_id = go["page_id"]
        while page_id and page_id in page_dict:
            page = page_dict[page_id]
            if is_clean_text(page["text"]):
                rows.append({
                    "npc_name": go["go_name"],
                    "sex": None,
                    "dialog_type": "item_text",
                    "quest_id": None,
                    "text": page["text"].strip(),
                })
            page_id = page["next_page"] if page["next_page"] != 0 else None

    # -------------------------------------------------
    # ITEM TEXT (letters, books, quest items)
    # -------------------------------------------------

    cursor.execute("""
        SELECT
            it.entry AS item_id,
            it.name AS item_name,
            it.startquest AS quest_id,
            it.PageText AS page_id
        FROM item_template it
        WHERE it.PageText IS NOT NULL
    """)

    items = cursor.fetchall()

    for item in items:
        page_id = item["page_id"]
        while page_id and page_id in page_dict:
            page = page_dict[page_id]
            text = page["text"]
            if is_clean_text(text):
                rows.append({
                    "npc_name": item["item_name"],
                    "sex": None,
                    "dialog_type": "item_text",
                    "quest_id": item["quest_id"],
                    "text": text.strip(),
                })
            page_id = page["next_page"] if page["next_page"] != 0 else None

# -------------------------------------------------
    # QUEST GREETINGS
    # -------------------------------------------------
    cursor.execute("""
        SELECT
            Entry AS npc_id,
            Text  AS text
        FROM questgiver_greeting
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if npc and is_clean_text(row["text"]):
            rows.append({
                "npc_name": npc["npc_name"],
                "sex": npc["sex"],
                "dialog_type": "gossip",
                "quest_id": None,
                "text": row["text"].strip(),
            })

    # -------------------------------------------------
    # TRAINER GREETINGS
    # -------------------------------------------------
    cursor.execute("""
        SELECT
            Entry AS npc_id,
            Text  AS text
        FROM trainer_greeting
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if npc and is_clean_text(row["text"]):
            rows.append({
                "npc_name": npc["npc_name"],
                "sex": npc["sex"],
                "dialog_type": "gossip",
                "quest_id": None,
                "text": row["text"].strip(),
            })
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
        for npc_id, dialog_type, col in fields:
            npc = npc_meta.get(npc_id)
            if npc and is_clean_text(row[col]):
                rows.append({
                    "npc_name": npc["npc_name"],
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
                    "sex": None,
                    "dialog_type": "gossip",
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
        writer = csv.DictWriter(f, fieldnames=["npc_name", "sex", "dialog_type", "quest_id", "text"])
        writer.writeheader()
        writer.writerows(data)
    print(f"Extracted {len(data)} lines. Combat noise filtered.")