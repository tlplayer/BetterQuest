#!/usr/bin/env python3

import csv
import yaml
import os
import mysql.connector
from collections import defaultdict

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
RACE_YAML = "../data/npc_race.yaml"
SEX_YAML = "../data/npc_sex.yaml"

# https://wowpedia.fandom.com/wiki/RaceId
RACE_DICT = {
    -1: 'narrator',
    1: 'human',
    2: 'orc',
    3: 'dwarf',
    4: 'nightelf',
    5: 'scourge',
    6: 'tauren',
    7: 'gnome',
    8: 'troll',
    9: 'goblin',
    10: 'bloodelf',
    11: 'draenei',
    12: 'felorc',
    13: 'naga',
    14: 'broken',
    15: 'skeleton',
    16: 'vrykul',
    17: 'tuskarr',
    18: 'foresttroll',
    19: 'taunka',
    20: 'northrendskeleton',
    21: 'icetroll',
    22: 'worgen',
    23: 'human',
    24: 'pandaren',
    25: 'pandaren',
    26: 'pandaren',
    27: 'nightborne',
    28: 'highmountaintauren',
    29: 'voidelf',
    30: 'lightforgeddraenei',
    31: 'zandalari',
    32: 'kultiran',
    33: 'thinhuman',
    34: 'darkirondwarf',
    35: 'vulpera',
    36: 'magharorc',
    37: 'mechagnome',
    52: 'dracthyr',
    70: 'dracthyr'
}

GENDER_DICT = {0: 'male', 1: 'female'}

# Add generic system/combat strings here to ignore them
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
    "%s ",  # Generic placeholder combat messages
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

def load_existing_yaml(filepath):
    """Load existing YAML file if it exists, otherwise return empty dict."""
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    return {}

