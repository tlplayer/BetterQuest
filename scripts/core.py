"""
core.py
-------
Entry point.  Parses args, initializes the TTS model once, and orchestrates
the three pipeline steps by calling into the adapters and generator.

Usage
-----
    python core.py [options]

Steps
-----
  1. adapter_game.sync_game_data      – BetterQuest.lua → CSV
  2. generator.generate_audio         – CSV → WAV files
  3. adapter_db.sync_metadata         – CSV + WAV files → npc_database.lua
"""

import argparse
import os
import sys

import pandas as pd

# ---------------------------------------------------------------------------
# LOCAL IMPORTS
# ---------------------------------------------------------------------------
from db_adapter import (
    load_npc_metadata,
    sync_metadata,
)
from game_adapter import (
    find_betterquest_file,
    monitor_file_changes,
    sync_game_data,
)
from generator import (
    build_ref_codes,
    deduplicate_dialogs,
    generate_audio,
    merge_item_text_rows,
)
from utils import normalize_dialog_text

# ---------------------------------------------------------------------------
# DEFAULTS  (override via --config or env if desired)
# ---------------------------------------------------------------------------

CONFIG = {
    "npc_dialog_csv":    "../data/all_npc_dialog.csv",
    "npc_metadata_json": "../data/npc_metadata.json",
    "race_file":         "../data/npc_race.yaml",
    "sex_file":          "../data/npc_sex.yaml",
    "zone_file":         "../data/npc_zone.yaml",
    "missing_race_file": "../data/missing_race.yaml",
    "output_lua":        "../db/npc_database.lua",
    "sounds_dir":        "../sounds",
    "samples_dir":       "../samples",
    "betterquest_lua":   "../../../../WTF/Account/ADMIN/SavedVariables/BetterQuest.lua",
    "wtf_path":          "../../../../WTF",
}

# ---------------------------------------------------------------------------
# ARG PARSING
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Unified TTS Pipeline: Sync → Generate → Link")

    # Filters
    p.add_argument("--race",     help="Filter by NPC race")
    p.add_argument("--sex",      help="Filter by NPC sex (male/female)")
    p.add_argument("--npc",      help="Filter by specific NPC name")
    p.add_argument(
        "--zone",
        action="append",
        help="Filter by zone; repeat the option or use commas for multiple zones",
    )
    p.add_argument(
        "--expansion",
        action="append",
        help="Filter by expansion; repeat the option or use commas (for example vanilla,tbc)",
    )
    p.add_argument("--type",     dest="dialog_type", help="Filter by dialog type")
    p.add_argument("--narrator", help="Voice override (wav filename without .wav)")
    p.add_argument("--limit",    type=int, help="Max rows to process")

    # Generation control
    p.add_argument("--regenerate",     action="store_true", help="Overwrite existing audio files")
    p.add_argument("--time",           metavar="YYYY-MM-DD", help="Regenerate files older than this date")
    p.add_argument("--device",         choices=["cpu", "cuda"], default="cuda")
    p.add_argument("--tts-model",      default="k2-fsa/OmniVoice", help="OmniVoice model ID or local path")
    p.add_argument("--tts-language",   default="English", help="OmniVoice language name or code")
    p.add_argument("--tts-steps",      type=int, default=16, help="Diffusion steps; 16 is fast, 32 favors quality")
    p.add_argument("--tts-speed",      type=float, default=1.0, help="Speaking speed multiplier")
    p.add_argument(
        "--asr-model",
        default="openai/whisper-tiny.en",
        help="ASR model used only when a reference sample has no matching .txt transcript",
    )

    # Skip flags
    p.add_argument("--skip-sync",      action="store_true")
    p.add_argument("--skip-audio",     action="store_true")
    p.add_argument("--skip-metadata",  action="store_true")

    # GPU tuning
    p.add_argument("--gpu-threshold",      type=float, default=0.85)
    p.add_argument("--gpu-wait",           type=int,   default=5)
    p.add_argument("--gpu-check-interval", type=int,   default=10)
    p.add_argument("--max-retries",        type=int,   default=3)
    p.add_argument("--retry-wait",         type=int,   default=10)

    # Daemon
    p.add_argument("--daemon",          action="store_true", help="Monitor BetterQuest.lua for changes")
    p.add_argument("--daemon-interval", type=int, default=5)
    p.add_argument("--wtf-path",        default=CONFIG["wtf_path"])

    return p.parse_args()


