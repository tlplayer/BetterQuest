# BetterQuest Severian pipeline

This package ports the BetterQuest data pipeline from `scripts/*.py` to native
Severian. It never invokes Python, a shell, or `omnivoice-infer`.

## Current parity

Implemented in `.sev`:

- BetterQuest SavedVariables discovery, schema-v2/legacy Lua parsing, daemon
  monitoring, CSV schema upgrades, escaping, indexing, and append-only sync;
- dialog normalization, filtering, item/book merging, deduplication, narrator
  resolution, Python-compatible MD5 signatures, and audio path selection;
- chunked generation orchestration, retry policy, regeneration cutoffs, and a
  native mono PCM16 WAV writer;
- JSON plus YAML NPC metadata loading, WAV duration parsing, locked incremental
  Lua updates, full metadata synchronization, missing-race output, and linked
  dialog entries;
- native MariaDB extraction for ScriptDev2/dbscripts, recursive gossip owners,
  recursive page text, quest text and greetings, AI/spell sources, orphan
  broadcasts, investigation CSV output, and source-of-truth regression checks;
- the Python CLI filters, skip flags, generation controls, and daemon workflow.

CSV parsing stays with `file.read(...)`/`csv.CSV`; schema, filtering, grouping,
indexing, and uniqueness use the format-independent `data.Data` layer. Shared
dialog/table conversion lives in `src/dialog_data.sev`, and filesystem metadata
and directory operations use `os`/`path` rather than the `file` content API.

The remaining blocker is the model itself. Severian does not yet implement the
OmniVoice architecture, audio tokenizer, Whisper fallback, weight loader, and
CUDA kernels required by `OmniVoiceBackend`. The backend therefore returns a
typed failure instead of silently producing substitute audio or spawning the
Python implementation. Data sync, extraction, metadata output, and deterministic
test backends are native today; production OmniVoice synthesis is not yet at
1:1 parity.

## Run and test

Run commands from the add-on root so the paths in `core.sev` resolve to
`data/`, `samples/`, `sounds/`, and `db/`:

```sh
sev check scripts_sev
sev run scripts_sev -- --skip-audio

# Exercise every converted module, not only the binary entry point.
for source in scripts_sev/src/*.sev; do
    sev test "$source" || exit 1
done
```

Useful pipeline examples:

```sh
# Sync SavedVariables and rebuild Lua metadata without attempting audio.
sev run scripts_sev -- --skip-audio

# Filter generation work exactly as the Python CLI does.
sev run scripts_sev -- --race orc --zone Durotar --type gossip --limit 20

# Watch the newest BetterQuest.lua under a WoW WTF directory.
sev run scripts_sev -- --daemon --wtf-path ../../../../WTF --skip-audio
```

The package depends on the accompanying Severian standard-library additions
for native file/directory operations, MD5, JSON nulls, MariaDB, file locking,
process arguments, and date parsing. The compiler changes also make conditional
expressions lazy and complete native lowering for map iteration/access.
