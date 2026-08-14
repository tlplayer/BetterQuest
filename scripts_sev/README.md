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

Decoded JSON, YAML, and CSV values load through extension-aware `file.load(...)`;
document mutation and raw binary access stay with `file.read(...)`. Schema,
filtering, grouping, indexing, and uniqueness use the format-independent `data.Data` layer. Shared
dialog/table conversion lives in `src/dialog_data.sev`, and filesystem metadata
and directory operations use `os`/`path` rather than the `file` content API.

The model layer now supplies OmniVoice's time-shifted unmask schedule,
classifier-free guidance, Gumbel selection, codebook penalties, duration
estimation, typed voice prompts, generic audio-model/codec boundaries, lazy F32
safetensor views, and both sharded and single-file safetensor stores. The
BetterQuest backend uses those primitives for transcript caching and native
generation planning.

Production synthesis still stops with a typed error at the remaining honest
boundary: Severian cannot yet execute OmniVoice's Qwen3 audio graph or the
Higgs audio tokenizer/vocoder, and has no native Whisper fallback. It does not
silently create substitute audio or spawn Python. Data sync, extraction,
metadata output, generation planning, and deterministic test backends are
native; waveform synthesis is not yet at 1:1 parity.

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
