import pandas as pd
import yaml
from tts_cli.sql_queries import make_connection
from tts_cli.consts import RACE_DICT, GENDER_DICT

def export_npc_race_sex_from_dialog():
    """
    Export race/gender YAML files only for NPCs in all_npc_dialog.csv
    Filters by NPC name since that's what matters for voice assignment
    """
    
    # Load the dialog CSV to get list of NPC names we care about
    print("Loading all_npc_dialog.csv...")
    dialog_df = pd.read_csv('data/all_npc_dialog.csv')
    
    # Get unique NPC names from dialog
    dialog_npc_names = set(dialog_df['npc_name'].unique())
    print(f"Found {len(dialog_npc_names)} unique NPC names in dialog CSV")
    
    # Get race/gender data from database
    print("Querying database for race/gender data...")
    db = make_connection()
    
    # Get all NPCs with their race/gender info
    query = '''
    SELECT DISTINCT 
        ct.entry AS npc_id,
        ct.name AS npc_name,
        cdix.DisplayRaceID,
        cdix.DisplaySexID
    FROM creature_template ct
    LEFT JOIN db_CreatureDisplayInfo cdi ON cdi.ID = ct.display_id1
    LEFT JOIN db_CreatureDisplayInfoExtra cdix ON cdix.ID = cdi.ExtendedDisplayInfoID
    '''
    
    df = pd.read_sql(query, db)
    db.close()
    
    print(f"Got {len(df)} total NPCs from database")
    
    # Filter to only NPCs that appear in the dialog CSV (by name)
    df = df[df['npc_name'].isin(dialog_npc_names)]
    print(f"Filtered to {len(df)} NPCs that appear in dialog CSV")
    
    # Map IDs to canonical names
    df['race'] = df['DisplayRaceID'].map(RACE_DICT)
    df['gender'] = df['DisplaySexID'].map(GENDER_DICT)
    
    # Stats
    has_race = df[df['race'].notna()]
    missing_race = df[df['race'].isna()]
    has_gender = df[df['gender'].notna()]
    missing_gender = df[df['gender'].isna()]
    
    print(f"\nRace data:")
    print(f"  - Has race: {len(has_race)} NPCs")
    print(f"  - Missing race: {len(missing_race)} NPCs")
    
    print(f"\nGender data:")
    print(f"  - Has gender: {len(has_gender)} NPCs")
    print(f"  - Missing gender: {len(missing_gender)} NPCs")
    
    # Build race dictionary - SIMPLE FORMAT: race: [list of names]
    race_dict = {}
    for _, row in df.iterrows():
        race = row['race'] if pd.notna(row['race']) else 'none'
        if race not in race_dict:
            race_dict[race] = []
        # Only add if not already in list (some NPCs have multiple entries)
        if row['npc_name'] not in race_dict[race]:
            race_dict[race].append(row['npc_name'])
    
    # Build gender dictionary - SIMPLE FORMAT: gender: [list of names]
    sex_dict = {}
    for _, row in df.iterrows():
        gender = row['gender'] if pd.notna(row['gender']) else 'none'
        if gender not in sex_dict:
            sex_dict[gender] = []
        # Only add if not already in list
        if row['npc_name'] not in sex_dict[gender]:
            sex_dict[gender].append(row['npc_name'])
    
    # Sort lists alphabetically
    for race in race_dict:
        race_dict[race] = sorted(race_dict[race])
    for gender in sex_dict:
        sex_dict[gender] = sorted(sex_dict[gender])
    
    # Write YAML files in simple format
    print("\nWriting YAML files...")
    
    with open('data/npc_race.yaml', 'w', encoding='utf-8') as f:
        yaml.dump(race_dict, f, allow_unicode=True, 
                  default_flow_style=False, sort_keys=True)
    print(f"  ✓ data/npc_race.yaml")
    
    with open('data/npc_sex.yaml', 'w', encoding='utf-8') as f:
        yaml.dump(sex_dict, f, allow_unicode=True, 
                  default_flow_style=False, sort_keys=True)
    print(f"  ✓ data/npc_sex.yaml")
    
    # Write CSV of missing data for research
    if len(missing_race) > 0:
        missing_race_csv = missing_race[['npc_id', 'npc_name']].drop_duplicates()
        missing_race_csv.to_csv('data/npcs_missing_race.csv', index=False)
        print(f"  ✓ data/npcs_missing_race.csv ({len(missing_race_csv)} NPCs to research)")
    
    if len(missing_gender) > 0:
        missing_gender_csv = missing_gender[['npc_id', 'npc_name']].drop_duplicates()
        missing_gender_csv.to_csv('data/npcs_missing_gender.csv', index=False)
        print(f"  ✓ data/npcs_missing_gender.csv ({len(missing_gender_csv)} NPCs to research)")
    
    # Print summary
    print(f"\n{'='*60}")
    print("Race Distribution (for NPCs with dialog):")
    print(f"{'='*60}")
    for race in sorted(race_dict.keys()):
        count = len(race_dict[race])
        print(f"  {race:20s}: {count:4d} NPCs")
    
    print(f"\n{'='*60}")
    print("Gender Distribution (for NPCs with dialog):")
    print(f"{'='*60}")
    for gender in sorted(sex_dict.keys()):
        count = len(sex_dict[gender])
        print(f"  {gender:20s}: {count:4d} NPCs")
    
    # Show sample of missing NPCs
    if 'none' in race_dict and len(race_dict['none']) > 0:
        print(f"\n{'='*60}")
        print("Sample of NPCs with missing race (first 10):")
        print(f"{'='*60}")
        for name in race_dict['none'][:10]:
            print(f"  - {name}")
    
    print(f"\n✓ Export complete!")

if __name__ == "__main__":
    export_npc_race_sex_from_dialog()