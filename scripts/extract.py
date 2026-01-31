#!/usr/bin/env python3

"""
MaNGOS NPC Dialog Extraction Script

This script extracts all in-game text spoken by NPCs, displayed on items/objects,
or presented in quests from a MaNGOS Classic database.

DATABASE FLOW (creature-centric):
==================================

1. creature_template
   - Entry (NPC ID) - primary key
   - Name, Subname
   - GossipMenuId -> gossip_menu
   - DisplayId1 -> creature_model_info (for gender)
   
2. gossip_menu (accessed via creature_template.GossipMenuId)
   - entry (gossip menu ID)
   - text_id -> npc_text_broadcast_text
   
3. npc_text_broadcast_text
   - Id -> npc_text.ID
   - BroadcastTextId0..7 -> broadcast_text.Id
   
4. broadcast_text (central text storage)
   - Id (primary key)
   - Text, Text1 (localized strings)
   - Referenced by: dbscripts (dataint), creature_ai_scripts, etc.
   
5. dbscripts_* tables (various event-driven scripts)
   - dbscripts_on_creature_death: id = creature_template.entry
   - dbscripts_on_creature_movement: id = creature_entry * 100 + waypoint_id
   - dbscripts_on_gossip: id = gossip_menu_option.action_script_id
   - dbscripts_on_quest_start: id = quest_template.StartScript
   - dbscripts_on_quest_end: id = quest_template.CompleteScript
   - dbscripts_on_relay: id = unique relay ID (NOT creature entry)
   - dbscripts_on_event: id = event ID (contextual)
   
   Common fields:
   - command (0 = TALK/SAY)
   - dataint -> broadcast_text.Id
   - buddy_entry (optional creature that may speak)
   - data_flags (controls source/target/buddy - NOT PARSED YET)

DIALOG_TYPES (canonical values):
=================================
- quest_accept: Quest offer/details text
- quest_complete: Quest completion text  
- quest_progress: Quest progress check text
- quest_objective: Quest objectives description
- gossip: NPC gossip, greetings, trainer text
- item_text: Books, letters, readable items

ATTRIBUTION CONFIDENCE:
=======================
- CANONICAL: Direct FK joins (gossip, quest relations)
- HEURISTIC: Pattern matching (script_texts comments)
- AMBIGUOUS: buddy_entry without data_flags parsing
- UNKNOWN: Relay scripts, orphan broadcast_text
"""

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

# Canonical dialog types - DO NOT ADD NEW ONES
DIALOG_TYPES = {
    "QUEST_ACCEPT": "quest_accept",
    "QUEST_COMPLETE": "quest_complete",
    "QUEST_OBJECTIVE": "quest_objective",
    "QUEST_PROGRESS": "quest_progress",
    "GOSSIP": "gossip",
    "ITEM_TEXT": "item_text",
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
    # ... rest of race mappings
}

GENDER_DICT = {0: 'male', 1: 'female'}