# ---------------------------------------------------------------------------
# DATAFRAME HELPERS
# ---------------------------------------------------------------------------

def load_csv(csv_path):
    df = pd.read_csv(csv_path)
    for optional_column in ("zone", "expansion", "client_version"):
        if optional_column not in df.columns:
            df[optional_column] = ""
    return df[df["text"].notna()]


def _requested_values(raw_values):
    if not raw_values:
        return set()
    if isinstance(raw_values, str):
        raw_values = [raw_values]
    return {
        value.strip().lower().replace("_", " ")
        for raw_value in raw_values
        for value in raw_value.split(",")
        if value.strip()
    }


def filter_dataframe(df, args, npc_lookup):
    if args.npc:
        df = df[df["npc_name"] == args.npc]
    if args.dialog_type:
        df = df[df["dialog_type"] == args.dialog_type]
    if args.race:
        allowed = {n for n, m in npc_lookup.items() if m.get("race") == args.race}
        df = df[df["npc_name"].isin(allowed)]
    if args.sex:
        allowed = {n for n, m in npc_lookup.items() if m.get("sex") == args.sex}
        df = df[df["npc_name"].isin(allowed)]
    if args.zone:
        requested_zones = _requested_values(args.zone)
        row_zones = df["zone"].fillna("").astype(str)
        normalized_row_zones = row_zones.str.lower().str.replace("_", " ", regex=False).str.strip()
        fallback_zones = df["npc_name"].map(
            lambda name: str(npc_lookup.get(name, {}).get("zone") or "")
            .lower()
            .replace("_", " ")
            .strip()
        )
        df = df[
            normalized_row_zones.isin(requested_zones)
            | ((normalized_row_zones == "") & fallback_zones.isin(requested_zones))
        ]
    if getattr(args, "expansion", None):
        requested_expansions = _requested_values(args.expansion)
        row_expansions = (
            df["expansion"].fillna("").astype(str).str.lower().str.replace("_", " ", regex=False).str.strip()
        )
        df = df[row_expansions.isin(requested_expansions)]
    if args.limit:
        df = df.head(args.limit)
    return df


def prepare_for_generation(df):
    """Deduplicate rows, normalize text, merge item_text, run dialog dedup."""
    df = df.drop_duplicates(subset=["npc_name", "text"])
    df["text"] = df["text"].apply(normalize_dialog_text)
    df = merge_item_text_rows(df)
    return df


# ---------------------------------------------------------------------------
# PIPELINE
# ---------------------------------------------------------------------------

