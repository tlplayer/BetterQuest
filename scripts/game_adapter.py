"""
adapter_game.py
---------------
Reads BetterQuest.lua (game SavedVariables) and appends new dialog rows
to all_npc_dialog.csv.  No audio, no metadata, no Lua DB writes.

Public API
----------
sync_game_data(csv_path, lua_path) -> int   # rows appended
find_betterquest_file(base_path)    -> str | None
monitor_file_changes(filepath, check_interval, callback)
"""

import csv
import glob
import os
import tempfile
import time
from datetime import datetime

# ---------------------------------------------------------------------------
# FILE DISCOVERY
# ---------------------------------------------------------------------------

def find_betterquest_file(base_path="../../../../WTF"):
    """
    Locate BetterQuest.lua under base_path, account-name agnostic.
    Returns the path string, or None if not found.
    Prefers the most recently modified file when multiple matches exist.
    """
    patterns = [
        os.path.join(base_path, "Account", "*", "SavedVariables", "BetterQuest.lua"),
        os.path.join(base_path, "*", "SavedVariables", "BetterQuest.lua"),
        os.path.join(base_path, "SavedVariables", "BetterQuest.lua"),
    ]

    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            if len(matches) > 1:
                matches.sort(key=lambda x: os.path.getmtime(x), reverse=True)
                print(f"[INFO] {len(matches)} BetterQuest.lua files found, using most recent: {matches[0]}")
            return matches[0]

    return None


def monitor_file_changes(filepath, check_interval=5, callback=None):
    """
    Poll filepath every check_interval seconds; call callback(filepath) on modification.
    Blocks until KeyboardInterrupt.
    """
    if not os.path.exists(filepath):
        print(f"[ERROR] File not found: {filepath}")
        return

    print(f"[DAEMON] Monitoring: {filepath}")
    print(f"[DAEMON] Interval:   {check_interval}s  |  Ctrl-C to stop\n")

    last_mtime = os.path.getmtime(filepath)
    last_processed = datetime.now()

    try:
        while True:
            time.sleep(check_interval)
            try:
                current_mtime = os.path.getmtime(filepath)
                if current_mtime > last_mtime:
                    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"\n{'='*60}\n[DAEMON] File modified at {ts}\n{'='*60}")
                    last_mtime = current_mtime
                    if callback:
                        try:
                            callback(filepath)
                        except Exception as e:
                            import traceback
                            print(f"[ERROR] Callback failed: {e}")
                            traceback.print_exc()
                    last_processed = datetime.now()
                    print("\n[DAEMON] Waiting for next change...")

            except FileNotFoundError:
                print(f"[WARNING] File disappeared: {filepath}")
            except Exception as e:
                print(f"[ERROR] Monitor error: {e}")

    except KeyboardInterrupt:
        elapsed = (datetime.now() - last_processed).total_seconds() / 60
        print(f"\n[DAEMON] Stopped. Last processed {elapsed:.1f}m ago.")


# ---------------------------------------------------------------------------
# LUA PARSING  (pure text; no dependencies on the rest of the pipeline)
# ---------------------------------------------------------------------------

