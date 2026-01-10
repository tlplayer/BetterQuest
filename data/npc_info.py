from collections import defaultdict
import yaml

# Example file paths (replace with your real files)
RACE_FILE = "npc_race.yaml"
SEX_FILE = "npc_sex.yaml"
ZONE_FILE = "npc_zone.yaml"

def read_mapping(file_path):
    """
    Reads a YAML file of the format:
      key:
      - value1
      - value2
    Returns a dict mapping key -> list of values
    """
    with open(file_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data

if __name__ == "__main__":
    # Read each file
    npc_race = read_mapping(RACE_FILE)
    npc_sex = read_mapping(SEX_FILE)
    npc_zone = read_mapping(ZONE_FILE)

    # Print the dictionaries
    print("npc_race =")
    print(npc_race)
    print("\nnpc_sex =")
    print(npc_sex)
    print("\nnpc_zone =")
    print(npc_zone)
