#!/usr/bin/env python3

import json
import mysql.connector
import pandas as pd
from collections import defaultdict
import re

DB_CONFIG = {
    "host": "localhost",
    "user": "mangos",
    "password": "mangos",
    "database": "classicmangos",
    "charset": "utf8mb4",
    "use_unicode": True,
}

NPC_DIALOG_CSV = "../data/all_npc_dialog.csv"

# Gender mappings from creature_model_info
GENDER_MAP = {
    0: "male",
    1: "female",
    2: "none",
}

# Expanded seed data with name patterns
KNOWN_NPCS = {
    # === ALLIANCE ===
    # Humans
    "King Varian Wrynn": "human",
    "Marshal Dughan": "human",
    "Baros Alexston": "human",
    "Bartlett the Brave": "human",
    "Remy Two-Times": "human",
    "Gryan Stoutmantle": "human",
    "Marshal McBride": "human",
    "Deputy Willem": "human",
    "Brother Paxton": "human",
    "Milly Osworth": "human",
    "Tommy Joe Stonefield": "human",
    
    # Dwarves
    "King Magni Bronzebeard": "dwarf",
    "Mountaineer Thalos": "dwarf",
    "Mountaineer Barleybrew": "dwarf",
    "Balin Barleybrew": "dwarf",
    "Golnir Bouldertoe": "dwarf",
    "Grelin Whitebeard": "dwarf",
    "Steelus Grimfoe": "dwarf",
    "Senator Barin Redstone": "dwarf",
    
    # Gnomes
    "High Tinker Mekkatorque": "gnome",
    "Springspindle Fizzlegear": "gnome",
    "Melder Thistledown": "gnome",
    "Ozzie Togglevolt": "gnome",
    "Technician Braggle": "gnome",
    
    # Night Elves
    "Tyrande Whisperwind": "night_elf",
    "Sentinel Elissa Starbreeze": "night_elf",
    "Priestess Alathea": "night_elf",
    "Dentaria Silverglade": "night_elf",
    "Conservator Ilthalaine": "night_elf",
    "Tarindrella": "night_elf",
    
    # === HORDE ===
    # Orcs
    "Thrall": "orc",
    "Orgnil Soulscar": "orc",
    "Gar'Thok": "orc",
    "Kaltunk": "orc",
    "Gornek": "orc",
    "Zureetha Fargaze": "orc",
    
    # Tauren
    "Cairne Bloodhoof": "tauren",
    "Grull Hawkwind": "tauren",
    "Harb Clawhoof": "tauren",
    "Chief Hawkwind": "tauren",
    
    # Trolls
    "Vol'jin": "troll",
    "Master Gadrin": "troll",
    "Master Vornal": "troll",
    "Kzan Thornslash": "troll",
    "Zen'Taji": "troll",
    
    # Undead
    "Lady Sylvanas Windrunner": "undead",
    "Executor Arren": "undead",
    "Shadow Priest Sarvis": "undead",
    "Deathguard Simmer": "undead",
    "Undertaker Mordo": "undead",
    
    # === OTHER RACES ===
    # Goblins
    "Gazlowe": "goblin",
    "Scooty": "goblin",
    "Wizbang Cranknoggin": "goblin",
    
    # Blood Elves
    "Lor'themar Theron": "blood_elf",
    
    # Dragons
    "Ysera": "dragon",
    "Alexstrasza": "dragon",
    "Nozdormu": "dragon",
    
    # Demons
    "Mannoroc Lasher": "demon",
    
    # Centaurs
    "Arnak Grimtotem": "centaur",
    
    # Mechanical
    "Harvest Reaper": "mechanical",
    
    # Animals
    "Chicken": "animal",
    "Rabbit": "animal",
    "Deer": "animal",
    "Cat": "animal",
    "Rat": "animal",
    "Snake": "animal",
    "Spider": "animal",
    "Wolf": "animal",
    "Bear": "animal",
    "Boar": "animal",
    
    # Objects
    "Bonfire": "object",
    "Campfire": "object",

      "World Alchemy Trainer                             ": "spirit",        # spectral trainer NPC
  "Baron Longshore                                   ": "human",
  "Billy Maclure                                     ": "human",
  "Hastat the Ancient                                ": "night_elf",
  "Homing Robot OOX-09/HL                            ": "mechanical",
  "Ambassador Ardalan                                ": "human",
  "Arcanist Nozzlespring                             ": "gnome",
  "Argent Messenger                                  ": "human",
  "Bragok                                            ": "orc",
  "Captain Kromcrush                                 ": "ogre",
  "Cho'Rush the Observer                             ": "ogre",
  "Corporal Carnes                                   ": "human",
  "Corporal Noreg Stormpike                          ": "dwarf",
  "Cracked Necrotic Crystal                          ": "object",
  "Devrak                                            ": "orc",
  "Do'gol                                            ": "orc",
  "Durik                                             ": "dwarf",
  "Flik                                              ": "gnome",
  "Gelkak Gyromast                                   ": "goblin",
  "Gordok Bushwacker                                 ": "ogre",
  "Gorn One Eye                                      ": "orc",
  "Grazle                                            ": "goblin",
  "Human Orphan                                      ": "human",
  "Huntsman Markhor                                  ": "orc",
  "Illiyana                                          ": "night_elf",
  "Innkeeper Faralia                                 ": "night_elf",
  "Johnny McWeaksauce                                ": "human",
  "Keeper Albagorm                                   ": "ancient",       # Keeper / tree-being
  "Kil'Hiwana                                        ": "troll",
  "Lord Tirion Fordring                              ": "human",
  "Lore Keeper of Norgannon                          ": "titan_construct",
  "Noggle Ficklespragg                               ": "gnome",
  "Pilot Xiggs Fuselighter                           ": "gnome",
  "Precious                                          ": "beast",         # dog (Stitches questline)
  "Servant of the Hand                               ": "undead",
  "Super-Seller 680                                  ": "mechanical",
  "Wonderform Operator                               ": "mechanical",

  "\"Auntie\" Bernice Stonefield                     ": "human",
  "\"Pretty Boy\" Duncan                             ": "human",
  "\"Sea Wolf\" MacKinley                            ": "human",
  "\"Shaky\" Phillipe                                ": "human",
  "\"Stinky\" Ignatz                                 ": "human",
  "\"Swamp Eye\" Jarl                                ": "human",

  "A-Me 01                                           ": "mechanical",
  "Aayndia Floralwind                                ": "night_elf",
  "Abercrombie                                       ": "human",
  "Abigail Sawyer                                    ": "human",
  "Aboda                                             ": "tauren",
  "Acolyte Dellis                                    ": "undead",
  "Acolyte Magaz                                     ": "undead",

}