def run_pipeline(args, npc_lookup, ref_codes, tts, betterquest_path=None):
    """
    Execute one full pipeline run.

    Parameters
    ----------
    args            : Parsed argparse namespace
    npc_lookup      : Pre-loaded NPC metadata dict
    ref_codes       : Pre-loaded narrator reference codes
    tts             : Initialized TTS model (may be None if --skip-audio)
    betterquest_path: Override for BetterQuest.lua location
    """
    lua_path = betterquest_path or CONFIG["betterquest_lua"]
    csv_path = CONFIG["npc_dialog_csv"]

    # ------------------------------------------------------------------
    # Step 1: Game → CSV
    # ------------------------------------------------------------------
    new_rows = 0
    if not args.skip_sync:
        new_rows = sync_game_data(csv_path=csv_path, lua_path=lua_path)
    else:
        print("\n=== STEP 1: Syncing game data [SKIPPED] ===")

    # ------------------------------------------------------------------
    # Load full CSV (used for metadata sync regardless of filters)
    # ------------------------------------------------------------------
    df_full = load_csv(csv_path)

    # ------------------------------------------------------------------
    # Step 2: CSV → WAV
    # ------------------------------------------------------------------
    if not args.skip_audio:
        df_gen = filter_dataframe(df_full.copy(), args, npc_lookup)

        # Daemon mode: prioritize newly added rows
        if args.daemon and new_rows > 0:
            print(f"[DAEMON] Prioritizing {new_rows} new rows")
            df_new = df_gen.tail(new_rows).copy()
            df_old = df_gen.head(len(df_gen) - new_rows).copy()
            df_gen = pd.concat([df_new, df_old], ignore_index=True)

        df_gen = prepare_for_generation(df_gen)
        df_gen = deduplicate_dialogs(df_gen, npc_lookup)

        generate_audio(
            df_gen,
            tts,
            ref_codes,
            npc_lookup,
            sounds_dir=CONFIG["sounds_dir"],
            regenerate=args.regenerate,
            narrator_override=args.narrator,
            gpu_threshold=args.gpu_threshold,
            gpu_wait=args.gpu_wait,
            gpu_check_interval=args.gpu_check_interval,
            max_retries=args.max_retries,
            retry_wait=args.retry_wait,
            incremental_sync=False,
            time_cutoff=args.time,
            config=CONFIG,
        )
    else:
        print("\n=== STEP 2: Generating TTS audio [SKIPPED] ===")

    # ------------------------------------------------------------------
    # Step 3: CSV + WAV → npc_database.lua
    # ------------------------------------------------------------------
    if not args.skip_metadata:
        df_meta = df_full.copy()
        df_meta = df_meta.drop_duplicates(subset=["npc_name", "text"])
        df_meta["text"] = df_meta["text"].apply(normalize_dialog_text)
        # merge_item_text_rows is called inside sync_metadata
        sync_metadata(df_meta, npc_lookup=npc_lookup, config=CONFIG)
    else:
        print("\n=== STEP 3: Syncing metadata [SKIPPED] ===")

    print("\n" + "=" * 60)
    print("PIPELINE COMPLETE")
    print("=" * 60)


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    args = parse_args()

    print("=" * 60)
    print("UNIFIED TTS PIPELINE")
    print("=" * 60)

    # Load metadata once; shared across all pipeline steps
    npc_lookup = load_npc_metadata(config=CONFIG)

    # Load narrator references
    ref_codes = build_ref_codes(CONFIG["samples_dir"])

    # Validate narrator override
    if args.narrator and args.narrator not in ref_codes:
        print(f"[ERROR] Narrator '{args.narrator}' not found in {CONFIG['samples_dir']}")
        print(f"        Available: {', '.join(sorted(ref_codes.keys()))}")
        sys.exit(1)

    # Initialize TTS model once (skip if not generating audio)
    tts = None
    if not args.skip_audio:
        from omnivoice_backend import OmniVoiceBackend
        print(f"[INFO] Loading {args.tts_model} on {args.device}…")
        tts = OmniVoiceBackend.from_pretrained(
            args.tts_model,
            device=args.device,
            language=args.tts_language,
            num_step=args.tts_steps,
            speed=args.tts_speed,
            asr_model_name=args.asr_model,
        )
        print("[INFO] TTS model ready")

    # ------------------------------------------------------------------
    # Daemon mode
    # ------------------------------------------------------------------
    if args.daemon:
        betterquest_path = find_betterquest_file(args.wtf_path)
        if not betterquest_path:
            print(f"[ERROR] BetterQuest.lua not found under {args.wtf_path}")
            sys.exit(1)
        print(f"[DAEMON] Found: {betterquest_path}")

        def on_change(filepath):
            run_pipeline(args, npc_lookup, ref_codes, tts, betterquest_path=filepath)

        monitor_file_changes(betterquest_path, check_interval=args.daemon_interval, callback=on_change)
        return

    # ------------------------------------------------------------------
    # Single run
    # ------------------------------------------------------------------
    run_pipeline(args, npc_lookup, ref_codes, tts)


if __name__ == "__main__":
    main()
