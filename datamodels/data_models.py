from dataclasses import dataclass, field
from typing import Optional

from enum import Enum

class Narrator(Enum):
    HUMAN = "human"
    HUMAN_FEMALE = "human_female"
    DWARF = "dwarf"
    DWARF_FEMALE = "dwarf_female"
    ELF = "elf"
    ELF_FEMALE = "elf_female"
    GNOME = "gnome"
    GNOME_FEMALE = "gnome_female"
    ORC = "orc"
    ORC_FEMALE = "orc_female"
    TROLL = "troll"
    TROLL_FEMALE = "troll_female"
    TAUREN = "tauren"
    TAUREN_FEMALE = "tauren_female"
    UNDEAD = "undead"
    UNDEAD_FEMALE = "undead_female"
    DEMON = "demon"
    SUCCUBUS = "succubus"
    FELGUARD = "felguard"
    NAGA = "naga"
    NAGA_FEMALE = "naga_female"
    ELEMENTAL = "elemental"
    SPIRIT = "spirit"
    DRAGON = "dragon"
    ANCIENT = "ancient"
    OGRE = "ogre"
    OGRE_FEMALE = "ogre_female"
    SATYR = "satyr"
    GIANT = "giant"
    MURLOC = "murloc"
    GNOLL = "gnoll"
    KOBOLD = "kobold"
    MECHANICAL = "mechanical"
    CONSTRUCT = "construct"
    ITEM = "item"




@dataclass
class DialogueEntry:
    name: str                    # NPC name
    id: str # could be quest id, item id etc. but it needs to match the dialog type this is how we link NPC <> quest from llm
    race: Optional[str] = None   # e.g., "human", "orc"
    sex: Optional[str] = None    # "male" or "female"
    dialog_type: str = "gossip" # "gossip", "quest", etc
    text: str = ""               # The line to be spoken
    zone: Optional[str] = None   # Zone the NPC is in
    narrator: Optional[str] = None  # TTS voice/narrator, e.g., "default", "Sean Bean"
    portrait: Optional[str] = None  # Optional: generic portrait or specific
    model_id: Optional[int] = None   # Optional: model display id or GUID

# Example usage
entries = [
    DialogueEntry(
        name="Marshal Dughan",
        race="human",
        sex="male",
        dialog_type="gossip",
        text="Ach, it's hard enough keeping order around here without all these new troubles popping up!  I hope you have good news, $n...",
        zone="Elwyn Forest",
        narrator="default",
        portrait="human",
        model_id=1985
    ),
    DialogueEntry(
        name="King of Stormwind",
        race="human",
        sex="male",
        dialog_type="gossip",
        text="The kingdom counts on your bravery.",
        zone="Stormwind City",
        narrator="Sean Bean",
        portrait="human_king",
        model_id=1234
    )
]