# System messages to exclude
EXCLUDED_SUBSTRINGS = [
    "attempts to run away in fear",
    "goes into a berserker rage",
    "is possessed",
    "is enraged",
    "begins to cast",
    "REUSE ME",
    "dies.",
    "flees in terror",
    "becomes enraged",
    "goes into a frenzy",
    "%s ",
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

# =========================
# EXTRACTION FUNCTIONS
# =========================

def load_npc_metadata(cursor):
    """
    Load base NPC metadata.
    
    SOURCE: creature_template
    JOINS: creature_model_info (for gender via DisplayId1)
    
    Returns: dict keyed by npc_id with name, gossip_menu_id, sex
    """
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
    return {r["npc_id"]: r for r in cursor.fetchall()}


def extract_scriptdev2_texts(cursor, npc_meta):
    """
    Extract ScriptDev2 C++ script texts.
    
    SOURCE: script_texts
    ATTRIBUTION: HEURISTIC - uses comment field pattern matching
    
    NOTE: NPC attribution is best-effort only. ScriptName matching is unreliable.
    
    FLOW:
    script_texts.entry < 0 (negative IDs)
    -> script_texts.comment LIKE creature_name pattern (HEURISTIC)
    -> creature_template.ScriptName match (if available)
    """
    rows = []
    seen = set()

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
        if not is_clean_text(row["text"]):
            continue

        # Try to extract NPC name from comment (heuristic)
        npc_name = row["npc_name"]
        if not npc_name and row["comment"]:
            npc_name = row["comment"].split()[0].replace('_', ' ').title()

        rows.append({
            "npc_name": npc_name or "Unknown",
            "sex": npc_meta.get(row["npc_id"], {}).get("sex") if row["npc_id"] else None,
            "dialog_type": DIALOG_TYPES["GOSSIP"],  # Best guess - these are spoken lines
            "quest_id": None,
            "text": row["text"].strip(),
        })

        if row["broadcast_text_id"]:
            seen.add(row["broadcast_text_id"])

    return rows, seen


def extract_dbscripts_creature_death(cursor, npc_meta):
    """
    Extract creature death script dialogue.
    
    SOURCE: dbscripts_on_creature_death
    CONTEXT: Triggered when creature dies
    
    PARTICIPANTS:
    - Source: The dying creature (dbscripts_on_creature_death.id = creature_template.entry)
    - Target: The killer (unit or player) - NOT stored in dbscripts table
    - Buddy: Optional creature that may participate (buddy_entry = creature_template.entry)
    
    SPEAKER RESOLUTION (via data_flags):
    From wiki: "Which one of the three (originalSource, originalTarget, buddy) will be 
    used depends on data_flags"
    
    ACTUAL USAGE PATTERNS (from real DB):
    - data_flags=0 (50%): Default - source/buddy speaks to target
    - data_flags=16 (50%): BUDDY_BY_GUID - use buddy_entry as GUID not entry
    
    Theoretical data_flags (from wiki, rarely used in practice):
    - 1 (0x01): BUDDY_AS_TARGET
    - 2 (0x02): REVERSE_DIRECTION  
    - 4 (0x04): SOURCE_TARGETS_SELF
    
    SIMPLIFIED LOGIC (based on actual data):
    - If buddy_entry present → buddy speaks (Town Crier announcing Stitches death)
    - If buddy_entry absent → dying creature speaks
    
    ATTRIBUTION CONFIDENCE: MEDIUM-HIGH
    - We know source = dying creature (id field)
    - Buddy attribution is reliable when present
    - data_flags=16 just changes buddy search method (guid vs entry)
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT
            d.id AS creature_entry,
            d.buddy_entry,
            d.data_flags,
            d.search_radius,
            d.dataint AS bt_id,
            bt.Text,
            bt.Text1,
            d.comments
        FROM dbscripts_on_creature_death d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        WHERE d.command = 0
          AND bt.Id > 0
    """)

    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if not is_clean_text(txt):
            continue

        # Determine speaker based on data_flags
        data_flags = row["data_flags"]
        creature_entry = row["creature_entry"]
        buddy_entry = row["buddy_entry"]
        
        # Parse data_flags bits (from wiki)
        BUDDY_AS_TARGET = (data_flags & 0x01) != 0       # 1
        REVERSE_DIRECTION = (data_flags & 0x02) != 0     # 2
        SOURCE_TARGETS_SELF = (data_flags & 0x04) != 0   # 4
        BUDDY_BY_GUID = (data_flags & 0x10) != 0         # 16 - search by guid not entry
        
        # Real-world patterns from DB: data_flags=0 (default) or 16 (buddy by guid)
        # data_flags=16 means: use buddy_entry as GUID, not entry, but still default direction
        
        # Determine speaker entry
        if buddy_entry:
            # When buddy is specified, buddy usually speaks (based on actual data)
            speaker_entry = buddy_entry
        else:
            # No buddy: dying creature speaks
            speaker_entry = creature_entry
        
        # Get NPC details
        npc = npc_meta.get(speaker_entry) if speaker_entry else None

        rows.append({
            "npc_name": npc["npc_name"] if npc else "Unknown",
            "sex": npc["sex"] if npc else None,
            "dialog_type": DIALOG_TYPES["GOSSIP"],
            "quest_id": None,
            "text": txt.strip(),
        })

        seen.add(row["bt_id"])

    return rows, seen


