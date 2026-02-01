import yaml

def merge_missing(base, fallback):
    """
    Merge fallback into base, but only where base is missing data.
    """
    if isinstance(base, dict) and isinstance(fallback, dict):
        for key, value in fallback.items():
            if key not in base:
                base[key] = value
            else:
                base[key] = merge_missing(base[key], value)
        return base

    elif isinstance(base, list) and isinstance(fallback, list):
        for item in fallback:
            if item not in base:
                base.append(item)
        return base

    else:
        # base exists, do not overwrite
        return base


with open("npc_race.yaml", "r") as f:
    base_data = yaml.safe_load(f) or {}

with open("npc_race_copy.yaml", "r") as f:
    fallback_data = yaml.safe_load(f) or {}

merged = merge_missing(base_data, fallback_data)

with open("npc_race.yaml", "w") as f:
    yaml.safe_dump(merged, f, sort_keys=False)
