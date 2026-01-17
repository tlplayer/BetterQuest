-- PortraitManager.lua
-- Unified portrait system for NPCs, books, and other interactions
-- WoW 1.12.1 compatible

-------------------------
-- PORTRAIT MANAGER
-------------------------

PortraitManager = {}

PortraitManager.Type = {
  NPC    = "npc",
  BOOK   = "book",
  ITEM   = "item",
  OBJECT = "object",
  CUSTOM = "custom",
}

PortraitManager.DEBUG = false

-------------------------
-- STATE
-------------------------

local currentPortrait = {
  type = nil,
  texture = nil,
  frame = nil,
}

local activeNPCName = nil

-------------------------
-- CONFIGURATION
-------------------------

local PORTRAIT_CONFIG = {
  WIDTH = 125,
  HEIGHT = 220,
  OFFSET_X = 15,
  OFFSET_Y = 50,

  -- Default fallback
  DEFAULT_NPC    = "Interface\\AddOns\\BetterQuest\\portraits\\default.tga",
  DEFAULT_BOOK   = "Interface\\Icons\\INV_Misc_Book_09",
  DEFAULT_ITEM   = "Interface\\Icons\\INV_Misc_QuestionMark",
  DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",

  -- Map portrait keys to actual file paths
  NPC_PORTRAITS = {
    ["human_male"]     = "Interface\\AddOns\\BetterQuest\\portraits\\human_male.tga",
    ["human_female"]   = "Interface\\AddOns\\BetterQuest\\portraits\\human_female.tga",
    ["dwarf_female"]   = "Interface\\AddOns\\BetterQuest\\portraits\\dwarf_female.png",
    ["dwarf_male"]     = "Interface\\AddOns\\BetterQuest\\portraits\\dwarf_generic.tga",
    ["gnome_male"]     = "Interface\\AddOns\\BetterQuest\\portraits\\gnome_male.tga",
    ["tauren_female"]  = "Interface\\AddOns\\BetterQuest\\portraits\\tauren_female.png",
    ["troll"]          = "Interface\\AddOns\\BetterQuest\\portraits\\troll.jpg",
    ["iron_golem"]     = "Interface\\AddOns\\BetterQuest\\portraits\\iron_golem.png",
    ["default"]        = "Interface\\AddOns\\BetterQuest\\portraits\\default.tga",
    -- Add more as needed
  },
}

-------------------------
-- UTIL
-------------------------

local function DebugLog(msg)
  if PortraitManager.DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. msg)
  end
end

local function GetOrCreatePortraitFrame(parentFrame)
  if not parentFrame then return nil end
  if parentFrame.widePortrait then return parentFrame.widePortrait end

  local portrait = CreateFrame("Frame", nil, parentFrame)
  portrait:SetWidth(PORTRAIT_CONFIG.WIDTH)
  portrait:SetHeight(PORTRAIT_CONFIG.HEIGHT)
  portrait:SetPoint(
    "TOPLEFT",
    parentFrame,
    "TOPLEFT",
    PORTRAIT_CONFIG.OFFSET_X,
    -PORTRAIT_CONFIG.OFFSET_Y
  )

  portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
  portrait.bg:SetAllPoints()
  portrait.bg:SetTexture(0, 0, 0, 1)

  portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
  portrait.texture:SetAllPoints()
  portrait.texture:SetTexCoord(0, 1, 0, 1)

  parentFrame.widePortrait = portrait
  return portrait
end

-------------------------
-- NPC CONTROL
-------------------------

function PortraitManager:SetActiveNPC(name)
  activeNPCName = name
  DebugLog("Active NPC set: " .. tostring(name))
end

function PortraitManager:ClearActiveNPC()
  activeNPCName = nil
end

function PortraitManager:GetNPCInfo()
    local name = activeNPCName or UnitName("npc") or UnitName("target") or "Unknown"
    print(name)
    if !NPC_DATA Then
      return
    end
    local npcData = NPC_DATA[name]
    print(npcData.race)


    return {
        name     = name,
        race     = npcData and npcData.race or "unknown",
        sex      = npcData and npcData.sex or "male",
        portrait = npcData and npcData.portrait or (npcData and npcData.race or "default"),
        zone     = npcData and npcData.zone or GetZoneText() or "Unknown",
        model_id = npcData and npcData.model_id or nil,
    }
end

function PortraitManager:FindNPCPortrait()
  local npc = self:GetNPCInfo()
  if not npc then
    return
  end
  local key = npc.portrait or "default"          -- fallback if nil
  print(npc.name)
  print(npc.race)
  print(npc.sex)

  if key and PORTRAIT_CONFIG.NPC_PORTRAITS[key] then
    return PORTRAIT_CONFIG.NPC_PORTRAITS[key]
  end

  return PORTRAIT_CONFIG.DEFAULT_NPC
end

-------------------------
-- BOOK PORTRAITS
-------------------------

function PortraitManager:FindBookPortrait(itemName)
  if BookDB and BookDB.portraits and itemName then
    if BookDB.portraits[itemName] then
      return BookDB.portraits[itemName]
    end
  end
  return PORTRAIT_CONFIG.DEFAULT_BOOK
end

-------------------------
-- DISPLAY
-------------------------

function PortraitManager:SetPortrait(parentFrame, portraitType, customTexture)
  local portrait = GetOrCreatePortraitFrame(parentFrame)
  if not portrait then return false end

  local texturePath

  if customTexture then
    texturePath = customTexture
  elseif portraitType == self.Type.NPC then
    texturePath = self:FindNPCPortrait()
  elseif portraitType == self.Type.BOOK then
    texturePath = PORTRAIT_CONFIG.DEFAULT_BOOK
  elseif portraitType == self.Type.ITEM then
    texturePath = PORTRAIT_CONFIG.DEFAULT_ITEM
  elseif portraitType == self.Type.OBJECT then
    texturePath = PORTRAIT_CONFIG.DEFAULT_OBJECT
  else
    texturePath = PORTRAIT_CONFIG.DEFAULT_NPC
  end

  portrait.texture:SetTexture(texturePath)

  if not portrait.texture:GetTexture() then
    portrait.texture:SetTexture(PORTRAIT_CONFIG.DEFAULT_NPC)
  end

  portrait:Show()

  currentPortrait.type = portraitType
  currentPortrait.texture = texturePath
  currentPortrait.frame = parentFrame

  DebugLog("Portrait set: " .. portraitType)
  return true
end

function PortraitManager:UpdateNPCPortrait(parentFrame)
  return self:SetPortrait(parentFrame or QuestFrame, self.Type.NPC)
end

function PortraitManager:UpdateBookPortrait(parentFrame, itemName)
  local tex = self:FindBookPortrait(itemName)
  return self:SetPortrait(parentFrame or ItemTextFrame, self.Type.BOOK, tex)
end

function PortraitManager:HidePortrait(parentFrame)
  local f = parentFrame or currentPortrait.frame
  if f and f.widePortrait then
    f.widePortrait:Hide()
  end

  currentPortrait.type = nil
  currentPortrait.texture = nil
  currentPortrait.frame = nil
end

function PortraitManager:GetCurrentPortrait()
  return currentPortrait
end

-------------------------
-- INIT
-------------------------

function PortraitManager:Initialize()
  DebugLog("PortraitManager initialized")
end

PortraitManager:Initialize()
