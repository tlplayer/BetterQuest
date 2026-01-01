-- BetterQuestText.lua
-- pfUI-aware wide quest layout for WoW 1.12.1
-- With working texture-based portraits

-------------------------
-- CONFIG
-------------------------
local CONFIG = {
  -- Frame dimensions
  WIDTH = 620,
  HEIGHT = 400,
  
  -- Frame position
  POS_X = 0,
  POS_Y = -60,
  
  -- Content margins
  MARGIN_LEFT = 140,  -- Increased to make room for portrait
  MARGIN_RIGHT = 50,
  MARGIN_TOP = 50,

  -- Text Margins
  TEXT_MARGIN_LEFT = 140,
  TEXT_MARGIN_RIGHT = 90,
  TEXT_MARGIN_TOP = 55,
  
  -- Scroll heights
  HEIGHT_DETAIL_SCROLL = 220,
  HEIGHT_PROGRESS_SCROLL = 220,
  HEIGHT_REWARD_SCROLL = 200,
  
  -- Button offsets
  BUTTON_OFFSET_X = 20,
  BUTTON_OFFSET_Y = 20,
  
  -- Close button
  CLOSE_OFFSET_X = 8,
  CLOSE_OFFSET_Y = 8,
  
  -- Scrollbar
  SCROLLBAR_OFFSET_X = 16,
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
}

local WIDE_TEXT_CONFIG = {
  -- Shared frame size
  FRAME_WIDTH = 620,
  FRAME_HEIGHT = 350,

  -- Text Padding
  TEXT_RIGHT_PADDING = -20,

  -- Screen position
  ANCHOR_POINT = "CENTER",
  ANCHOR_RELATIVE = "CENTER",
  OFFSET_X = 0,
  OFFSET_Y = -250,

  -- Content margins
  CONTENT_MARGIN_LEFT = 15,
  CONTENT_MARGIN_RIGHT = 20,
  CONTENT_MARGIN_TOP = 30,
  CONTENT_MARGIN_BOTTOM = 30,

  -- Scrollbar spacing
  SCROLLBAR_OFFSET_X = 16,
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
}

-------------------------
-- Portrait System
-------------------------
local PORTRAIT_CONFIG = {
  WIDTH = 110,
  HEIGHT = 110,
  OFFSET_X = 15,  -- Distance from left edge
  OFFSET_Y = 60,  -- Distance from top
}

