"""Default paths are relative to this checkout, never the shell's directory."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = {
    "npc_dialog_csv": str(ROOT / "data/all_npc_dialog.csv"),
    "npc_metadata_json": str(ROOT / "data/npc_metadata.json"),
    "race_file": str(ROOT / "data/npc_race.yaml"),
    "sex_file": str(ROOT / "data/npc_sex.yaml"),
    "zone_file": str(ROOT / "data/npc_zone.yaml"),
    "missing_race_file": str(ROOT / "data/missing_race.yaml"),
    "missing_narrators_csv": str(ROOT / "data/missing_narrators.csv"),
    "output_lua": str(ROOT / "db/npc_database.lua"),
    "sounds_dir": str(ROOT / "sounds"),
    "samples_dir": str(ROOT / "samples"),
    "betterquest_lua": str(ROOT.parents[2] / "WTF/Account/ADMIN/SavedVariables/BetterQuest.lua"),
    "wtf_path": str(ROOT.parents[2] / "WTF"),
}