# Name patterns to auto-detect races
RACE_PATTERNS = {
    "dwarf": [
        r"^Mountaineer\s",
        r"^Ironforge\s",
        r"\bBronzebeard\b",
        r"\bIronforge\b",
        r"\bStoneforge\b",
        r"\bHammerfist\b",
    ],
    "gnome": [
        r"^Technician\s",
        r"^Engineer\s",
        r"\bGearspring\b",
        r"\bSpringspindle\b",
        r"\bMekkatorque\b",
        r"\bToggle\b",
        r"\bCog\b",
    ],
    "night_elf": [
        r"^Sentinel\s",
        r"^Huntress\s",
        r"^Priestess\s",
        r"\bMoonwell\b",
        r"\bStarbreeze\b",
        r"\bMoonshadow\b",
        r"\bSilverwing\b",
    ],
    "orc": [
        r"^Grunt\s",
        r"^Kor'kron\s",
        r"\bWarsong\b",
        r"\bFrostwolf\b",
        r"\bBlackrock\b",
    ],
    "troll": [
        r"^Witch Doctor\s",
        r"^Shadow Hunter\s",
        r"\bDarkspear\b",
        r"\bRevantusk\b",
        r"^Zen'",
        r"^Vol'",
    ],
    "tauren": [
        r"^Brave\s",
        r"\bBloodhoof\b",
        r"\bThunderhorn\b",
        r"\bWindtotem\b",
    ],
    "undead": [
        r"^Deathguard\s",
        r"^Dark Ranger\s",
        r"^Executor\s",
        r"\bForsaken\b",
    ],
    "human": [
        r"^Marshal\s",
        r"^Stormwind\s",
        r"^Guard\s",
        r"\bStormwind\b",
    ],
    "goblin": [
        r"\bGoblin\b",
        r"^Scooty$",
        r"^Gazlowe$",
        r"\bBilgewater\b",
    ],
    "animal": [
        r"^(Chicken|Rabbit|Deer|Cat|Rat|Snake|Spider|Wolf|Bear|Boar|Cow|Sheep|Pig)$",
        r"^(Young|Elder|Rabid|Diseased|Crazed)\s+(Wolf|Bear|Boar|Spider)",
        r"^(Black|Brown|Gray|White)\s+(Wolf|Bear|Spider|Ram)",
    ],
    "mechanical": [
        r"^Harvest (Reaper|Golem|Watcher)",
        r"^(Defias\s)?Gunpowder",
        r"Bot$",
        r"^[0-9]:[A-Z]+$",  # 7:XT pattern
    ],
    "demon": [
        r"^(Felhound|Imp|Succubus|Voidwalker|Felguard|Infernal)",
        r"Demon$",
        r"^Shadowfiend",
    ],
    "elemental": [
        r"^(Fire|Water|Air|Earth)\s+Elemental",
        r"Elemental$",
    ],
    "spirit": [
        r"Spirit$",
        r"^Ghost\s",
        r"^Phantom\s",
        r"Specter$",
    ],
    "wisp": [
        r"^Wisp$",
    ],
    "construct": [
        r"^(Flesh|Bone|Patchwerk)",
        r"Golem$",
        r"Construct$",
    ],
    "object": [
        r"^(Bonfire|Campfire|Brazier|Banner|Flag|Drum)$",
        r"^<TXT>",
        r"Doodad$",
        r"^(Quest\s)?Credit$",
    ],
}

