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

OUTPUT_CSV = "all_npc_dialog.csv"

# =========================
# DB CONNECTION
# =========================

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

# =========================
# HELPERS
# =========================

def non_empty(text):
    return text is not None and text.strip() != ""

# =========================
# EXTRACTION
# =========================

def extract_all_dialog():
    db = get_connection()
    cursor = db.cursor(dictionary=True)

    rows = []

    # -------------------------------------------------
    # BASE NPC METADATA
    # -------------------------------------------------

    cursor.execute("""
        SELECT
            ct.Entry        AS npc_id,
            ct.Name         AS npc_name,
            ct.GossipMenuId AS gossip_menu_id,
            ct.DisplayId1   AS model_id,
            cmi.gender      AS sex,
            cmr.racemask    AS race_mask
        FROM creature_template ct
        LEFT JOIN creature_model_info cmi
            ON cmi.modelid = ct.DisplayId1
        LEFT JOIN creature_model_race cmr
            ON cmr.modelid = ct.DisplayId1
    """)

    npc_meta = {r["npc_id"]: r for r in cursor.fetchall()}

    # -------------------------------------------------
    # GOSSIP TEXT (npc_text)
    # -------------------------------------------------

    cursor.execute("""
        SELECT
            ct.Entry AS npc_id,
            nt.*
        FROM creature_template ct
        JOIN gossip_menu gm
            ON gm.entry = ct.GossipMenuId
        JOIN npc_text nt
            ON nt.ID = gm.text_id
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if not npc:
            continue

        for i in range(8):
            for j in range(2):
                field = f"text{i}_{j}"
                text = row.get(field)
                if non_empty(text):
                    rows.append({
                        "npc_id": npc["npc_id"],
                        "npc_name": npc["npc_name"],
                        "race_mask": npc["race_mask"],
                        "sex": npc["sex"],
                        "model_id": npc["model_id"],
                        "dialog_type": "gossip",
                        "quest_id": None,
                        "text": text.strip(),
                    })

    # -------------------------------------------------
    # QUEST ACCEPT / PROGRESS TEXT
    # -------------------------------------------------

    cursor.execute("""
        SELECT
            cqr.id       AS npc_id,
            qt.entry     AS quest_id,
            qt.Details,
            qt.RequestItemsText
        FROM creature_questrelation cqr
        JOIN quest_template qt
            ON qt.entry = cqr.quest
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if not npc:
            continue

        if non_empty(row["Details"]):
            rows.append({
                "npc_id": npc["npc_id"],
                "npc_name": npc["npc_name"],
                "race_mask": npc["race_mask"],
                "sex": npc["sex"],
                "model_id": npc["model_id"],
                "dialog_type": "quest_accept",
                "quest_id": row["quest_id"],
                "text": row["Details"].strip(),
            })

        if non_empty(row["RequestItemsText"]):
            rows.append({
                "npc_id": npc["npc_id"],
                "npc_name": npc["npc_name"],
                "race_mask": npc["race_mask"],
                "sex": npc["sex"],
                "model_id": npc["model_id"],
                "dialog_type": "quest_progress",
                "quest_id": row["quest_id"],
                "text": row["RequestItemsText"].strip(),
            })

    # -------------------------------------------------
    # QUEST COMPLETE TEXT
    # -------------------------------------------------

    cursor.execute("""
        SELECT
            cir.id       AS npc_id,
            qt.entry     AS quest_id,
            qt.OfferRewardText
        FROM creature_involvedrelation cir
        JOIN quest_template qt
            ON qt.entry = cir.quest
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if npc and non_empty(row["OfferRewardText"]):
            rows.append({
                "npc_id": npc["npc_id"],
                "npc_name": npc["npc_name"],
                "race_mask": npc["race_mask"],
                "sex": npc["sex"],
                "model_id": npc["model_id"],
                "dialog_type": "quest_complete",
                "quest_id": row["quest_id"],
                "text": row["OfferRewardText"].strip(),
            })

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
        if npc and non_empty(row["text"]):
            rows.append({
                "npc_id": npc["npc_id"],
                "npc_name": npc["npc_name"],
                "race_mask": npc["race_mask"],
                "sex": npc["sex"],
                "model_id": npc["model_id"],
                "dialog_type": "quest_greeting",
                "quest_id": None,
                "text": row["text"].strip(),
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
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "npc_id",
                "npc_name",
                "race_mask",
                "sex",
                "model_id",
                "dialog_type",
                "quest_id",
                "text",
            ],
        )
        writer.writeheader()
        writer.writerows(data)

    print(f"Extracted {len(data)} dialog rows → {OUTPUT_CSV}")
