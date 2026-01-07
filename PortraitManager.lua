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

  DEFAULT_NPC    = "Interface\\CharacterFrame\\TempPortrait",
  DEFAULT_BOOK   = "Interface\\Icons\\INV_Misc_Book_09",
  DEFAULT_ITEM   = "Interface\\Icons\\INV_Misc_QuestionMark",
  DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",
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

  if parentFrame.widePortrait then
    return parentFrame.widePortrait
  end

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
  local name =
    activeNPCName or
    UnitName("npc") or
    UnitName("target") or
    "Unknown"

  local zone = GetZoneText() or "Unknown"
  local race = UnitRace("npc") or UnitRace("target") or "Unknown"
  local sex  = UnitSex("npc") or UnitSex("target") or 2

  return {
    name = name,
    zone = zone,
    race = race,
    sex  = sex,
  }
end

function PortraitManager:FindNPCPortrait()
  if not PortraitDB then
    return PORTRAIT_CONFIG.DEFAULT_NPC, "no db"
  end

  local npc = self:GetNPCInfo()
  if not npc then
    return PortraitDB.default or PORTRAIT_CONFIG.DEFAULT_NPC, "no npc"
  end

  if PortraitDB.named and PortraitDB.named[npc.name] then
    return PortraitDB.named[npc.name], "named"
  end

  if npc.race and PortraitDB.race and PortraitDB.race[npc.race] then
    local r = PortraitDB.race[npc.race]
    if type(r) == "table" then
      if npc.sex == 3 and r.female then
        return r.female, "race/female"
      elseif r.male then
        return r.male, "race/male"
      end
    else
      return r, "race"
    end
  end

  if npc.zone and PortraitDB.zone and PortraitDB.zone[npc.zone] then
    return PortraitDB.zone[npc.zone], "zone"
  end

  return PortraitDB.default or PORTRAIT_CONFIG.DEFAULT_NPC, "default"
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
