# ---------- BetterQuest.lua integration ----------
BETTERQUEST_LUA = "../../../../WTF/Account/ADMIN/SavedVariables/BetterQuest.lua"

import csv
import os

def _find_matching_brace(s, start_idx):
    """
    Given s[start_idx] == '{', return index of matching '}'.
    Skips over quoted strings and handles nested braces.
    Returns -1 on failure.
    """
    i = start_idx
    n = len(s)
    if i >= n or s[i] != "{":
        return -1
    depth = 0
    while i < n:
        ch = s[i]
        if ch == '"' or ch == "'":
            # skip quoted string
            quote = ch
            i += 1
            while i < n:
                if s[i] == "\\":
                    i += 2  # skip escaped char
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
    Parse a Lua string literal starting at start_idx where s[start_idx] is a quote.
    Returns (unescaped_python_string, idx_after_closing_quote) or (None, start_idx) on failure.
    Handles \" and \\ escapes.
    """
    n = len(s)
    if start_idx >= n or s[start_idx] not in ('"', "'"):
        return None, start_idx
    quote = s[start_idx]
    i = start_idx + 1
    out_chars = []
    while i < n:
        ch = s[i]
        if ch == "\\":
            # handle escape
            i += 1
            if i >= n:
                break
            esc = s[i]
            # keep common escapes; otherwise keep the escaped char
            if esc == "n":
                out_chars.append("\n")
            elif esc == "t":
                out_chars.append("\t")
            elif esc == "r":
                out_chars.append("\r")
            else:
                out_chars.append(esc)
            i += 1
        elif ch == quote:
            return "".join(out_chars), i + 1
        else:
            out_chars.append(ch)
            i += 1
    return None, start_idx

def _extract_missing_npcs_from_lua(lua_text):
    """
    Parse the BetterQuestDB.lua text and extract a dict:
      { npc_name: [ { 'text':..., 'dialog_type':..., 'count':... , 'originalName':... }, ... ] }
    This function does not use regexes for nested structures except to find the missingNPCs block start.
    """
    result = {}
    marker = '["missingNPCs"]'
    idx = lua_text.find(marker)
    if idx == -1:
        return result

    # find the '=' after the marker, then the opening '{'
    eq_idx = lua_text.find("=", idx)
    if eq_idx == -1:
        return result
    brace_idx = lua_text.find("{", eq_idx)
    if brace_idx == -1:
        return result
    end_brace = _find_matching_brace(lua_text, brace_idx)
    if end_brace == -1:
        return result

    block = lua_text[brace_idx:end_brace+1]

    i = 0
    L = len(block)
    # iterate through entries like ["Kaltunk"] = { ... },
    while i < L:
        # find next ["<name>"]
        start_key = block.find('["', i)
        if start_key == -1:
            break
        key_start = start_key + 2
        key_end = block.find('"]', key_start)
        if key_end == -1:
            break
        npc_key = block[key_start:key_end]
        # find '=' after key_end
        eq = block.find("=", key_end)
        if eq == -1:
            i = key_end + 2
            continue
        # find opening brace for this npc table
        npc_brace = block.find("{", eq)
        if npc_brace == -1:
            i = eq + 1
            continue
        npc_end = _find_matching_brace(block, npc_brace)
        if npc_end == -1:
            break
        npc_block = block[npc_brace:npc_end+1]

        # find originalName inside npc_block (optional)
        original_name = None
        on = npc_block.find('["originalName"]')
        if on != -1:
            # find '=' and string after it
            on_eq = npc_block.find("=", on)
            if on_eq != -1:
                # find first quote
                qpos = npc_block.find('"', on_eq)
                if qpos == -1:
                    qpos = npc_block.find("'", on_eq)
                if qpos != -1:
                    parsed, after = _parse_lua_string(npc_block, qpos)
                    if parsed is not None:
                        original_name = parsed

        # find dialogs table inside npc_block
        dialogs_marker = '["dialogs"]'
        dpos = npc_block.find(dialogs_marker)
        dialogs = []
        if dpos != -1:
            d_eq = npc_block.find("=", dpos)
            if d_eq != -1:
                d_brace = npc_block.find("{", d_eq)
                if d_brace != -1:
                    d_end = _find_matching_brace(npc_block, d_brace)
                    if d_end != -1:
                        dialogs_block = npc_block[d_brace:d_end+1]
                        # parse individual dialog entries: ["key"] = { ... },
                        j = 0
                        M = len(dialogs_block)
                        while j < M:
                            kstart = dialogs_block.find('["', j)
                            if kstart == -1:
                                break
                            k_s = kstart + 2
                            k_e = dialogs_block.find('"]', k_s)
                            if k_e == -1:
                                break
                            dialog_hash = dialogs_block[k_s:k_e]

                            # find '=' and then opening brace for this dialog entry
                            keq = dialogs_block.find("=", k_e)
                            if keq == -1:
                                j = k_e + 2
                                continue
                            kbrace = dialogs_block.find("{", keq)
                            if kbrace == -1:
                                j = keq + 1
                                continue
                            k_end = _find_matching_brace(dialogs_block, kbrace)
                            if k_end == -1:
                                break
                            entry_block = dialogs_block[kbrace:k_end+1]

                            # extract fields dialog_text, dialogType, count
                            # dialog_text may be multi-line; find '["dialog_text"]' inside entry_block
                            def _find_field_string(block, fieldname):
                                marker = '["' + fieldname + '"]'
                                pos = block.find(marker)
                                if pos == -1:
                                    return None
                                eqpos = block.find("=", pos)
                                if eqpos == -1:
                                    return None
                                # find first quote after eqpos
                                q = block.find('"', eqpos)
                                if q == -1:
                                    q = block.find("'", eqpos)
                                if q == -1:
                                    return None
                                parsed, after = _parse_lua_string(block, q)
                                return parsed

                            def _find_field_token(block, fieldname):
                                # simple numeric or word token after =
                                marker = '["' + fieldname + '"]'
                                pos = block.find(marker)
                                if pos == -1:
                                    return None
                                eqpos = block.find("=", pos)
                                if eqpos == -1:
                                    return None
                                # read token until comma or brace
                                tstart = eqpos + 1
                                while tstart < len(block) and block[tstart].isspace():
                                    tstart += 1
                                tend = tstart
                                while tend < len(block) and block[tend] not in [",", "}"]:
                                    tend += 1
                                token = block[tstart:tend].strip()
                                return token or None

                            dialog_text = _find_field_string(entry_block, "dialog_text")
                            dialog_type = _find_field_string(entry_block, "dialogType")
                            if dialog_type is None:
                                # In some dumps dialogType uses different capitalization or unquoted token
                                dt_tok = _find_field_token(entry_block, "dialogType")
                                if dt_tok:
                                    dialog_type = dt_tok.strip('"').strip("'")
                            count_tok = _find_field_token(entry_block, "count")
                            count = None
                            if count_tok:
                                try:
                                    count = int(count_tok)
                                except Exception:
                                    count = None

                            dialogs.append({
                                "hash": dialog_hash,
                                "dialog_text": dialog_text,
                                "dialogType": dialog_type or "unknown",
                                "count": count or 1,
                            })

                            j = k_end + 1

        # add to result using originalName if available, otherwise npc_key
        npc_name_key = original_name or npc_key
        # ensure normalized trimming
        npc_name_key = npc_name_key.strip() if isinstance(npc_name_key, str) else npc_key

        if dialogs:
            result[npc_name_key] = dialogs

        i = npc_end + 1  # move outer loop forward

    return result

def _load_csv_index(csv_path):
    """
    Load existing CSV into a set of tuples: (npc_name, dialog_type, quest_id, text)
    """
    existing = set()
    if not os.path.exists(csv_path):
        return existing
    with open(csv_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            key = (
                (r.get("npc_name") or "").strip(),
                (r.get("dialog_type") or "").strip(),
                (r.get("quest_id") or "").strip() if r.get("quest_id") is not None else "",
                (r.get("text") or "").strip()
            )
            existing.add(key)
    return existing

def append_missing_to_csv(csv_path="../data/all_npc_dialog.csv", lua_path=BETTERQUEST_LUA):
    """
    Parse BetterQuestDB.lua and append any missing dialog lines to CSV.
    Columns: npc_name, sex, dialog_type, quest_id, text
    (sex left empty; quest_id left empty - missingNPCs don't have quest associations)
    """
    if not os.path.exists(lua_path):
        print(f"BetterQuest DB not found at: {lua_path}")
        return 0

    with open(lua_path, "r", encoding="utf-8") as f:
        lua_text = f.read()

    missing = _extract_missing_npcs_from_lua(lua_text)
    if not missing:
        print("No missingNPCs found in BetterQuestDB.lua")
        return 0

    existing = _load_csv_index(csv_path)

    to_append = []
    for npc_name, dialogs in missing.items():
        for d in dialogs:
            text = (d.get("dialog_text") or "").strip()
            if not text:
                continue
            dialog_type = (d.get("dialogType") or "unknown").lower()
            key = (npc_name.strip(), dialog_type, "", text)
            if key not in existing:
                to_append.append({
                    "npc_name": npc_name.strip(),
                    "sex": "",  # not known from BetterQuestDB
                    "dialog_type": dialog_type,
                    "quest_id": "",
                    "text": text
                })
                existing.add(key)

    if not to_append:
        print("No new missingNPC dialogs to add.")
        return 0

    # Ensure CSV exists with header
    write_header = not os.path.exists(csv_path)
    os.makedirs(os.path.dirname(csv_path), exist_ok=True)

    with open(csv_path, "a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["npc_name", "sex", "dialog_type", "quest_id", "text"])
        if write_header:
            writer.writeheader()
        for row in to_append:
            writer.writerow(row)

    print(f"Appended {len(to_append)} missingNPC dialog rows to {csv_path}")
    return len(to_append)


if __name__ == "__main__":
    appended = append_missing_to_csv()
    print(f"Appended {appended} rows from BetterQuestDB.lua")