def discover_new_race_gender_mappings(db):
    """
    Discover unmapped DisplayRaceID and DisplaySexID values from the database.
    Returns dict of new mappings with sample NPC names.
    """
    cursor = db.cursor(dictionary=True)
    
    # Find all unique race/gender combinations with example NPCs
    cursor.execute("""
        SELECT DISTINCT
            cdix.DisplayRaceID,
            cdix.DisplaySexID,
            ct.name AS example_npc
        FROM creature_template ct
        LEFT JOIN db_CreatureDisplayInfo cdi ON cdi.ID = ct.DisplayId1
        LEFT JOIN db_CreatureDisplayInfoExtra cdix ON cdix.ID = cdi.ExtendedDisplayInfoID
        WHERE cdix.DisplayRaceID IS NOT NULL
        ORDER BY cdix.DisplayRaceID, cdix.DisplaySexID
    """)
    
    results = cursor.fetchall()
    cursor.close()
    
    # Group by race/gender ID
    unmapped_races = defaultdict(list)
    unmapped_genders = defaultdict(list)
    
    for row in results:
        race_id = row['DisplayRaceID']
        gender_id = row['DisplaySexID']
        npc_name = row['example_npc']
        
        if race_id not in RACE_DICT and npc_name:
            unmapped_races[race_id].append(npc_name)
        
        if gender_id not in GENDER_DICT and npc_name:
            unmapped_genders[gender_id].append(npc_name)
    
    return unmapped_races, unmapped_genders

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

    # 2. SCRIPT_TEXTS (C++ ScriptDev2 system)
    cursor.execute("""
        SELECT
            st.entry AS script_entry,
            st.content_default AS text,
            st.broadcast_text_id,
            st.comment,
            ct.Entry AS npc_id,
            ct.Name AS npc_name
        FROM script_texts st
        LEFT JOIN creature_template ct ON ct.ScriptName IS NOT NULL
            AND st.comment LIKE CONCAT(LOWER(REPLACE(ct.Name, ' ', '_')), '%')
        WHERE st.entry < 0
            AND st.content_default IS NOT NULL
            AND st.content_default != ''
    """)
    
    for row in cursor.fetchall():
        txt = row["text"]
        if is_clean_text(txt):
            # Try to extract NPC name from comment if not linked
            npc_name = row["npc_name"]
            if not npc_name and row["comment"]:
                # Comment format is usually "npc_name SAY_SOMETHING"
                npc_name = row["comment"].split()[0].replace('_', ' ').title()
            
            rows.append({
                "npc_name": npc_name or "Unknown",
                "sex": npc_meta.get(row["npc_id"], {}).get("sex") if row["npc_id"] else None,
                "dialog_type": "script",
                "quest_id": None,
                "text": txt.strip(),
            })
            if row["broadcast_text_id"]:
                seen_broadcast_ids.add(row["broadcast_text_id"])

    # 3. DBSCRIPTS - CREATURE_DEATH
    cursor.execute("""
        SELECT DISTINCT
            d.id AS script_id,
            d.dataint AS bt_id,
            d.buddy_entry,
            bt.Text,
            bt.Text1,
            COALESCE(ct_buddy.Name, 'Unknown') AS npc_name,
            COALESCE(cmi.gender, 0) AS sex
        FROM dbscripts_on_creature_death d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        LEFT JOIN creature_template ct_buddy ON ct_buddy.Entry = d.buddy_entry
        LEFT JOIN creature_model_info cmi ON cmi.modelid = ct_buddy.DisplayId1
        WHERE d.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if is_clean_text(txt):
            rows.append({
                "npc_name": row["npc_name"],
                "sex": row["sex"],
                "dialog_type": "event",
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 4. DBSCRIPTS - CREATURE_MOVEMENT
    cursor.execute("""
        SELECT DISTINCT
            d.id AS script_id,
            d.dataint AS bt_id,
            d.buddy_entry,
            bt.Text,
            bt.Text1,
            COALESCE(ct_buddy.Name, ct_main.Name, 'Unknown') AS npc_name,
            COALESCE(cmi_buddy.gender, cmi_main.gender, 0) AS sex
        FROM dbscripts_on_creature_movement d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        LEFT JOIN creature_template ct_buddy ON ct_buddy.Entry = d.buddy_entry
        LEFT JOIN creature_model_info cmi_buddy ON cmi_buddy.modelid = ct_buddy.DisplayId1
        LEFT JOIN creature_template ct_main ON ct_main.Entry = FLOOR(d.id / 100)
        LEFT JOIN creature_model_info cmi_main ON cmi_main.modelid = ct_main.DisplayId1
        WHERE d.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if is_clean_text(txt):
            rows.append({
                "npc_name": row["npc_name"],
                "sex": row["sex"],
                "dialog_type": "movement",
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 5. DBSCRIPTS - RELAY
    cursor.execute("""
        SELECT DISTINCT
            d.id AS script_id,
            d.dataint AS bt_id,
            d.buddy_entry,
            bt.Text,
            bt.Text1,
            COALESCE(ct_buddy.Name, ct_relay.Name, 'Unknown') AS npc_name,
            COALESCE(cmi_buddy.gender, cmi_relay.gender, 0) AS sex
        FROM dbscripts_on_relay d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        LEFT JOIN creature_template ct_buddy ON ct_buddy.Entry = d.buddy_entry
        LEFT JOIN creature_model_info cmi_buddy ON cmi_buddy.modelid = ct_buddy.DisplayId1
        LEFT JOIN creature_template ct_relay ON ct_relay.Entry = d.id AND d.buddy_entry = 0
        LEFT JOIN creature_model_info cmi_relay ON cmi_relay.modelid = ct_relay.DisplayId1
        WHERE d.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if is_clean_text(txt):
            rows.append({
                "npc_name": row["npc_name"],
                "sex": row["sex"],
                "dialog_type": "event",
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 6. DBSCRIPTS - QUEST START
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

    # 7. DBSCRIPTS - QUEST END
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

    # 8. DBSCRIPTS - OTHER TABLES (event, gossip, go_use, go_template_use)
    dbscript_tables = [
        ("dbscripts_on_event", "dse"),
        ("dbscripts_on_gossip", "dsg"),
        ("dbscripts_on_go_template_use", "dsgt"),
        ("dbscripts_on_go_use", "dsgu"),
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
                    "dialog_type": "event",
                    "quest_id": None,
                    "text": txt.strip(),
                })
                seen_broadcast_ids.add(row["bt_id"])

    # 9. AI SCRIPTS (action1, action2, action3)
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
                "dialog_type": "combat",
                "quest_id": None,
                "text": txt.strip(),
            })
            seen_broadcast_ids.add(row["bt_id"])

    # 10. GOSSIP TEXT
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

    # 11. OBJECT TEXT (plaques, graves, books on the ground etc)
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

    # page_text lookup
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

    # 12. ITEM TEXT (letters, books, quest items)
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

    # 13. QUEST GREETINGS
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

    # 14. TRAINER GREETINGS
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

    # 15. QUEST TEXTS (Accept, Progress, Complete, Objectives)
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

    # 16. THE FINAL SWEEP (Orphans / Unlinked text)
    cursor.execute("SELECT Id, Text, Text1 FROM broadcast_text WHERE Id > 0")
    for row in cursor.fetchall():
        if row["Id"] not in seen_broadcast_ids:
            txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
            if is_clean_text(txt):
                rows.append({
                    "npc_name": "Unknown",
                    "sex": None,
                    "dialog_type": "unknown",
                    "quest_id": None,
                    "text": txt.strip(),
                })

    cursor.close()
    return rows, db

def export_race_sex_yaml(db, dialog_rows):
    """
    Export race/gender YAML files for NPCs in dialog.
    Preserves existing mappings and only adds new ones.
    """
    print("\n" + "="*60)
    print("EXPORTING RACE/SEX DATA")
    print("="*60)
    
    # Load existing YAML files
    existing_race_dict = load_existing_yaml(RACE_YAML)
    existing_sex_dict = load_existing_yaml(SEX_YAML)
    
    print(f"Loaded {len(existing_race_dict)} existing race categories")
    print(f"Loaded {len(existing_sex_dict)} existing sex categories")
    
    # Discover unmapped race/gender IDs
    print("\nDiscovering unmapped DisplayRaceID and DisplaySexID values...")
    unmapped_races, unmapped_genders = discover_new_race_gender_mappings(db)
    
    if unmapped_races:
        print(f"\nFound {len(unmapped_races)} unmapped DisplayRaceID values:")
        for race_id, examples in sorted(unmapped_races.items())[:10]:
            print(f"  DisplayRaceID {race_id}: {examples[:3]}")
        print(f"\nConsider adding these to RACE_DICT in the script!")
    
    if unmapped_genders:
        print(f"\nFound {len(unmapped_genders)} unmapped DisplaySexID values:")
        for gender_id, examples in sorted(unmapped_genders.items())[:10]:
            print(f"  DisplaySexID {gender_id}: {examples[:3]}")
        print(f"\nConsider adding these to GENDER_DICT in the script!")
    
    # Get unique NPC names from dialog
    dialog_npc_names = set(row['npc_name'] for row in dialog_rows if row['npc_name'] != 'Unknown')
    print(f"\nProcessing {len(dialog_npc_names)} unique NPCs from dialog...")
    
    cursor = db.cursor(dictionary=True)
    
    # Get race/gender data for NPCs in dialog
    cursor.execute("""
        SELECT DISTINCT 
            ct.name AS npc_name,
            cdix.DisplayRaceID,
            cdix.DisplaySexID
        FROM creature_template ct
        LEFT JOIN db_CreatureDisplayInfo cdi ON cdi.ID = ct.DisplayId1
        LEFT JOIN db_CreatureDisplayInfoExtra cdix ON cdix.ID = cdi.ExtendedDisplayInfoID
        WHERE ct.name IS NOT NULL
    """)
    
    npc_race_sex = {}
    for row in cursor.fetchall():
        if row['npc_name'] in dialog_npc_names:
            npc_race_sex[row['npc_name']] = {
                'race_id': row['DisplayRaceID'],
                'sex_id': row['DisplaySexID']
            }
    
    cursor.close()
    
    # Build new race dictionary (preserve existing + add new)
    race_dict = dict(existing_race_dict)  # Copy existing
    
    for npc_name, data in npc_race_sex.items():
        race_id = data['race_id']
        race = RACE_DICT.get(race_id, 'unknown')
        
        # Add to appropriate category
        if race not in race_dict:
            race_dict[race] = []
        if npc_name not in race_dict[race]:
            race_dict[race].append(npc_name)
    
    # Build new sex dictionary (preserve existing + add new)
    sex_dict = dict(existing_sex_dict)  # Copy existing
    
    for npc_name, data in npc_race_sex.items():
        sex_id = data['sex_id']
        gender = GENDER_DICT.get(sex_id, 'unknown')
        
        # Add to appropriate category
        if gender not in sex_dict:
            sex_dict[gender] = []
        if npc_name not in sex_dict[gender]:
            sex_dict[gender].append(npc_name)
    
    # Sort all lists alphabetically
    for race in race_dict:
        race_dict[race] = sorted(set(race_dict[race]))
    for gender in sex_dict:
        sex_dict[gender] = sorted(set(sex_dict[gender]))
    
    # Write YAML files
    print("\nWriting YAML files...")
    
    with open(RACE_YAML, 'w', encoding='utf-8') as f:
        yaml.dump(race_dict, f, allow_unicode=True, 
                  default_flow_style=False, sort_keys=True)
    print(f"  ✓ {RACE_YAML}")
    
    with open(SEX_YAML, 'w', encoding='utf-8') as f:
        yaml.dump(sex_dict, f, allow_unicode=True, 
                  default_flow_style=False, sort_keys=True)
    print(f"  ✓ {SEX_YAML}")
    
    # Print summary
    print(f"\n{'='*60}")
    print("Race Distribution:")
    print(f"{'='*60}")
    for race in sorted(race_dict.keys()):
        count = len(race_dict[race])
        print(f"  {race:20s}: {count:4d} NPCs")
    
    print(f"\n{'='*60}")
    print("Gender Distribution:")
    print(f"{'='*60}")
    for gender in sorted(sex_dict.keys()):
        count = len(sex_dict[gender])
        print(f"  {gender:20s}: {count:4d} NPCs")

# =========================
# WRITE CSV
# =========================

if __name__ == "__main__":
    print("Extracting dialog...")
    data, db = extract_all_dialog()
    
    print(f"\nWriting CSV with {len(data)} dialog lines...")
    with open(OUTPUT_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["npc_name", "sex", "dialog_type", "quest_id", "text"])
        writer.writeheader()
        writer.writerows(data)
    print(f"  ✓ {OUTPUT_CSV}")
    
    # Export race/sex YAML files
    export_race_sex_yaml(db, data)
    
    db.close()
    
    print(f"\n✓ All extractions complete!")