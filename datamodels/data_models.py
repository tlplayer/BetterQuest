from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any

# -----------------------------
# Core NPC / Creature Model
# -----------------------------
@dataclass
class NPC:
    npc_id: int                       # Unique NPC entry ID
    name: str                          # NPC name (very important!)
    race: Optional[str] = None         # Race inferred from model or DB
    sex: Optional[str] = None          # Male/Female
    display_ids: Dict[str, int] = field(default_factory=dict)  # e.g. main/secondary/tertiary/quaternary
    race_mask: Optional[int] = None
    quests: List["QuestInteraction"] = field(default_factory=list)  # Linked quests
    gossip_texts: List["GossipText"] = field(default_factory=list)   # Linked gossip texts

# -----------------------------
# Quest Info
# -----------------------------
@dataclass
class QuestInteraction:
    quest_id: int
    source_type: str                  # "accept", "progress", "complete"
    quest_title: str
    quest_text: str                   # What the NPC says for this step
    extra: Dict[str, Any] = field(default_factory=dict)

# -----------------------------
# Gossip / Broadcast Text Info
# -----------------------------
@dataclass
class GossipText:
    text_id: int
    text: str
    broadcast_type: str               # "male" / "female" / "neutral"
    related_quest_id: Optional[int] = None
    extra: Dict[str, Any] = field(default_factory=dict)

# -----------------------------
# Sample TTS Data Model
# -----------------------------
@dataclass
class TTS_Sample:
    text: str
    audio_file: Optional[str] = None     # Path to audio file
    npc_name: Optional[str] = None
    npc_race: Optional[str] = None
    npc_sex: Optional[str] = None
    quest_id: Optional[int] = None
    quest_text: Optional[str] = None