def extract_dbscripts_creature_movement(cursor, npc_meta):
    """
    Extract creature waypoint movement script dialogue.
    
    SOURCE: dbscripts_on_creature_movement
    CONTEXT: Triggered at waypoint arrival
    
    ID FORMAT: creature_entry * 100 + script_number (01-99)
    Example: Creature 474, script #1 → ID = 47401
    
    PARTICIPANTS:
    - Source: The moving creature (derived from FLOOR(id/100))
    - Target: The moving creature (same as source)
    - Buddy: Optional creature (buddy_entry = creature_template.entry)
    
    SPEAKER RESOLUTION (via data_flags):
    
    ACTUAL USAGE PATTERNS (from real DB):
    - data_flags=0 (73%): Default behavior
    - data_flags=4 (10%): SOURCE_TARGETS_SELF
    - data_flags=7 (9%): Complex multi-flag combo
    - data_flags=23 (3%): Complex multi-flag combo
    - data_flags=16 (1%): BUDDY_BY_GUID
    
    SIMPLIFIED LOGIC (based on actual data):
    - If buddy_entry present → buddy speaks (e.g., Town Crier during Stitches walk)
    - If buddy_entry absent → moving creature speaks
    
    ATTRIBUTION CONFIDENCE: MEDIUM
    - FLOOR(id/100) works for ~95% of cases
    - Some IDs don't follow pattern (17040, 38417, 160005) - fallback to Unknown
    - data_flags mostly affect targeting, not speaker identity
    
    CAVEATS:
    - Some older DBs may use different ID formatting
    - Waypoint-triggered dialogue may be conditional (event-based)
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT
            d.id AS script_id,
            d.buddy_entry,
            d.data_flags,
            d.search_radius,
            d.dataint AS bt_id,
            bt.Text,
            bt.Text1,
            d.comments,
            FLOOR(d.id / 100) AS derived_creature_entry,
            MOD(d.id, 100) AS script_number
        FROM dbscripts_on_creature_movement d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        WHERE d.command = 0
          AND bt.Id > 0
    """)

    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if not is_clean_text(txt):
            continue

        # Determine speaker based on data_flags and actual DB patterns
        data_flags = row["data_flags"]
        creature_entry = row["derived_creature_entry"]
        buddy_entry = row["buddy_entry"]
        script_number = row["script_number"]
        
        # Real-world data_flags patterns from analysis:
        # 0 (most common): default behavior
        # 4: SOURCE_TARGETS_SELF
        # 7: BUDDY_AS_TARGET + REVERSE + SOURCE_TARGETS_SELF
        # 16: BUDDY_BY_GUID (use buddy_entry as guid)
        # 23: multiple flags combined
        
        # For movement scripts, source=target=moving creature
        # When buddy present, context determines who speaks
        
        if buddy_entry:
            # Buddy is specified - buddy usually speaks
            speaker_entry = buddy_entry
        else:
            # No buddy: moving creature speaks
            speaker_entry = creature_entry
        
        # Validate creature exists (catches malformed IDs)
        npc = npc_meta.get(speaker_entry)
        
        # If derived entry doesn't exist, try treating full ID as entry
        # (handles edge cases where ID format is non-standard)
        if speaker_entry == creature_entry and not npc and script_number == 0:
            # Maybe the full ID is the entry (no multiplication)
            speaker_entry = row["script_id"]
            npc = npc_meta.get(speaker_entry)
        
        if not npc:
            speaker_entry = None

        rows.append({
            "npc_name": npc["npc_name"] if npc else "Unknown",
            "sex": npc["sex"] if npc else None,
            "dialog_type": DIALOG_TYPES["GOSSIP"],
            "quest_id": None,
            "text": txt.strip(),
        })

        seen.add(row["bt_id"])

    return rows, seen


