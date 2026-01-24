-- PortraitManager.lua
-- Unified portrait system for NPCs, books, and other interactions
-- WoW 1.12.1 compatible
-- Now uses NPC_DATABASE format

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
  
  -- Portrait base path
  PORTRAIT_PATH = "Interface\\AddOns\\BetterQuest\\portraits\\",
}

-------------------------
-- UTIL
-------------------------
local function DebugLog(msg)
  if PortraitManager.DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. msg)
  end
end

local function NormalizeNPCName(name)
  if not name then return nil end
  name = string.gsub(name, "['']", "")
  return name
end

local function BuildPortraitPath(race, sex)
  -- Convention: portraits/race.tga or portraits/race_female.tga
  if not race or race == "" then
    return PORTRAIT_CONFIG.DEFAULT_NPC
  end
  
  local filename
  if sex == "female" then
    filename = race .. "_female.tga"
  else
    filename = race .. ".tga"
  end
  
  return PORTRAIT_CONFIG.PORTRAIT_PATH .. filename
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
  local normalizedName = NormalizeNPCName(name)
  
  -- Use GetNPCMetadata from the unified database
  local metadata = GetNPCMetadata and GetNPCMetadata(normalizedName)
  
  if not metadata then
    DebugLog("No metadata found for: " .. tostring(name))
    return nil
  end
  
  return {
    name     = normalizedName,
    race     = metadata.race or "unknown",
    sex      = metadata.sex or "male",
    portrait = metadata.portrait or metadata.race or "default",
    zone     = metadata.zone or GetZoneText() or "Unknown",
    model_id = metadata.model_id,
    narrator = metadata.narrator or "default",
  }
end

function PortraitManager:FindNPCPortrait()
  local npc = self:GetNPCInfo()
  if not npc then
    DebugLog("No NPC info available, using default")
    return PORTRAIT_CONFIG.DEFAULT_NPC
  end
  
  -- Build path using convention: race.tga or race_female.tga
  if npc.race and npc.race ~= "" then
    local path = BuildPortraitPath(npc.race, npc.sex)
    DebugLog("Using portrait: " .. path)
    return path
  end
  
  DebugLog("No race found, using default")
  return PORTRAIT_CONFIG.DEFAULT_NPC
end

function PortraitManager:FindNPCPortraitByKey(key)
  if not key or key == "" then
    return PORTRAIT_CONFIG.DEFAULT_NPC
  end
  
  -- Simple convention: key.tga
  return PORTRAIT_CONFIG.PORTRAIT_PATH .. key .. ".tga"
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
  
  -- Validate texture path
  if not texturePath or texturePath == "" then
    DebugLog("Invalid texture path, using default")
    texturePath = PORTRAIT_CONFIG.DEFAULT_NPC
  end
  
  -- Set texture
  portrait.texture:SetTexture(texturePath)
  
  -- Show portrait with error handling
  local success, err = pcall(function()
    portrait:Show()
  end)
  
  if not success then
    DebugLog("ERROR showing portrait: " .. tostring(err))
    return false
  end
  
  currentPortrait.type = portraitType
  currentPortrait.texture = texturePath
  currentPortrait.frame = parentFrame
  
  DebugLog("Portrait set: " .. texturePath)
  
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
  
  -- Verify NPC_DATABASE is available
  if not NPC_DATABASE then
    print("|cffff0000[PortraitManager]|r WARNING: NPC_DATABASE not loaded!")
  else
    DebugLog("NPC_DATABASE loaded successfully")
  end
end

PortraitManager:Initialize()