def apply_name_patterns(npc_name):
    """Try to detect race from NPC name using patterns"""
    for race, patterns in RACE_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, npc_name, re.IGNORECASE):
                return race
    return None

def get_dialog_npcs():
    """Get unique NPCs from dialog CSV"""
    df = pd.read_csv(NPC_DIALOG_CSV)
    
    # Get unique NPC names (skip items and gameobjects)
    dialog_npcs = df[~df['npc_name'].str.startswith('item_', na=False)]
    dialog_npcs = dialog_npcs[~dialog_npcs['npc_name'].str.startswith('go_', na=False)]
    
    unique_npcs = dialog_npcs['npc_name'].unique()
    print(f"Found {len(unique_npcs)} unique NPCs with dialog")
    
    return set(unique_npcs)

def extract_dialog_npcs_from_db(dialog_npc_names):
    """Get NPC data only for NPCs that have dialog"""
    db = mysql.connector.connect(**DB_CONFIG)
    cursor = db.cursor(dictionary=True)

    # Create placeholders for IN clause
    placeholders = ','.join(['%s'] * len(dialog_npc_names))
    
    query = f"""
        SELECT DISTINCT
            ct.Entry AS npc_id,
            ct.Name AS name,
            ct.DisplayId1 AS model_id,
            cmi.gender AS gender
        FROM creature_template ct
        LEFT JOIN creature_model_info cmi
            ON cmi.modelid = ct.DisplayId1
        WHERE ct.Name IN ({placeholders})
            AND ct.DisplayId1 IS NOT NULL
        ORDER BY ct.Name
    """
    
    cursor.execute(query, list(dialog_npc_names))
    npcs = cursor.fetchall()
    
    cursor.close()
    db.close()
    
    print(f"Retrieved {len(npcs)} NPC records from database")
    return npcs