def extract_dbscripts_relay(cursor, npc_meta):
    """
    Extract relay script dialogue.
    
    SOURCE: dbscripts_on_relay
    ATTRIBUTION: UNKNOWN - relay IDs are not creature entries
    
    FLOW:
    dbscripts_on_relay.id = unique relay ID (0-9999, 10k-19999, 20k+)
    -> dataint = broadcast_text.Id
    -> NO direct creature link (runtime only)
    
    IMPORTANT: Do NOT join id to creature_template.entry - these are different ID spaces!
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT
            d.id AS relay_id,
            d.dataint AS bt_id,
            bt.Text,
            bt.Text1
        FROM dbscripts_on_relay d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        WHERE d.command = 0
          AND bt.Id > 0
    """)

    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if not is_clean_text(txt):
            continue

        # Relay scripts have no inherent speaker
        rows.append({
            "npc_name": "Unknown",
            "sex": None,
            "dialog_type": DIALOG_TYPES["GOSSIP"],
            "quest_id": None,
            "text": txt.strip(),
        })

        seen.add(row["bt_id"])

    return rows, seen


def extract_dbscripts_quest_start(cursor, npc_meta):
    """
    Extract quest start script dialogue.
    
    SOURCE: dbscripts_on_quest_start, quest_template, creature_questrelation
    ATTRIBUTION: CANONICAL - quest giver is known
    
    FLOW:
    quest_template.StartScript = dbscripts_on_quest_start.id
    -> creature_questrelation.quest = quest_template.entry
    -> creature_questrelation.id = creature_template.entry (quest giver)
    -> dbscripts_on_quest_start.dataint = broadcast_text.Id
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT DISTINCT
            cqr.id AS npc_id,
            qt.entry AS quest_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1
        FROM dbscripts_on_quest_start dqs
        JOIN broadcast_text bt ON bt.Id = dqs.dataint
        JOIN quest_template qt ON qt.StartScript = dqs.id
        JOIN creature_questrelation cqr ON cqr.quest = qt.entry
        WHERE dqs.command = 0 AND bt.Id > 0
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "sex": npc["sex"] if npc else None,
                "dialog_type": DIALOG_TYPES["QUEST_ACCEPT"],
                "quest_id": row["quest_id"],
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    return rows, seen


def extract_dbscripts_quest_end(cursor, npc_meta):
    """
    Extract quest completion script dialogue.
    
    SOURCE: dbscripts_on_quest_end, quest_template, creature_involvedrelation
    ATTRIBUTION: CANONICAL - quest completer is known
    
    FLOW:
    quest_template.CompleteScript = dbscripts_on_quest_end.id
    -> creature_involvedrelation.quest = quest_template.entry
    -> creature_involvedrelation.id = creature_template.entry (quest ender)
    -> dbscripts_on_quest_end.dataint = broadcast_text.Id
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT DISTINCT
            cir.id AS npc_id,
            qt.entry AS quest_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1
        FROM dbscripts_on_quest_end dqe
        JOIN broadcast_text bt ON bt.Id = dqe.dataint
        JOIN quest_template qt ON qt.CompleteScript = dqe.id
        JOIN creature_involvedrelation cir ON cir.quest = qt.entry
        WHERE dqe.command = 0 AND bt.Id > 0
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        
        if is_clean_text(txt):
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "sex": npc["sex"] if npc else None,
                "dialog_type": DIALOG_TYPES["QUEST_COMPLETE"],
                "quest_id": row["quest_id"],
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    return rows, seen