def _find_matching_brace(s, start_idx):
    """
    Return index of the closing '}' that matches s[start_idx] == '{'.
    Handles nested braces and quoted strings.  Returns -1 on failure.
    """
    i = start_idx
    n = len(s)
    if i >= n or s[i] != "{":
        return -1
    depth = 0
    while i < n:
        ch = s[i]
        if ch in ('"', "'"):
            quote = ch
            i += 1
            while i < n:
                if s[i] == "\\":
                    i += 2
                elif s[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _parse_lua_string(s, start_idx):
    """
    Parse a Lua string literal starting at s[start_idx] (a quote character).
    Returns (python_str, idx_after_close) or (None, start_idx) on failure.
    """
    n = len(s)
    if start_idx >= n or s[start_idx] not in ('"', "'"):
        return None, start_idx
    quote = s[start_idx]
    i = start_idx + 1
    out = []
    while i < n:
        ch = s[i]
        if ch == "\\":
            i += 1
            if i >= n:
                break
            esc = s[i]
            out.append({"n": "\n", "t": "\t", "r": "\r"}.get(esc, esc))
            i += 1
        elif ch == quote:
            return "".join(out), i + 1
        else:
            out.append(ch)
            i += 1
    return None, start_idx


def _find_field_string(block, fieldname):
    """Extract a Lua string field value: ["fieldname"] = "value" """
    marker = '["' + fieldname + '"]'
    pos = block.find(marker)
    if pos == -1:
        return None
    eq = block.find("=", pos)
    if eq == -1:
        return None
    q = block.find('"', eq)
    if q == -1:
        q = block.find("'", eq)
    if q == -1:
        return None
    parsed, _ = _parse_lua_string(block, q)
    return parsed


def _find_field_table(block, fieldname):
    """Return the complete Lua table assigned to a named field."""
    marker = '["' + fieldname + '"]'
    pos = block.find(marker)
    if pos == -1:
        return None
    eq = block.find("=", pos)
    if eq == -1:
        return None
    start = block.find("{", eq)
    if start == -1:
        return None
    end = _find_matching_brace(block, start)
    return block[start : end + 1] if end != -1 else None


def _find_string_table_values(block, fieldname):
    """Extract string values from a simple SavedVariables table field."""
    table = _find_field_table(block, fieldname)
    if not table:
        return []

    values = []
    i = 0
    while i < len(table):
        eq = table.find("=", i)
        if eq == -1:
            break
        value_start = eq + 1
        while value_start < len(table) and table[value_start].isspace():
            value_start += 1
        if value_start < len(table) and table[value_start] in ('"', "'"):
            value, after = _parse_lua_string(table, value_start)
            if value is not None and value not in values:
                values.append(value)
            i = after
        else:
            i = value_start + 1
    return values


def _extract_missing_npcs_from_lua(lua_text):
    """
    Parse BetterQuest.lua and return:
        { npc_name: [{text, zone, expansion, client_version}, ...] }

    Expected Lua schema:
        BetterQuestDB = {
            ["NPC Name"] = {
                ["originalName"] = "NPC Name",   -- optional
                ["dialogs"] = {
                    ["hash_key"] = "Legacy dialog text.",
                    ["new_hash"] = {
                        ["text"] = "Full dialog text.",
                        ["zone"] = "Elwynn Forest",
                        ["expansion"] = "vanilla",
                        ["clientVersion"] = "1.12.1",
                    },
                    ...
                },
            },
            ...
        }

    Both legacy string values and schema-v2 record values are accepted.
    Uses originalName as the result key when present.
    """
    result = {}

    # Find the top-level table: BetterQuestDB = { ... }
    marker = "BetterQuestDB"
    idx = lua_text.find(marker)
    if idx == -1:
        return result
    eq_idx = lua_text.find("=", idx)
    if eq_idx == -1:
        return result
    brace_idx = lua_text.find("{", eq_idx)
    if brace_idx == -1:
        return result
    end_brace = _find_matching_brace(lua_text, brace_idx)
    if end_brace == -1:
        return result

    top_block = lua_text[brace_idx : end_brace + 1]
    metadata_block = _find_field_table(top_block, "metadata") or ""
    saved_expansion = _find_field_string(metadata_block, "expansion") or ""
    saved_client_version = _find_field_string(metadata_block, "clientVersion") or ""
    i = 0
    L = len(top_block)

    while i < L:
        # Find next NPC key: ["NPC Name"]
        start_key = top_block.find('["', i)
        if start_key == -1:
            break
        key_start = start_key + 2
        key_end = top_block.find('"]', key_start)
        if key_end == -1:
            break
        npc_key = top_block[key_start:key_end]

        # Find '=' then opening '{' for this NPC's sub-table
        eq = top_block.find("=", key_end)
        if eq == -1:
            i = key_end + 2
            continue
        npc_brace = top_block.find("{", eq)
        if npc_brace == -1:
            i = eq + 1
            continue
        npc_end = _find_matching_brace(top_block, npc_brace)
        if npc_end == -1:
            break
        npc_block = top_block[npc_brace : npc_end + 1]

        # Extract originalName (optional override for the key)
        original_name = _find_field_string(npc_block, "originalName")
        npc_zones = _find_string_table_values(npc_block, "zones")
        legacy_zone = npc_zones[0] if len(npc_zones) == 1 else ""

        # Find the dialogs sub-table
        dialogs = []
        dpos = npc_block.find('["dialogs"]')
        if dpos != -1:
            d_eq = npc_block.find("=", dpos)
            if d_eq != -1:
                d_brace = npc_block.find("{", d_eq)
                if d_brace != -1:
                    d_end = _find_matching_brace(npc_block, d_brace)
                    if d_end != -1:
                        dialogs_block = npc_block[d_brace : d_end + 1]
                        j = 0
                        M = len(dialogs_block)
                        while j < M:
                            # Find each ["hash_key"] entry
                            kstart = dialogs_block.find('["', j)
                            if kstart == -1:
                                break
                            k_s = kstart + 2
                            k_e = dialogs_block.find('"]', k_s)
                            if k_e == -1:
                                break

                            keq = dialogs_block.find("=", k_e)
                            if keq == -1:
                                j = k_e + 2
                                continue

                            # Skip whitespace to find the opening quote
                            vstart = keq + 1
                            while vstart < M and dialogs_block[vstart].isspace():
                                vstart += 1

                            if vstart < M and dialogs_block[vstart] in ('"', "'"):
                                dialog_text, after = _parse_lua_string(dialogs_block, vstart)
                                if dialog_text is not None:
                                    dialogs.append({
                                        "text": dialog_text,
                                        "zone": legacy_zone,
                                        "expansion": saved_expansion,
                                        "client_version": saved_client_version,
                                    })
                                j = after if after > vstart else vstart + 1
                            elif vstart < M and dialogs_block[vstart] == "{":
                                value_end = _find_matching_brace(dialogs_block, vstart)
                                if value_end == -1:
                                    j = vstart + 1
                                    continue
                                value_block = dialogs_block[vstart : value_end + 1]
                                dialog_text = _find_field_string(value_block, "text")
                                if dialog_text is not None:
                                    dialogs.append({
                                        "text": dialog_text,
                                        "zone": _find_field_string(value_block, "zone") or legacy_zone,
                                        "expansion": _find_field_string(value_block, "expansion") or saved_expansion,
                                        "client_version": _find_field_string(value_block, "clientVersion") or saved_client_version,
                                    })
                                j = value_end + 1
                            else:
                                j = keq + 1

        npc_name_key = (original_name or npc_key).strip()
        if dialogs:
            result.setdefault(npc_name_key, []).extend(dialogs)

        i = npc_end + 1

    return result


# ---------------------------------------------------------------------------
# CSV I/O
# ---------------------------------------------------------------------------

_CSV_FIELDNAMES = [
    "npc_name",
    "sex",
    "zone",
    "expansion",
    "client_version",
    "dialog_type",
    "quest_id",
    "text",
]


def _ensure_csv_schema(csv_path):
    """Add optional provenance columns to an older CSV without losing rows."""
    if not os.path.exists(csv_path):
        return _CSV_FIELDNAMES

    with open(csv_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        original_fields = reader.fieldnames or []
        rows = list(reader)

    extra_fields = [field for field in original_fields if field not in _CSV_FIELDNAMES]
    fieldnames = _CSV_FIELDNAMES + extra_fields
    if all(field in original_fields for field in _CSV_FIELDNAMES):
        return fieldnames

    csv_dir = os.path.dirname(os.path.abspath(csv_path))
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", newline="", dir=csv_dir, delete=False
    ) as tmp:
        writer = csv.DictWriter(tmp, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
        temp_path = tmp.name
    os.replace(temp_path, csv_path)
    print(f"[INFO] Upgraded CSV columns in {csv_path}")
    return fieldnames


def _load_csv_index(csv_path):
    """
    Return a set of identifying dialog tuples from csv_path.
    Returns empty set if file does not exist.
    """
    existing = set()
    if not os.path.exists(csv_path):
        return existing
    with open(csv_path, "r", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            existing.add((
                (r.get("npc_name") or "").strip(),
                (r.get("dialog_type") or "").strip(),
                (r.get("quest_id") or "").strip(),
                (r.get("text") or "").strip(),
                (r.get("zone") or "").strip(),
                (r.get("expansion") or "").strip().lower(),
            ))
    return existing


# ---------------------------------------------------------------------------
# PUBLIC ENTRY POINT
# ---------------------------------------------------------------------------

def sync_game_data(csv_path, lua_path):
    """
    Parse BetterQuest.lua and append any new missingNPC dialog rows to csv_path.
    Returns the number of rows appended.
    """
    print("\n=== STEP 1: Syncing game data from BetterQuest.lua ===")

    if not os.path.exists(lua_path):
        print(f"[SKIP] BetterQuest.lua not found: {lua_path}")
        return 0

    with open(lua_path, "r", encoding="utf-8") as f:
        lua_text = f.read()

    missing = _extract_missing_npcs_from_lua(lua_text)
    if not missing:
        print("[INFO] No missingNPCs found in BetterQuest.lua")
        return 0

    csv_fieldnames = _ensure_csv_schema(csv_path)
    existing = _load_csv_index(csv_path)
    to_append = []

    for npc_name, dialogs in missing.items():
        for dialog in dialogs:
            text = dialog["text"]
            # Collapse all internal whitespace sequences (including newlines) to a single space
            text = " ".join(text.split())
            if not text:
                continue
            dialog_type = "gossip"
            zone = dialog["zone"].strip()
            expansion = dialog["expansion"].strip().lower()
            key = (npc_name.strip(), dialog_type, "", text, zone, expansion)
            if key not in existing:
                to_append.append({
                    "npc_name":    npc_name.strip(),
                    "sex":         "",
                    "zone":        zone,
                    "expansion":   expansion,
                    "client_version": dialog["client_version"].strip(),
                    "dialog_type": dialog_type,
                    "quest_id":    "",
                    "text":        text,
                })
                existing.add(key)

    if not to_append:
        print("[INFO] No new missingNPC dialogs to append.")
        return 0

    write_header = not os.path.exists(csv_path)
    csv_parent = os.path.dirname(csv_path)
    if csv_parent:
        os.makedirs(csv_parent, exist_ok=True)

    with open(csv_path, "a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=csv_fieldnames, lineterminator="\n")
        if write_header:
            writer.writeheader()
        writer.writerows(to_append)

    print(f"[OK] Appended {len(to_append)} rows to {csv_path}")
    return len(to_append)
