-- portraitdb.lua
-- Portrait database for BetterQuestText
-- Maps NPC names, zones, and races to portrait texture paths
--
-- Texture Paths:
--   portraits/npcs/   - Named NPCs
--   portraits/books/  - Book reader portraits
--   portraits/notes/  - Note reader portraits

PortraitDB = {
  named = {},
  zone = {},
  race = {},
  default = "Interface\\AddOns\\BetterQuestText\\portraits\\default",
}

-------------------------
-- NAMED NPCS
-------------------------

PortraitDB.named = {
  -- Faction Leaders
  ["Thrall"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\thrall",
  ["Cairne Bloodhoof"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\cairne",
  ["Vol'jin"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\voljin",
  ["King Magni Bronzebeard"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\magni",
  ["Lady Sylvanas Windrunner"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\sylvanas",
  ["Highlord Bolvar Fordragon"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\bolvar",
  ["Tyrande Whisperwind"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\tyrande",
  
  -- Dun Modr NPCs
  ["Mountaineer Kadrell"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Mountaineer Wallbang"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Mountaineer Stormpike"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Ragnar Thunderbrew"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Khazgorm"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Miran"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Grumnus Steelshaper"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Tognus Flintfire"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Longbraid the Grim"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Tharek Blackstone"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
}

-------------------------
-- ZONE-BASED PORTRAITS
-------------------------

PortraitDB.zone = {
  -- Major Cities
  ["Orgrimmar"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\orc_generic.tga",
  ["Stormwind City"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\human_generic.tga",
  ["Ironforge"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Darnassus"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\nightelf_generic.tga",
  ["Thunder Bluff"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\tauren_generic.tga",
  ["Undercity"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\undead_generic.tga",
  
  -- Zones
  ["Dun Morogh"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
  ["Wetlands"] = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_generic.tga",
}

-------------------------
-- RACE-BASED FALLBACKS
-------------------------

PortraitDB.race = {
  ["Human"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\human_male.tga",
               female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\human_female.tga" },
  ["Orc"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\orc_male.tga",
              female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\orc_female.tga" },
  ["Dwarf"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_male.tga",
                female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\dwarf_female.tga" },
  ["Night Elf"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\nightelf_male.tga",
                    female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\nightelf_female.tga" },
  ["Undead"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\undead_male.tga",
                 female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\undead_female.tga" },
  ["Tauren"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\tauren_male.tga",
                 female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\tauren_female.tga" },
  ["Gnome"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\gnome_male.tga",
                female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\gnome_female.tga" },
  ["Troll"] = { male = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\troll_male.tga",
                female = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\troll_female.tga" },
}