def extract_dbscripts_gossip(cursor, npc_meta):
    """
    Extract gossip script dialogue (when player clicks gossip option).
    
    SOURCE: dbscripts_on_gossip, gossip_menu_option, gossip_menu, creature_template
    CONTEXT: Triggered when player selects a gossip menu option
    
    ID RELATIONSHIP:
    gossip_menu_option.action_script_id = dbscripts_on_gossip.id
    
    PARTICIPANTS (depends on gossip holder type):
    
    When gossip holder is CREATURE:
    - Source: creature (gossip holder)
    - Target: player
    - Buddy: optional creature
    
    When gossip holder is GAMEOBJECT:
    - Source: player
    - Target: gameobject (gossip holder)
    - Buddy: optional creature
    
    SPEAKER RESOLUTION:
    For creature gossip (most common):
    - 0 (0x00): creature → player      [DEFAULT: NPC responds]
    - 1 (0x01): creature → buddy       [NPC talks to buddy]
    - 2 (0x02): player → creature      [Player speaks (rare)]
    - 3 (0x03): buddy → creature       [Buddy responds]
    
    ATTRIBUTION CONFIDENCE: HIGH
    - Direct FK chain from gossip_menu_option
    - Creature ownership is canonical via GossipMenuId
    
    FLOW:
    creature_template.GossipMenuId → gossip_menu.entry
    → gossip_menu_option.menu_id → gossip_menu_option.action_script_id
    → dbscripts_on_gossip.id → dbscripts_on_gossip.dataint → broadcast_text.Id
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT DISTINCT
            ct.Entry AS npc_id,
            ct.Name AS npc_name,
            gmo.menu_id,
            gmo.id AS option_id,
            gmo.option_text,
            gmo.action_script_id,
            dsg.data_flags,
            dsg.buddy_entry,
            dsg.dataint AS bt_id,
            bt.Text,
            bt.Text1,
            dsg.comments
        FROM gossip_menu_option gmo
        JOIN dbscripts_on_gossip dsg ON dsg.id = gmo.action_script_id
        JOIN broadcast_text bt ON bt.Id = dsg.dataint
        LEFT JOIN creature_template ct ON ct.GossipMenuId = gmo.menu_id
        WHERE dsg.command = 0
          AND bt.Id > 0
          AND gmo.action_script_id > 0
    """)

    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if not is_clean_text(txt):
            continue

        # Determine speaker based on context
        # For creature gossip (most common): NPC responds to player selection
        npc_id = row["npc_id"]
        buddy_entry = row["buddy_entry"]
        
        # Real-world patterns: Usually the NPC speaks, or their buddy
        if buddy_entry:
            # Buddy specified: buddy speaks
            speaker_entry = buddy_entry
        elif npc_id:
            # No buddy: NPC speaks
            speaker_entry = npc_id
        else:
            # Gameobject gossip or unknown
            speaker_entry = None
        
        npc = npc_meta.get(speaker_entry) if speaker_entry else None

        rows.append({
            "npc_name": npc["npc_name"] if npc else "Unknown",
            "sex": npc["sex"] if npc else None,
            "dialog_type": DIALOG_TYPES["GOSSIP"],
            "quest_id": None,
            "text": txt.strip(),
        })

        seen.add(row["bt_id"])

    return rows, seen