-- Portrait Database - maps NPC names to texture paths
-- You'll need to place portrait images in Interface/AddOns/YourAddonName/portraits/
local PortraitDB = {
  -- Named NPCs (use texture paths relative to WoW interface folder)
  named = {
    ["Thrall"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\thrall",
    ["Cairne Bloodhoof"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\cairne",
    ["Vol'jin"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\voljin",
    ["King Magni Bronzebeard"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\magni",
    ["Lady Sylvanas Windrunner"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\sylvanas",
    ["Highlord Bolvar Fordragon"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\bolvar",
    ["Tyrande Whisperwind"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\tyrande",
  },
  
  -- Zone-based portraits (guards, citizens)
  zone = {
    ["Orgrimmar"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\orc_generic",
    ["Stormwind City"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\human_generic",
    ["Ironforge"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\dwarf_generic",
    ["Darnassus"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\nightelf_generic",
    ["Thunder Bluff"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\tauren_generic",
    ["Undercity"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\undead_generic",
  },
  
  -- Race-based fallbacks
  race = {
    ["Human"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\human_generic",
    ["Orc"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\orc_generic",
    ["Dwarf"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\dwarf_generic",
    ["Night Elf"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\nightelf_generic",
    ["Undead"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\undead_generic",
    ["Tauren"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\tauren_generic",
    ["Gnome"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\gnome_generic",
    ["Troll"] = "Interface\\AddOns\\BetterQuestTest\\portraits\\troll_generic",
  },
  
  -- Default fallback
  default = "Interface\\AddOns\\BetterQuestTest\\portraits\\default",
}

-- Get NPC information
local function GetNPCInfo()
  return {
    name = UnitName("npc") or UnitName("target") or "Unknown",
    zone = GetZoneText(),
    race = UnitRace("npc") or UnitRace("target"),
  }
end

-- Find the appropriate portrait texture
local function FindPortraitTexture()
  local npc = GetNPCInfo()
  local texture = nil
  
  -- 1. Try named NPC lookup (most specific)
  if npc.name and PortraitDB.named[npc.name] then
    texture = PortraitDB.named[npc.name]
    return texture, "named: " .. npc.name
  end
  
  -- 2. Try zone-based lookup
  if npc.zone and PortraitDB.zone[npc.zone] then
    texture = PortraitDB.zone[npc.zone]
    return texture, "zone: " .. npc.zone
  end
  
  -- 3. Try race-based lookup
  if npc.race and PortraitDB.race[npc.race] then
    texture = PortraitDB.race[npc.race]
    return texture, "race: " .. npc.race
  end
  
  -- 4. Use default
  return PortraitDB.default, "default"
end

-- Create or update portrait frame
local function UpdatePortrait(parentFrame)
  if not parentFrame then return end
  
  local portrait = parentFrame.widePortrait
  
  -- Create portrait frame if it doesn't exist
  if not portrait then
    portrait = CreateFrame("Frame", nil, parentFrame)
    portrait:SetWidth(PORTRAIT_CONFIG.WIDTH)
    portrait:SetHeight(PORTRAIT_CONFIG.HEIGHT)
    portrait:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", PORTRAIT_CONFIG.OFFSET_X, -PORTRAIT_CONFIG.OFFSET_Y)
    
    -- Create texture
    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints(portrait)
    
    -- Create border (optional)
    portrait.border = portrait:CreateTexture(nil, "OVERLAY")
    portrait.border:SetAllPoints(portrait)
    portrait.border:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Border")
    portrait.border:SetTexCoord(0, 0.8, 0, 0.8)
    
    parentFrame.widePortrait = portrait
  end
  
  -- Update texture to current NPC
  local texturePath, source = FindPortraitTexture()
  portrait.texture:SetTexture(texturePath)

  print(texturePath,source)
  
  -- If texture fails to load, use a fallback
  if not portrait.texture:GetTexture() then
    portrait.texture:SetTexture("Interface\\CharacterFrame\\TempPortrait")
  end
  
  portrait:Show()
  
  -- Debug output (optional)
  -- DEFAULT_CHAT_FRAME:AddMessage("Portrait: " .. source)
end

-- Helper: Add portrait to database dynamically
function PortraitDB_AddNPC(npcName, texturePath)
  if not npcName or not texturePath then return false end
  PortraitDB.named[npcName] = texturePath
  return true
end

-------------------------
-- Get Backdrop
-------------------------
local function GetBackdrop()
  return QuestFrame.backdrop or QuestFrame
end

-------------------------
-- Apply Layout
-------------------------
local function ApplyLayout()
  if not QuestFrame then return end
  
  local backdrop = GetBackdrop()
  
  -- Size and position frame
  QuestFrame:SetWidth(CONFIG.WIDTH)
  QuestFrame:SetHeight(CONFIG.HEIGHT)
  QuestFrame:ClearAllPoints()
  QuestFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", CONFIG.POS_X, CONFIG.POS_Y)
  
  -- Update portrait
  UpdatePortrait(QuestFrame)
  
  -- Content width (accounting for portrait space)
  local contentWidth = CONFIG.WIDTH - CONFIG.MARGIN_LEFT - CONFIG.MARGIN_RIGHT
  
  ------------------------------------------------
  -- Detail Scroll
  ------------------------------------------------
  if QuestDetailScrollFrame then
    QuestDetailScrollFrame:ClearAllPoints()
    QuestDetailScrollFrame:SetPoint("TOPLEFT", QuestFrame, "TOPLEFT", CONFIG.MARGIN_LEFT, -CONFIG.MARGIN_TOP)
    QuestDetailScrollFrame:SetWidth(contentWidth)
    QuestDetailScrollFrame:SetHeight(CONFIG.HEIGHT_DETAIL_SCROLL)
    
    if QuestDetailScrollChildFrame then
      QuestDetailScrollChildFrame:SetWidth(contentWidth)
    end
    
    if QuestDetailScrollFrameScrollBar then
      QuestDetailScrollFrameScrollBar:ClearAllPoints()
      QuestDetailScrollFrameScrollBar:SetPoint("TOPRIGHT", QuestDetailScrollFrame, "TOPRIGHT", CONFIG.SCROLLBAR_OFFSET_X, -CONFIG.SCROLLBAR_OFFSET_TOP)
      QuestDetailScrollFrameScrollBar:SetPoint("BOTTOMRIGHT", QuestDetailScrollFrame, "BOTTOMRIGHT", CONFIG.SCROLLBAR_OFFSET_X, CONFIG.SCROLLBAR_OFFSET_BOTTOM)
    end
  end
  
  ------------------------------------------------
  -- Progress Scroll
  ------------------------------------------------
  if QuestProgressScrollFrame then
    QuestProgressScrollFrame:ClearAllPoints()
    QuestProgressScrollFrame:SetPoint("TOPLEFT", QuestFrame, "TOPLEFT", CONFIG.MARGIN_LEFT, -CONFIG.MARGIN_TOP)
    QuestProgressScrollFrame:SetWidth(contentWidth)
    QuestProgressScrollFrame:SetHeight(CONFIG.HEIGHT_PROGRESS_SCROLL)
    
    if QuestProgressScrollChildFrame then
      QuestProgressScrollChildFrame:SetWidth(contentWidth)
    end
    
    if QuestProgressScrollFrameScrollBar then
      QuestProgressScrollFrameScrollBar:ClearAllPoints()
      QuestProgressScrollFrameScrollBar:SetPoint("TOPRIGHT", QuestProgressScrollFrame, "TOPRIGHT", CONFIG.SCROLLBAR_OFFSET_X, -CONFIG.SCROLLBAR_OFFSET_TOP)
      QuestProgressScrollFrameScrollBar:SetPoint("BOTTOMRIGHT", QuestProgressScrollFrame, "BOTTOMRIGHT", CONFIG.SCROLLBAR_OFFSET_X, CONFIG.SCROLLBAR_OFFSET_BOTTOM)
    end
  end
  
  ------------------------------------------------
  -- Reward Scroll  
  ------------------------------------------------
  if QuestRewardScrollFrame then
    QuestRewardScrollFrame:ClearAllPoints()
    QuestRewardScrollFrame:SetPoint("TOPLEFT", QuestFrame, "TOPLEFT", CONFIG.MARGIN_LEFT, -CONFIG.MARGIN_TOP)
    QuestRewardScrollFrame:SetWidth(contentWidth)
    QuestRewardScrollFrame:SetHeight(CONFIG.HEIGHT_REWARD_SCROLL)
    
    if QuestRewardScrollChildFrame then
      QuestRewardScrollChildFrame:SetWidth(contentWidth)
    end
    
    if QuestRewardScrollFrameScrollBar then
      QuestRewardScrollFrameScrollBar:ClearAllPoints()
      QuestRewardScrollFrameScrollBar:SetPoint("TOPRIGHT", QuestRewardScrollFrame, "TOPRIGHT", CONFIG.SCROLLBAR_OFFSET_X, -CONFIG.SCROLLBAR_OFFSET_TOP)
      QuestRewardScrollFrameScrollBar:SetPoint("BOTTOMRIGHT", QuestRewardScrollFrame, "BOTTOMRIGHT", CONFIG.SCROLLBAR_OFFSET_X, CONFIG.SCROLLBAR_OFFSET_BOTTOM)
    end
  end
  
  ------------------------------------------------
  -- Buttons
  ------------------------------------------------
  
  -- Accept button (LEFT)
  if QuestFrameAcceptButton then
    QuestFrameAcceptButton:ClearAllPoints()
    QuestFrameAcceptButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  -- Complete button (LEFT)
  if QuestFrameCompleteButton then
    QuestFrameCompleteButton:ClearAllPoints()
    QuestFrameCompleteButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  -- Decline button (RIGHT)
  if QuestFrameDeclineButton then
    QuestFrameDeclineButton:ClearAllPoints()
    QuestFrameDeclineButton:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  -- Goodbye/Cancel button (RIGHT)
  if QuestFrameGoodbyeButton then
    QuestFrameGoodbyeButton:ClearAllPoints()
    QuestFrameGoodbyeButton:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  ------------------------------------------------
  -- Close Button
  ------------------------------------------------
  if QuestFrameCloseButton then
    QuestFrameCloseButton:ClearAllPoints()
    QuestFrameCloseButton:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -CONFIG.CLOSE_OFFSET_X, -CONFIG.CLOSE_OFFSET_Y)
  end
end

-------------------------
-- Fix Text Widths
-------------------------
local function FixTextWidths()
  local textWidth = CONFIG.WIDTH - CONFIG.MARGIN_LEFT - CONFIG.MARGIN_RIGHT - 10
  
  local texts = {
    QuestTitleText,
    QuestDescription,
    QuestObjectiveText,
    QuestProgressText,
    QuestRewardText,
    QuestRewardItemChooseText,
  }
  
  for _, text in pairs(texts) do
    if text then
      text:SetWidth(textWidth)
      text:SetJustifyH("LEFT")
    end
  end
  
  for i = 1, 10 do
    local obj = getglobal("QuestObjectiveText" .. i)
    if obj then
      obj:SetWidth(textWidth)
      obj:SetJustifyH("LEFT")
    end
  end
end

-------------------------
-- Hooks
-------------------------
local originalOnShow = QuestFrame:GetScript("OnShow")
QuestFrame:SetScript("OnShow", function()
  if originalOnShow then originalOnShow() end
  ApplyLayout()
  this:SetScript("OnUpdate", function()
    FixTextWidths()
    this:SetScript("OnUpdate", nil)
  end)
end)

-------------------------
-- Events
-------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_GREETING")
f:SetScript("OnEvent", function()
  this:SetScript("OnUpdate", function()
    ApplyLayout()
    FixTextWidths()
    this:SetScript("OnUpdate", nil)
  end)
end)

-------------------------
-- Utility
-------------------------
local function GetVisualBackdrop(frame, inset)
  if frame and frame.backdrop then
    return frame.backdrop
  end
  if inset then
    return inset
  end
  return frame
end

local function ApplyScrollbarLayout(scrollFrame, scrollBar)
  if not scrollFrame or not scrollBar then return end

  scrollBar:ClearAllPoints()
  scrollBar:SetPoint(
    "TOPRIGHT",
    scrollFrame,
    "TOPRIGHT",
    WIDE_TEXT_CONFIG.SCROLLBAR_OFFSET_X,
    -WIDE_TEXT_CONFIG.SCROLLBAR_OFFSET_TOP
  )
  scrollBar:SetPoint(
    "BOTTOMRIGHT",
    scrollFrame,
    "BOTTOMRIGHT",
    WIDE_TEXT_CONFIG.SCROLLBAR_OFFSET_X,
    WIDE_TEXT_CONFIG.SCROLLBAR_OFFSET_BOTTOM
  )
end

-------------------------------------------------
-- ItemTextFrame (Books, Notes, Letters)
-------------------------------------------------
local function ApplyItemTextLayout()
  if not ItemTextFrame then return end

  local backdrop = GetVisualBackdrop(ItemTextFrame, ItemTextFrameInset)
  if not backdrop then return end

  ItemTextFrame:SetWidth(WIDE_TEXT_CONFIG.FRAME_WIDTH)
  ItemTextFrame:SetHeight(WIDE_TEXT_CONFIG.FRAME_HEIGHT)
  ItemTextFrame:ClearAllPoints()
  ItemTextFrame:SetPoint(
    WIDE_TEXT_CONFIG.ANCHOR_POINT,
    UIParent,
    WIDE_TEXT_CONFIG.ANCHOR_RELATIVE,
    WIDE_TEXT_CONFIG.OFFSET_X,
    WIDE_TEXT_CONFIG.OFFSET_Y
  )

  local contentWidth =
    backdrop:GetWidth()
    - WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT
    - WIDE_TEXT_CONFIG.CONTENT_MARGIN_RIGHT

  local contentHeight =
    backdrop:GetHeight()
    - WIDE_TEXT_CONFIG.CONTENT_MARGIN_TOP
    - WIDE_TEXT_CONFIG.CONTENT_MARGIN_BOTTOM

  if ItemTextScrollFrame then
    ItemTextScrollFrame:ClearAllPoints()
    ItemTextScrollFrame:SetPoint(
      "TOPLEFT",
      backdrop,
      "TOPLEFT",
      WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT,
      -WIDE_TEXT_CONFIG.CONTENT_MARGIN_TOP
    )
    ItemTextScrollFrame:SetWidth(contentWidth)
    ItemTextScrollFrame:SetHeight(contentHeight)

    ApplyScrollbarLayout(
      ItemTextScrollFrame,
      ItemTextScrollFrameScrollBar
    )
  end

  if ItemTextPageText then
    ItemTextPageText:SetWidth(contentWidth + WIDE_TEXT_CONFIG.TEXT_RIGHT_PADDING)
    ItemTextPageText:SetJustifyH("LEFT")
  end
end

-------------------------------------------------
-- GossipFrame (NPC dialogue text)
-------------------------------------------------
local OriginalGossipResize = GossipResize

function GossipResize(titleButton)
  if not titleButton then return end
  
  local contentWidth = WIDE_TEXT_CONFIG.FRAME_WIDTH - WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT - WIDE_TEXT_CONFIG.CONTENT_MARGIN_RIGHT
  
  titleButton:SetHeight(titleButton:GetTextHeight() + 2)
  titleButton:SetWidth(contentWidth)
  
  local buttonText = getglobal(titleButton:GetName() .. "Text")
  if buttonText then
    buttonText:ClearAllPoints()
    buttonText:SetPoint("LEFT", titleButton, "LEFT", 25, 0)
    buttonText:SetWidth(contentWidth - 30)
    buttonText:SetJustifyH("LEFT")
  end
  
  local buttonIcon = getglobal(titleButton:GetName() .. "GossipIcon")
  if buttonIcon then
    buttonIcon:ClearAllPoints()
    buttonIcon:SetPoint("LEFT", titleButton, "LEFT", 3, 0)
  end
end

local function ApplyGossipLayout()
  if not GossipFrame then return end

  local backdrop = GetVisualBackdrop(GossipFrame, GossipFrameInset)
  if not backdrop then backdrop = GossipFrame end

  GossipFrame:SetWidth(WIDE_TEXT_CONFIG.FRAME_WIDTH)
  GossipFrame:SetHeight(WIDE_TEXT_CONFIG.FRAME_HEIGHT)
  GossipFrame:ClearAllPoints()
  GossipFrame:SetPoint(
    WIDE_TEXT_CONFIG.ANCHOR_POINT,
    UIParent,
    WIDE_TEXT_CONFIG.ANCHOR_RELATIVE,
    WIDE_TEXT_CONFIG.OFFSET_X,
    WIDE_TEXT_CONFIG.OFFSET_Y
  )

  local contentWidth = WIDE_TEXT_CONFIG.FRAME_WIDTH - WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT - WIDE_TEXT_CONFIG.CONTENT_MARGIN_RIGHT - 40
  local contentHeight = WIDE_TEXT_CONFIG.FRAME_HEIGHT - WIDE_TEXT_CONFIG.CONTENT_MARGIN_TOP - WIDE_TEXT_CONFIG.CONTENT_MARGIN_BOTTOM - 90

  if GossipGreetingScrollFrame then
    GossipGreetingScrollFrame:ClearAllPoints()
    GossipGreetingScrollFrame:SetPoint(
      "TOPLEFT",
      backdrop,
      "TOPLEFT",
      WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT,
      -WIDE_TEXT_CONFIG.CONTENT_MARGIN_TOP
    )
    GossipGreetingScrollFrame:SetWidth(contentWidth)
    GossipGreetingScrollFrame:SetHeight(contentHeight)
    GossipGreetingScrollFrame:EnableMouse(true)
    
    if GossipGreetingScrollFrameScrollBar then
      ApplyScrollbarLayout(GossipGreetingScrollFrame, GossipGreetingScrollFrameScrollBar)
    end
  end

  if GossipGreetingScrollChildFrame then
    GossipGreetingScrollChildFrame:SetWidth(contentWidth)
    GossipGreetingScrollChildFrame:EnableMouse(true)
  end
end

local OriginalGossipFrameUpdate = GossipFrameUpdate
local gossipUpdateFrame = CreateFrame("Frame")

function GossipFrameUpdate()
  if OriginalGossipFrameUpdate then
    OriginalGossipFrameUpdate()
  end

  gossipUpdateFrame:SetScript("OnUpdate", function()
    ApplyGossipLayout()
    this:SetScript("OnUpdate", nil)
  end)
end

-------------------------
-- Event Handling
-------------------------
local gossipEventFrame = CreateFrame("Frame")
gossipEventFrame:RegisterEvent("GOSSIP_SHOW")
gossipEventFrame:SetScript("OnEvent", function()
  if event == "GOSSIP_SHOW" then
    this:SetScript("OnUpdate", function()
      ApplyGossipLayout()
      this:SetScript("OnUpdate", nil)
    end)
  end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ITEM_TEXT_BEGIN")
eventFrame:RegisterEvent("ITEM_TEXT_READY")
eventFrame:RegisterEvent("GOSSIP_SHOW")

eventFrame:SetScript("OnEvent", function()
  this:SetScript("OnUpdate", function()
    ApplyItemTextLayout()
    ApplyGossipLayout()
    this:SetScript("OnUpdate", nil)
  end)
end)

-------------------------
-- OnShow Hooks
-------------------------
if ItemTextFrame then
  local originalItemTextOnShow = ItemTextFrame:GetScript("OnShow")
  ItemTextFrame:SetScript("OnShow", function()
    if originalItemTextOnShow then originalItemTextOnShow() end
    ApplyItemTextLayout()
  end)
end

if GossipFrame then
  local originalGossipOnShow = GossipFrame:GetScript("OnShow")
  GossipFrame:SetScript("OnShow", function()
    if originalGossipOnShow then originalGossipOnShow() end
    ApplyGossipLayout()
  end)
end

-------------------------
-- Init
-------------------------
local function Init()
  local timer = 0
  local initFrame = CreateFrame("Frame")
  initFrame:SetScript("OnUpdate", function()
    timer = timer + arg1
    if timer > 0.5 then
      ApplyLayout()
      FixTextWidths()
      this:SetScript("OnUpdate", nil)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBetterQuestTest|r loaded with portrait support")
    end
  end)
end

Init()