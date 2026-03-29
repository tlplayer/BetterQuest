"""
utils.py
--------
Pure string utilities shared across adapter_db, adapter_game, and generator.
No I/O, no torch, no pandas.
"""

import hashlib
import re


def normalize_name(name):
    """Strip parenthetical suffixes, quotes, leading backslashes, and whitespace."""
    if not isinstance(name, str):
        return None
    name = re.sub(r"\s*\(.*?\)", "", name)
    name = re.sub(r"['']", "'", name)   # curly → straight
    name = name.lstrip("\\")
    return name.strip().replace('"', '').replace("'", "")


def sanitize_filename(name):
    """Make a string safe for use as a filename component."""
    name = name.strip()
    name = re.sub(r"[^\w\s-]", "", name)
    name = re.sub(r"\s+", "_", name)
    return name.lower()


def remove_audio_cues(text):
    """Strip bracketed sound cues, parentheticals, and short onomatopoeia lines."""
    if not isinstance(text, str):
        return text
    patterns = [
        r"\[[^\]]*\]",
        r"\([^\)]*\)",
        r"<[^>]*>",
        r"\*[^*]+\*",
        r"\b(?:sfx|audio|sound)\s*:\s*[^\n]+",
    ]
    text = re.sub(r"(?m)^\s*[a-z]{1,4}[.!?…]*\s*$", "", text, flags=re.IGNORECASE)
    for pat in patterns:
        text = re.sub(pat, "", text, flags=re.IGNORECASE)
    return text


def normalize_dialog_text(text):
    """
    Expand WoW dialog tokens into TTS-safe equivalents.
    Apply to the 'text' column before generation or metadata sync.
    """
    if not isinstance(text, str):
        return text
    text = re.sub(r"\$B+", "\n", text, flags=re.IGNORECASE)
    text = remove_audio_cues(text)
    replacements = [
        (r"\$(lad|lass)\b[^.?!;\n]*", "adventurer"),
        (r"\$(n|N|r|R|c|C)\b",         "adventurer"),
        (r"\$g[^;]*;",                  "adventurer"),
        (r"\$\w+",                      ""),
    ]
    for pat, repl in replacements:
        text = re.sub(pat, repl, text, flags=re.IGNORECASE)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def normalize_text_for_matching(text):
    """
    Canonical form for Lua lookup keys.
    Removes WoW tokens, punctuation, and extra whitespace.
    """
    if not isinstance(text, str):
        return ""
    text = re.sub(r"\$B+", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"\$(lad|lass)\b[^.?!;\n]*", "adventurer", text, flags=re.IGNORECASE)
    text = re.sub(r"\$(n|N|r|R|c|C)\b", "adventurer", text)
    text = re.sub(r"\$g[^;]*;", "adventurer", text, flags=re.IGNORECASE)
    text = re.sub(r"\$\w+", "", text, flags=re.IGNORECASE)
    for pat in [r"\[[^\]]*\]", r"\([^\)]*\)", r"<[^>]*>", r"\*[^*]+\*"]:
        text = re.sub(pat, "", text)
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip().lower()


def create_text_hash(text):
    """50-char normalized prefix used as Lua dialog key."""
    normalized = normalize_text_for_matching(text)
    return normalized[:50] if normalized else ""


def create_dialog_signature(text, race, sex):
    """MD5-based dedup key: original text + race + sex."""
    sig = f"{text.strip()}|{race or 'unknown'}|{sex or 'unknown'}"
    return hashlib.md5(sig.encode()).hexdigest()[:16]