def propagate_race_by_model(npcs):
    """
    Use seed NPCs + name patterns to assign races to model IDs, then propagate
    """
    # Step 1: Build model_id -> race/gender mapping
    model_metadata = {}  # model_id -> {race, gender, source_npc}
    
    npc_lookup = {npc["name"]: npc for npc in npcs}
    
    # Add known NPCs
    for npc_name, race in KNOWN_NPCS.items():
        if npc_name in npc_lookup:
            npc = npc_lookup[npc_name]
            model_id = npc["model_id"]
            gender = npc["gender"]
            
            if model_id not in model_metadata:
                model_metadata[model_id] = {
                    "race": race,
                    "gender": gender,
                    "source_npc": npc_name,
                    "source_type": "known"
                }
    
    # Add NPCs detected by name patterns
    pattern_detected = 0
    for npc in npcs:
        model_id = npc["model_id"]
        if model_id not in model_metadata:
            detected_race = apply_name_patterns(npc["name"])
            if detected_race:
                model_metadata[model_id] = {
                    "race": detected_race,
                    "gender": npc["gender"],
                    "source_npc": npc["name"],
                    "source_type": "pattern"
                }
                pattern_detected += 1
    
    print(f"\nSeeded {len(model_metadata)} model IDs:")
    print(f"  - From known NPCs: {len([m for m in model_metadata.values() if m['source_type'] == 'known'])}")
    print(f"  - From name patterns: {pattern_detected}")
    
    # Step 2: Apply model metadata to all NPCs
    npc_metadata = {}
    resolved_count = 0
    unknown_count = 0
    unknown_models = set()
    
    for npc in npcs:
        name = npc["name"]
        model_id = npc["model_id"]
        gender = npc["gender"]
        
        if model_id in model_metadata:
            meta = model_metadata[model_id]
            race = meta["race"]
            sex = GENDER_MAP.get(gender, "none")
            resolved_count += 1
        else:
            race = "UNKNOWN"
            sex = GENDER_MAP.get(gender, "none")
            unknown_count += 1
            unknown_models.add(model_id)
        
        npc_metadata[name] = {
            "npc_id": npc["npc_id"],
            "race": race,
            "sex": sex,
            "model_id": model_id,
        }
    
    print(f"\nResults:")
    print(f"  Resolved: {resolved_count} NPCs ({resolved_count/len(npcs)*100:.1f}%)")
    print(f"  Unknown: {unknown_count} NPCs ({unknown_count/len(npcs)*100:.1f}%)")
    print(f"  Unique unknown models: {len(unknown_models)}")
    
    # Step 3: Show top unknown models by count (models with most NPCs first)
    model_to_npcs = defaultdict(list)
    for npc in npcs:
        if npc["model_id"] in unknown_models:
            model_to_npcs[npc["model_id"]].append(npc)
    
    # Sort by count descending
    sorted_models = sorted(model_to_npcs.items(), key=lambda x: len(x[1]), reverse=True)
    
    print(f"\nTop unknown models by NPC count (add these to KNOWN_NPCS):")
    print(f"Format: <example_npc> (model_id=<id>, gender=<gender>, total_npcs=<count>)\n")
    
    for model_id, npc_list in sorted_models[:50]:  # Top 50
        example_npc = npc_list[0]  # Just show one example
        print(f'  "{example_npc["name"]:<50}": "RACE_HERE",  # (model_id={model_id:<5}, gender={example_npc["gender"]}, total_npcs={len(npc_list)})')
    
    return npc_metadata, unknown_models

def export_unknown_models(npcs, unknown_models):
    """Export a list of NPCs grouped by unknown model_id for easy categorization"""
    model_to_npcs = defaultdict(list)
    
    for npc in npcs:
        if npc["model_id"] in unknown_models:
            model_to_npcs[npc["model_id"]].append(npc["name"])
    
    # Export to JSON for manual review
    output = {}
    for model_id, npc_names in sorted(model_to_npcs.items(), key=lambda x: len(x[1]), reverse=True):
        output[str(model_id)] = {
            "example_npcs": npc_names[:10],  # First 10 examples
            "total_count": len(npc_names),
            "suggested_race": "UNKNOWN",  # Fill this in manually
        }
    
    with open("../data/unknown_models.json", "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"\nExported {len(output)} unknown models to ../data/unknown_models.json")

if __name__ == "__main__":
    print("=" * 70)
    print("NPC METADATA EXTRACTOR - Dialog NPCs Only")
    print("=" * 70)
    
    # Step 1: Get NPCs that have dialog
    dialog_npc_names = get_dialog_npcs()
    
    # Step 2: Get their data from database
    print("\nQuerying database for dialog NPCs...")
    npcs = extract_dialog_npcs_from_db(dialog_npc_names)
    
    # Step 3: Propagate race/sex
    print("\nPropagating race data from known NPCs and patterns...")
    npc_metadata, unknown_models = propagate_race_by_model(npcs)
    
    # Step 4: Save metadata
    output_file = "../data/npc_metadata.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(npc_metadata, f, indent=2, ensure_ascii=False)
    
    print(f"\nSaved NPC metadata to {output_file}")
    
    # Step 5: Export unknown models for manual categorization
    if unknown_models:
        export_unknown_models(npcs, unknown_models)
    
    # Print statistics
    races = defaultdict(int)
    sexes = defaultdict(int)
    for npc in npc_metadata.values():
        races[npc["race"]] += 1
        sexes[npc["sex"]] += 1
    
    print("\n" + "=" * 70)
    print("STATISTICS")
    print("=" * 70)
    
    print("\nRace distribution:")
    for race, count in sorted(races.items(), key=lambda x: x[1], reverse=True):
        print(f"  {race:<15}: {count:>4} ({count/len(npc_metadata)*100:.1f}%)")
    
    print("\nSex distribution:")
    for sex, count in sorted(sexes.items(), key=lambda x: x[1], reverse=True):
        print(f"  {sex:<15}: {count:>4} ({count/len(npc_metadata)*100:.1f}%)")