def extract_dbscripts_misc(cursor, npc_meta):
    """
    Extract miscellaneous dbscript dialogue from tables without direct creature links.
    
    SOURCES: dbscripts_on_event, dbscripts_on_go_template_use, dbscripts_on_go_use
    
    DETAILS:
    
    dbscripts_on_event:
    - ID = event ID (from spell SEND_EVENT or gameobject event)
    - Source/Target varies by event trigger
    - Cannot reliably determine speaker without runtime context
    
    dbscripts_on_go_template_use:
    - ID = gameobject_template.entry (button/lever/chest)
    - Source = object user (unit)
    - Target = gameobject
    - Buddy may be creature
    
    dbscripts_on_go_use:
    - ID = gameobject.guid (specific GO instance)
    - Source = object user (unit)
    - Target = gameobject
    - Buddy may be creature
    
    ATTRIBUTION CONFIDENCE: LOW-MEDIUM
    - Event scripts: UNKNOWN (runtime-dependent)
    - GO scripts: Buddy may be speaker, otherwise unknown
    
    NOTE: dbscripts_on_gossip has been moved to its own function with proper attribution
    """
    rows = []
    seen = set()

    # Event scripts - truly unknown speaker
    cursor.execute("""
        SELECT DISTINCT
            d.id AS event_id,
            d.buddy_entry,
            d.data_flags,
            d.dataint AS bt_id,
            bt.Text,
            bt.Text1
        FROM dbscripts_on_event d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        WHERE d.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if is_clean_text(txt):
            # Try buddy if present
            speaker_entry = row["buddy_entry"] if row["buddy_entry"] else None
            npc = npc_meta.get(speaker_entry) if speaker_entry else None
            
            rows.append({
                "npc_name": npc["npc_name"] if npc else "Unknown",
                "sex": npc["sex"] if npc else None,
                "dialog_type": DIALOG_TYPES["GOSSIP"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    # GO template use scripts
    cursor.execute("""
        SELECT DISTINCT
            d.id AS go_entry,
            got.name AS go_name,
            d.buddy_entry,
            d.data_flags,
            d.dataint AS bt_id,
            bt.Text,
            bt.Text1
        FROM dbscripts_on_go_template_use d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        LEFT JOIN gameobject_template got ON got.entry = d.id
        WHERE d.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if is_clean_text(txt):
            # Buddy may speak, otherwise unknown
            speaker_entry = row["buddy_entry"] if row["buddy_entry"] else None
            npc = npc_meta.get(speaker_entry) if speaker_entry else None
            
            rows.append({
                "npc_name": npc["npc_name"] if npc else row["go_name"] or "Unknown",
                "sex": npc["sex"] if npc else None,
                "dialog_type": DIALOG_TYPES["GOSSIP"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    # GO use scripts (by guid)
    cursor.execute("""
        SELECT DISTINCT
            d.id AS go_guid,
            go.id AS go_entry,
            got.name AS go_name,
            d.buddy_entry,
            d.data_flags,
            d.dataint AS bt_id,
            bt.Text,
            bt.Text1
        FROM dbscripts_on_go_use d
        JOIN broadcast_text bt ON bt.Id = d.dataint
        LEFT JOIN gameobject go ON go.guid = d.id
        LEFT JOIN gameobject_template got ON got.entry = go.id
        WHERE d.command = 0 AND bt.Id > 0
    """)
    
    for row in cursor.fetchall():
        txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
        if is_clean_text(txt):
            # Buddy may speak, otherwise unknown
            speaker_entry = row["buddy_entry"] if row["buddy_entry"] else None
            npc = npc_meta.get(speaker_entry) if speaker_entry else None
            
            rows.append({
                "npc_name": npc["npc_name"] if npc else row["go_name"] or "Unknown",
                "sex": npc["sex"] if npc else None,
                "dialog_type": DIALOG_TYPES["GOSSIP"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    return rows, seen


def extract_ai_scripts(cursor, npc_meta):
    """
    Extract creature AI combat script dialogue.
    
    SOURCE: creature_ai_scripts
    ATTRIBUTION: CANONICAL - creature_id = creature_template.entry
    
    FLOW:
    creature_ai_scripts.creature_id = creature_template.entry
    -> action1/2/3_type = 1 (TALK action)
    -> action1/2/3_param1 = broadcast_text.Id
    """
    rows = []
    seen = set()

    cursor.execute("""
        SELECT DISTINCT
            cas.creature_id AS npc_id,
            bt.Id AS bt_id,
            bt.Text,
            bt.Text1
        FROM creature_ai_scripts cas
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
                "dialog_type": DIALOG_TYPES["GOSSIP"],  # Combat text
                "quest_id": None,
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    return rows, seen


def extract_gossip_text(cursor, npc_meta):
    """
    Extract NPC gossip menu text.
    
    SOURCE: creature_template, gossip_menu, npc_text_broadcast_text, broadcast_text
    ATTRIBUTION: CANONICAL - follows foreign key chain
    
    FLOW:
    creature_template.GossipMenuId = gossip_menu.entry
    -> gossip_menu.text_id = npc_text_broadcast_text.Id
    -> npc_text_broadcast_text.BroadcastTextId0..7 = broadcast_text.Id
    """
    rows = []
    seen = set()

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
                "dialog_type": DIALOG_TYPES["GOSSIP"],
                "quest_id": None,
                "text": txt.strip(),
            })
            seen.add(row["bt_id"])

    return rows, seen


def extract_gameobject_text(cursor):
    """
    Extract readable gameobject text (plaques, books, etc).
    
    SOURCE: gameobject_template, page_text
    ATTRIBUTION: N/A - gameobjects, not creatures
    
    FLOW:
    gameobject_template.type = 9 (GAMEOBJECT_TYPE_TEXT)
    -> gameobject_template.data0 = page_text.entry
    -> page_text.next_page (chain multiple pages)
    """
    rows = []

    cursor.execute("""
        SELECT
            got.entry AS go_id,
            got.name AS go_name,
            got.data0 AS page_id
        FROM gameobject_template got
        WHERE got.type = 9
          AND got.data0 IS NOT NULL
    """)

    gameobjects = cursor.fetchall()

    # Load all page_text for chaining
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
                    "dialog_type": DIALOG_TYPES["ITEM_TEXT"],
                    "quest_id": None,
                    "text": page["text"].strip(),
                })
            page_id = page["next_page"] if page["next_page"] != 0 else None

    return rows, set()  # No broadcast_text tracking for gameobject text


def extract_item_text(cursor):
    """
    Extract item-contained text (letters, books).
    
    SOURCE: item_template, page_text
    ATTRIBUTION: N/A - items, not creatures
    
    FLOW:
    item_template.PageText = page_text.entry
    -> page_text.next_page (chain multiple pages)
    -> item_template.startquest (optional quest link)
    """
    rows = []

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

    # Load all page_text for chaining
    cursor.execute("SELECT entry, text, next_page FROM page_text")
    page_dict = {r["entry"]: r for r in cursor.fetchall()}

    for item in items:
        page_id = item["page_id"]
        while page_id and page_id in page_dict:
            page = page_dict[page_id]
            if is_clean_text(page["text"]):
                rows.append({
                    "npc_name": item["item_name"],
                    "sex": None,
                    "dialog_type": DIALOG_TYPES["ITEM_TEXT"],
                    "quest_id": item["quest_id"],
                    "text": page["text"].strip(),
                })
            page_id = page["next_page"] if page["next_page"] != 0 else None

    return rows, set()


def extract_quest_greetings(cursor, npc_meta):
    """
    Extract NPC quest/trainer greetings.
    
    SOURCES: questgiver_greeting, trainer_greeting
    ATTRIBUTION: CANONICAL - Entry = creature_template.entry
    
    FLOW:
    questgiver_greeting.Entry = creature_template.entry
    trainer_greeting.Entry = creature_template.entry
    """
    rows = []

    # Quest greetings
    cursor.execute("""
        SELECT
            Entry AS npc_id,
            Text AS text
        FROM questgiver_greeting
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if npc and is_clean_text(row["text"]):
            rows.append({
                "npc_name": npc["npc_name"],
                "sex": npc["sex"],
                "dialog_type": DIALOG_TYPES["GOSSIP"],
                "quest_id": None,
                "text": row["text"].strip(),
            })

    # Trainer greetings
    cursor.execute("""
        SELECT
            Entry AS npc_id,
            Text AS text
        FROM trainer_greeting
    """)

    for row in cursor.fetchall():
        npc = npc_meta.get(row["npc_id"])
        if npc and is_clean_text(row["text"]):
            rows.append({
                "npc_name": npc["npc_name"],
                "sex": npc["sex"],
                "dialog_type": DIALOG_TYPES["GOSSIP"],
                "quest_id": None,
                "text": row["text"].strip(),
            })

    return rows, set()


def extract_quest_texts(cursor, npc_meta):
    """
    Extract quest template text fields.
    
    SOURCE: quest_template, creature_questrelation, creature_involvedrelation
    ATTRIBUTION: CANONICAL - quest giver/ender known
    
    FLOW:
    quest_template.entry
    -> creature_questrelation.quest (quest giver)
    -> creature_involvedrelation.quest (quest ender)
    
    Fields:
    - Details -> quest_accept (from quest giver)
    - RequestItemsText -> quest_progress (from quest giver)
    - OfferRewardText -> quest_complete (from quest ender)
    - Objectives -> quest_objective (from quest giver)
    """
    rows = []

    cursor.execute("""
        SELECT 
            qt.entry AS quest_id,
            qt.Details,
            qt.RequestItemsText,
            qt.OfferRewardText,
            qt.Objectives,
            cqr.id AS accept_npc,
            cir.id AS complete_npc
        FROM quest_template qt
        LEFT JOIN creature_questrelation cqr ON qt.entry = cqr.quest
        LEFT JOIN creature_involvedrelation cir ON qt.entry = cir.quest
    """)

    for row in cursor.fetchall():
        fields = [
            (row["accept_npc"], DIALOG_TYPES["QUEST_ACCEPT"], "Details"),
            (row["accept_npc"], DIALOG_TYPES["QUEST_PROGRESS"], "RequestItemsText"),
            (row["complete_npc"], DIALOG_TYPES["QUEST_COMPLETE"], "OfferRewardText"),
            (row["accept_npc"], DIALOG_TYPES["QUEST_OBJECTIVE"], "Objectives"),
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

    return rows, set()


def extract_orphan_broadcast_text(cursor, seen_broadcast_ids):
    """
    Extract broadcast_text not referenced by any other source.
    
    SOURCE: broadcast_text
    ATTRIBUTION: UNKNOWN - no source reference
    
    NOTE: These may be unused, or referenced by systems we don't track yet.
    """
    rows = []

    cursor.execute("SELECT Id, Text, Text1 FROM broadcast_text WHERE Id > 0")
    
    for row in cursor.fetchall():
        if row["Id"] not in seen_broadcast_ids:
            txt = row["Text"] if is_clean_text(row["Text"]) else row["Text1"]
            if is_clean_text(txt):
                rows.append({
                    "npc_name": "Unknown",
                    "sex": None,
                    "dialog_type": DIALOG_TYPES["GOSSIP"],  # Unknown context
                    "quest_id": None,
                    "text": txt.strip(),
                })

    return rows


# =========================
# MAIN EXTRACTION
# =========================

def extract_all_dialog():
    """
    Main orchestrator - calls all extraction functions in order.
    """
    db = get_connection()
    cursor = db.cursor(dictionary=True)

    rows = []
    seen_broadcast_ids = set()

    # Load NPC metadata once
    npc_meta = load_npc_metadata(cursor)

    # Run all extractors
    extractors = [
        extract_scriptdev2_texts,
        extract_dbscripts_creature_death,
        extract_dbscripts_creature_movement,
        extract_dbscripts_relay,
        extract_dbscripts_quest_start,
        extract_dbscripts_quest_end,
        extract_dbscripts_gossip,
        extract_dbscripts_misc,
        extract_ai_scripts,
        extract_gossip_text,
        extract_gameobject_text,
        extract_item_text,
        extract_quest_greetings,
        extract_quest_texts,
    ]

    for extractor in extractors:
        new_rows, new_seen = extractor(cursor, npc_meta)
        rows.extend(new_rows)
        seen_broadcast_ids |= new_seen

    # Final orphan sweep
    orphan_rows = extract_orphan_broadcast_text(cursor, seen_broadcast_ids)
    rows.extend(orphan_rows)

    cursor.close()
    return rows, db


# =========================
# MAIN
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
    
    db.close()
    print(f"\n✓ Extraction complete!")