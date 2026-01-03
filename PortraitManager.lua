-- PortraitManager.lua
-- Unified portrait system for NPCs, books, and other interactions
-- Manages portrait display across quest dialogs and item text frames

-------------------------
-- PORTRAIT MANAGER
-------------------------

PortraitManager = {}

-- Portrait types
PortraitManager.Type = {
  NPC = "npc",
  BOOK = "book",
  ITEM = "item",
  OBJECT = "object",
  CUSTOM = "custom",
}

-- Current portrait state
local currentPortrait = {
  type = nil,
  texture = nil,
  frame = nil,
}

-------------------------
-- CONFIGURATION
-------------------------

local PORTRAIT_CONFIG = {
  WIDTH = 125,
  HEIGHT = 220,
  OFFSET_X = 15,
  OFFSET_Y = 50,
  
  -- Default textures
  DEFAULT_NPC = "Interface\\CharacterFrame\\TempPortrait",
  DEFAULT_BOOK = "Interface\\Icons\\INV_Misc_Book_09",
  DEFAULT_ITEM = "Interface\\Icons\\INV_Misc_QuestionMark",
  DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",
}

-------------------------
-- UTILITY FUNCTIONS
-------------------------

--- Debug logging
local function DebugLog(msg)
  if PortraitManager.DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. msg)
  end
end

--- Get or create portrait frame on parent
local function GetOrCreatePortraitFrame(parentFrame)
  if not parentFrame then return nil end
  
  local portrait = parentFrame.widePortrait
  
  if not portrait then
    portrait = CreateFrame("Frame", nil, parentFrame)
    portrait:SetWidth(PORTRAIT_CONFIG.WIDTH)
    portrait:SetHeight(PORTRAIT_CONFIG.HEIGHT)
    portrait:SetPoint(
      "TOPLEFT",
      parentFrame,
      "TOPLEFT",
      PORTRAIT_CONFIG.OFFSET_X,
      -PORTRAIT_CONFIG.OFFSET_Y
    )
    
    -- Black background
    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints(portrait)
    portrait.bg:SetTexture(0, 0, 0, 1)
    
    -- Portrait texture layer
    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints(portrait)
    portrait.texture:SetTexCoord(0, 1, 0, 1)
    
    parentFrame.widePortrait = portrait
  end
  
  return portrait
end

-------------------------
-- NPC PORTRAITS
-------------------------

--- Get NPC information
function PortraitManager:GetNPCInfo()
  local name = UnitName("npc") or UnitName("target") or "Unknown"
  local zone = GetZoneText() or "Unknown"
  local race = UnitRace("npc") or UnitRace("target") or "Unknown"
  local sex = UnitSex("npc") or UnitSex("target") or 2
  
  return {
    name = name,
    zone = zone,
    race = race,
    sex = sex,
  }
end

--- Find NPC portrait texture
function PortraitManager:FindNPCPortrait()
  if not PortraitDB then
    return PORTRAIT_CONFIG.DEFAULT_NPC, "no database"
  end
  
  local npc = self:GetNPCInfo()
  if not npc then
    return PortraitDB.default or PORTRAIT_CONFIG.DEFAULT_NPC, "no npc"
  end
  
  -- Named NPC lookup
  if PortraitDB.named[npc.name] then
    return PortraitDB.named[npc.name], "named: " .. npc.name
  end
  
  -- Race-based with sex
  if npc.race and PortraitDB.race[npc.race] then
    local raceEntry = PortraitDB.race[npc.race]
    if raceEntry.male and raceEntry.female then
      if npc.sex == 3 then
        return raceEntry.female, "race/female: " .. npc.race
      else
        return raceEntry.male, "race/male: " .. npc.race
      end
    else
      return raceEntry, "race: " .. npc.race
    end
  end
  
  -- Zone-based
  if npc.zone and PortraitDB.zone[npc.zone] then
    return PortraitDB.zone[npc.zone], "zone: " .. npc.zone
  end
  
  -- Default
  return PortraitDB.default or PORTRAIT_CONFIG.DEFAULT_NPC, "default"
end

-------------------------
-- BOOK PORTRAITS
-------------------------

--- Find book/narrator portrait texture
function PortraitManager:FindBookPortrait(itemName)
  -- Check for custom book portraits in BookDB
  if BookDB and BookDB.portraits and itemName then
    local customPortrait = BookDB.portraits[itemName]
    if customPortrait then
      return customPortrait, "custom book"
    end
  end
  
  -- Try narrator portrait
  local narratorPath = "Interface\\AddOns\\BetterQuestText\\portraits\\books\\narrator.tga"
  
  -- Default book icon as fallback
  return PORTRAIT_CONFIG.DEFAULT_BOOK, "default book"
end

-------------------------
-- PORTRAIT DISPLAY
-------------------------

--- Set portrait texture
function PortraitManager:SetPortrait(parentFrame, portraitType, customTexture)
  local portrait = GetOrCreatePortraitFrame(parentFrame)
  if not portrait then return false end
  
  local texturePath, source
  
  -- Determine texture based on type
  if customTexture then
    texturePath = customTexture
    source = "custom"
  elseif portraitType == self.Type.NPC then
    texturePath, source = self:FindNPCPortrait()
  elseif portraitType == self.Type.BOOK then
    texturePath, source = self:FindBookPortrait()
  elseif portraitType == self.Type.ITEM then
    texturePath = PORTRAIT_CONFIG.DEFAULT_ITEM
    source = "default item"
  elseif portraitType == self.Type.OBJECT then
    texturePath = PORTRAIT_CONFIG.DEFAULT_OBJECT
    source = "default object"
  else
    texturePath = PORTRAIT_CONFIG.DEFAULT_NPC
    source = "default"
  end
  
  -- Apply texture
  portrait.texture:SetTexture(texturePath)
  
  -- Fallback if texture fails
  if not portrait.texture:GetTexture() then
    if portraitType == self.Type.BOOK then
      portrait.texture:SetTexture(PORTRAIT_CONFIG.DEFAULT_BOOK)
    else
      portrait.texture:SetTexture(PORTRAIT_CONFIG.DEFAULT_NPC)
    end
    source = source .. " (fallback)"
  end
  
  -- Update state
  currentPortrait.type = portraitType
  currentPortrait.texture = texturePath
  currentPortrait.frame = portrait
  
  portrait:Show()
  
  DebugLog("Set portrait: " .. portraitType .. " (" .. source .. ")")
  
  return true
end

--- Update NPC portrait
function PortraitManager:UpdateNPCPortrait(parentFrame)
  return self:SetPortrait(parentFrame or QuestFrame, self.Type.NPC)
end

--- Update book portrait
function PortraitManager:UpdateBookPortrait(parentFrame, itemName)
  local customTexture = nil
  
  if itemName then
    customTexture = self:FindBookPortrait(itemName)
  end
  
  return self:SetPortrait(parentFrame or ItemTextFrame, self.Type.BOOK, customTexture)
end

--- Hide portrait
function PortraitManager:HidePortrait(parentFrame)
  local frame = parentFrame or currentPortrait.frame
  
  if frame and frame.widePortrait then
    frame.widePortrait:Hide()
    DebugLog("Portrait hidden")
  end
  
  currentPortrait.type = nil
  currentPortrait.texture = nil
  currentPortrait.frame = nil
end

--- Get current portrait info
function PortraitManager:GetCurrentPortrait()
  return currentPortrait
end

-------------------------
-- INITIALIZATION
-------------------------

function PortraitManager:Initialize()
  DebugLog("Portrait Manager initialized")
end

-- Auto-initialize
PortraitManager:Initialize()