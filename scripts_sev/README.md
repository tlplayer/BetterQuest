# BetterQuest Severian pipeline

This directory is the Severian conversion of the Python modules in `scripts/`.
The native program owns CSV and SavedVariables parsing, text normalization,
filtering, deduplication, narrator selection, output naming, Lua metadata
rendering, and orchestration. The final model invocation is the installed
OmniVoice inference executable; none of the BetterQuest Python modules are
loaded or executed.

From the add-on root, use the freshly built Severian CLI:

```sh
sev build scripts_sev
sev test scripts_sev
sev coverage scripts_sev
sev scripts_sev/src/core.sev
aplay scripts_sev/output/thrall_4974_quest_complete.wav
```

`sev run scripts_sev` is the equivalent package-oriented invocation.

The bounded trial stages one Thrall record from the production
`data/all_npc_dialog.csv`, then parses that record and the production
`data/npc_race.yaml` and `data/npc_sex.yaml` in Severian. It clones the
`samples/orc.wav` reference and writes the result under `scripts_sev/output/`.
The bounded staging avoids the current runtime's quadratic cost when building
multi-megabyte immutable strings one character at a time.

For reproducible Python/Severian parity, the OmniVoice command sets both
position and class sampling temperatures to zero. With identical model dtype,
text, reference audio and transcript, the Severian-run WAV is byte-for-byte
identical to direct Python `OmniVoice.generate` output.
