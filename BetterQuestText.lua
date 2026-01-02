-- BetterQuestText.lua
-- Wide quest frame with NPC portraits for WoW 1.12.1
-- pfUI-aware layout
--
-- File Structure:
--   BetterQuestText/
--   ├── BetterQuestText.lua (this file)
--   ├── BetterQuestText.toc
--   ├── db/
--   │   └── portraitdb.lua
--   └── portraits/
--       ├── npcs/
--       ├── books/
--       └── notes/

-------------------------
-- CONFIGURATION
-------------------------

-- Quest frame dimensions and positioning
local QUEST_CONFIG = {
  WIDTH = 620,
  HEIGHT = 400,
  POS_X = 0,
  POS_Y = -60,
  
  MARGIN_LEFT = 140,
  MARGIN_RIGHT = 50,
  MARGIN_TOP = 50,
  
  SCROLL_HEIGHT_DETAIL = 220,
  SCROLL_HEIGHT_PROGRESS = 220,
  SCROLL_HEIGHT_REWARD = 200,
  
  BUTTON_OFFSET_X = 20,
  BUTTON_OFFSET_Y = 20,
  
  CLOSE_OFFSET_X = 8,
  CLOSE_OFFSET_Y = 8,
  
  SCROLLBAR_OFFSET_X = 16,
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
}

-- Portrait display configuration
local PORTRAIT_CONFIG = {
  WIDTH = 125,
  HEIGHT = 220,
  OFFSET_X = 15,
  OFFSET_Y = 50,
}

-- Wide text frames (gossip, books, notes)
local TEXT_CONFIG = {
  FRAME_WIDTH = 620,
  FRAME_HEIGHT = 350,
  
  ANCHOR_POINT = "CENTER",
  ANCHOR_RELATIVE = "CENTER",
  OFFSET_X = 0,
  OFFSET_Y = -250,
  
  MARGIN_LEFT = 15,
  MARGIN_RIGHT = 30,
  MARGIN_TOP = 30,
  MARGIN_BOTTOM = 30,
  
  TEXT_RIGHT_PADDING = -100,
  
  SCROLLBAR_OFFSET_X = 16,
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
}

-------------------------
-- PORTRAIT SYSTEM
-------------------------

--- Get current NPC information
-- @return table {name, zone, race} or nil if no NPC available
local function GetNPCInfo()
  local name = UnitName("npc") or UnitName("target") or "Unknown"
  local zone = GetZoneText() or "Unknown"
  local race,raceEn = UnitRace("npc") or UnitRace("target") or "Unknown"
  local sex = UnitSex("npc") or UnitSex("target") or 2  -- default male

  -- Debug log
  DEFAULT_CHAT_FRAME:AddMessage(
    string.format(
      "|cff33ffccGetNPCInfo|r -> Name: %s | Zone: %s | Race: %s | Sex: %s",
      name,
      zone,
      race,
      (sex == 2 and "Male" or sex == 3 and "Female" or "Unknown")
    )
  )

  return {
    name = name,
    zone = zone,
    race = race,
    sex = sex,
  }
end

--- Find appropriate portrait texture for current NPC
-- Lookup hierarchy: named NPC -> zone -> race -> default
-- @return string texture path
-- @return string source description for debugging
local function FindPortraitTexture()
  if not PortraitDB then 
    return "Interface\\CharacterFrame\\TempPortrait", "no database" 
  end
  
  local npc = GetNPCInfo()
  if not npc then
    return PortraitDB.default, "no npc"
  end
  
  -- Priority 1: Named NPC
  if PortraitDB.named[npc.name] then
    return PortraitDB.named[npc.name], "named: " .. npc.name
  end
  
    -- Priority 2: Race-based with sex
  if npc.race and PortraitDB.race[npc.race] then
    local raceEntry = PortraitDB.race[npc.race]
    if raceEntry.male and raceEntry.female then
      if npc.sex == 3 then         -- female
        return raceEntry.female, "race/female: " .. npc.race
      else                        -- default male
        return raceEntry.male, "race/male: " .. npc.race
      end
    else
      return raceEntry, "race: " .. npc.race
    end
  end

  -- Priority 3: Zone-based
  if npc.zone and PortraitDB.zone[npc.zone] then
    return PortraitDB.zone[npc.zone], "zone: " .. npc.zone
  end

  
  -- Priority 4: Default fallback
  return PortraitDB.default, "default"
end


--- Create or update portrait frame on quest dialog
-- @param parentFrame Frame to attach portrait to (typically QuestFrame)
local function UpdatePortrait(parentFrame)
  if not parentFrame then return end
  
  local portrait = parentFrame.widePortrait
  
  -- Create portrait frame on first call
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
    
    -- Portrait texture
    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints(portrait)
    portrait.texture:SetTexCoord(0, 1, 0, 1)
    
    parentFrame.widePortrait = portrait
  end
  
  -- Update to current NPC portrait
  local texturePath, source = FindPortraitTexture()
  portrait.texture:SetTexture(texturePath)
  
  -- Fallback if texture fails to load
  if not portrait.texture:GetTexture() then
    portrait.texture:SetTexture("Interface\\CharacterFrame\\TempPortrait")
  end
  
  portrait:Show()
end

-------------------------
-- QUEST FRAME LAYOUT
-------------------------

--- Get backdrop frame (pfUI compatibility)
-- @return Frame backdrop or QuestFrame
local function GetBackdrop()
  return QuestFrame.backdrop or QuestFrame
end

--- Apply wide layout to quest frame
-- Repositions all scroll frames, buttons, and portrait
local function ApplyQuestLayout()
  if not QuestFrame then return end
  
  local backdrop = GetBackdrop()
  
  -- Set frame size and position
  QuestFrame:SetWidth(QUEST_CONFIG.WIDTH)
  QuestFrame:SetHeight(QUEST_CONFIG.HEIGHT)
  QuestFrame:ClearAllPoints()
  QuestFrame:SetPoint(
    "BOTTOM", 
    UIParent, 
    "BOTTOM", 
    QUEST_CONFIG.POS_X, 
    QUEST_CONFIG.POS_Y
  )
  
  -- Update portrait for current NPC
  UpdatePortrait(QuestFrame)
  
  -- Calculate content width (accounting for portrait)
  local contentWidth = QUEST_CONFIG.WIDTH - QUEST_CONFIG.MARGIN_LEFT - QUEST_CONFIG.MARGIN_RIGHT
  
  -- Quest Detail (initial quest offer)
  if QuestDetailScrollFrame then
    QuestDetailScrollFrame:ClearAllPoints()
    QuestDetailScrollFrame:SetPoint(
      "TOPLEFT", 
      QuestFrame, 
      "TOPLEFT", 
      QUEST_CONFIG.MARGIN_LEFT, 
      -QUEST_CONFIG.MARGIN_TOP
    )
    QuestDetailScrollFrame:SetWidth(contentWidth)
    QuestDetailScrollFrame:SetHeight(QUEST_CONFIG.SCROLL_HEIGHT_DETAIL)
    
    if QuestDetailScrollChildFrame then
      QuestDetailScrollChildFrame:SetWidth(contentWidth)
    end
    
    if QuestDetailScrollFrameScrollBar then
      QuestDetailScrollFrameScrollBar:ClearAllPoints()
      QuestDetailScrollFrameScrollBar:SetPoint(
        "TOPRIGHT", 
        QuestDetailScrollFrame, 
        "TOPRIGHT", 
        QUEST_CONFIG.SCROLLBAR_OFFSET_X, 
        -QUEST_CONFIG.SCROLLBAR_OFFSET_TOP
      )
      QuestDetailScrollFrameScrollBar:SetPoint(
        "BOTTOMRIGHT", 
        QuestDetailScrollFrame, 
        "BOTTOMRIGHT", 
        QUEST_CONFIG.SCROLLBAR_OFFSET_X, 
        QUEST_CONFIG.SCROLLBAR_OFFSET_BOTTOM
      )
    end
  end
  
  -- Quest Progress (turn-in check)
  if QuestProgressScrollFrame then
    QuestProgressScrollFrame:ClearAllPoints()
    QuestProgressScrollFrame:SetPoint(
      "TOPLEFT", 
      QuestFrame, 
      "TOPLEFT", 
      QUEST_CONFIG.MARGIN_LEFT, 
      -QUEST_CONFIG.MARGIN_TOP
    )
    QuestProgressScrollFrame:SetWidth(contentWidth)
    QuestProgressScrollFrame:SetHeight(QUEST_CONFIG.SCROLL_HEIGHT_PROGRESS)
    
    if QuestProgressScrollChildFrame then
      QuestProgressScrollChildFrame:SetWidth(contentWidth)
    end
    
    if QuestProgressScrollFrameScrollBar then
      QuestProgressScrollFrameScrollBar:ClearAllPoints()
      QuestProgressScrollFrameScrollBar:SetPoint(
        "TOPRIGHT", 
        QuestProgressScrollFrame, 
        "TOPRIGHT", 
        QUEST_CONFIG.SCROLLBAR_OFFSET_X, 
        -QUEST_CONFIG.SCROLLBAR_OFFSET_TOP
      )
      QuestProgressScrollFrameScrollBar:SetPoint(
        "BOTTOMRIGHT", 
        QuestProgressScrollFrame, 
        "BOTTOMRIGHT", 
        QUEST_CONFIG.SCROLLBAR_OFFSET_X, 
        QUEST_CONFIG.SCROLLBAR_OFFSET_BOTTOM
      )
    end
  end
  
  -- Quest Reward (completion screen)
  if QuestRewardScrollFrame then
    QuestRewardScrollFrame:ClearAllPoints()
    QuestRewardScrollFrame:SetPoint(
      "TOPLEFT", 
      QuestFrame, 
      "TOPLEFT", 
      QUEST_CONFIG.MARGIN_LEFT, 
      -QUEST_CONFIG.MARGIN_TOP
    )
    QuestRewardScrollFrame:SetWidth(contentWidth)
    QuestRewardScrollFrame:SetHeight(QUEST_CONFIG.SCROLL_HEIGHT_REWARD)
    
    if QuestRewardScrollChildFrame then
      QuestRewardScrollChildFrame:SetWidth(contentWidth)
    end
    
    if QuestRewardScrollFrameScrollBar then
      QuestRewardScrollFrameScrollBar:ClearAllPoints()
      QuestRewardScrollFrameScrollBar:SetPoint(
        "TOPRIGHT", 
        QuestRewardScrollFrame, 
        "TOPRIGHT", 
        QUEST_CONFIG.SCROLLBAR_OFFSET_X, 
        -QUEST_CONFIG.SCROLLBAR_OFFSET_TOP
      )
      QuestRewardScrollFrameScrollBar:SetPoint(
        "BOTTOMRIGHT", 
        QuestRewardScrollFrame, 
        "BOTTOMRIGHT", 
        QUEST_CONFIG.SCROLLBAR_OFFSET_X, 
        QUEST_CONFIG.SCROLLBAR_OFFSET_BOTTOM
      )
    end
  end
  
  -- Action Buttons (Accept/Complete on left, Decline/Goodbye on right)
  if QuestFrameAcceptButton then
    QuestFrameAcceptButton:ClearAllPoints()
    QuestFrameAcceptButton:SetPoint(
      "BOTTOMLEFT", 
      backdrop, 
      "BOTTOMLEFT", 
      QUEST_CONFIG.BUTTON_OFFSET_X, 
      QUEST_CONFIG.BUTTON_OFFSET_Y
    )
  end
  
  if QuestFrameCompleteButton then
    QuestFrameCompleteButton:ClearAllPoints()
    QuestFrameCompleteButton:SetPoint(
      "BOTTOMLEFT", 
      backdrop, 
      "BOTTOMLEFT", 
      QUEST_CONFIG.BUTTON_OFFSET_X, 
      QUEST_CONFIG.BUTTON_OFFSET_Y
    )
  end
  
  if QuestFrameDeclineButton then
    QuestFrameDeclineButton:ClearAllPoints()
    QuestFrameDeclineButton:SetPoint(
      "BOTTOMRIGHT", 
      backdrop, 
      "BOTTOMRIGHT", 
      -QUEST_CONFIG.BUTTON_OFFSET_X, 
      QUEST_CONFIG.BUTTON_OFFSET_Y
    )
  end
  
  if QuestFrameGoodbyeButton then
    QuestFrameGoodbyeButton:ClearAllPoints()
    QuestFrameGoodbyeButton:SetPoint(
      "BOTTOMRIGHT", 
      backdrop, 
      "BOTTOMRIGHT", 
      -QUEST_CONFIG.BUTTON_OFFSET_X, 
      QUEST_CONFIG.BUTTON_OFFSET_Y
    )
  end
  
  -- Close Button
  if QuestFrameCloseButton then
    QuestFrameCloseButton:ClearAllPoints()
    QuestFrameCloseButton:SetPoint(
      "TOPRIGHT", 
      backdrop, 
      "TOPRIGHT", 
      -QUEST_CONFIG.CLOSE_OFFSET_X, 
      -QUEST_CONFIG.CLOSE_OFFSET_Y
    )
  end
end

--- Fix text widths to match new frame width
-- Must run after layout to properly wrap text
local function FixTextWidths()
  local textWidth = QUEST_CONFIG.WIDTH - QUEST_CONFIG.MARGIN_LEFT - QUEST_CONFIG.MARGIN_RIGHT - 10
  
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
  
  -- Objective text lines
  for i = 1, 10 do
    local obj = getglobal("QuestObjectiveText" .. i)
    if obj then
      obj:SetWidth(textWidth)
      obj:SetJustifyH("LEFT")
    end
  end
end

-------------------------
-- TEXT FRAME UTILITIES
-------------------------

--- Get visual backdrop frame (pfUI compatibility)
-- @param frame Frame to check
-- @param inset Inset frame fallback
-- @return Frame backdrop, inset, or original frame
local function GetVisualBackdrop(frame, inset)
  if frame and frame.backdrop then
    return frame.backdrop
  end
  if inset then
    return inset
  end
  return frame
end

--- Position scrollbar on text frames
-- @param scrollFrame ScrollFrame to attach to
-- @param scrollBar Scrollbar to position
local function ApplyScrollbarLayout(scrollFrame, scrollBar)
  if not scrollFrame or not scrollBar then return end

  scrollBar:ClearAllPoints()
  scrollBar:SetPoint(
    "TOPRIGHT",
    scrollFrame,
    "TOPRIGHT",
    TEXT_CONFIG.SCROLLBAR_OFFSET_X,
    -TEXT_CONFIG.SCROLLBAR_OFFSET_TOP
  )
  scrollBar:SetPoint(
    "BOTTOMRIGHT",
    scrollFrame,
    "BOTTOMRIGHT",
    TEXT_CONFIG.SCROLLBAR_OFFSET_X,
    TEXT_CONFIG.SCROLLBAR_OFFSET_BOTTOM
  )
end

-------------------------
-- ITEM TEXT FRAME (Books, Notes, Letters)
-------------------------

--- Apply wide layout to book/note reader frame
local function ApplyItemTextLayout()
  if not ItemTextFrame then return end

  local backdrop = GetVisualBackdrop(ItemTextFrame, ItemTextFrameInset)
  if not backdrop then return end

  ItemTextFrame:SetWidth(TEXT_CONFIG.FRAME_WIDTH)
  ItemTextFrame:SetHeight(TEXT_CONFIG.FRAME_HEIGHT)
  ItemTextFrame:ClearAllPoints()
  ItemTextFrame:SetPoint(
    TEXT_CONFIG.ANCHOR_POINT,
    UIParent,
    TEXT_CONFIG.ANCHOR_RELATIVE,
    TEXT_CONFIG.OFFSET_X,
    TEXT_CONFIG.OFFSET_Y
  )

  local contentWidth = backdrop:GetWidth() - TEXT_CONFIG.MARGIN_LEFT - TEXT_CONFIG.MARGIN_RIGHT
  local contentHeight = backdrop:GetHeight() - TEXT_CONFIG.MARGIN_TOP - TEXT_CONFIG.MARGIN_BOTTOM

  if ItemTextScrollFrame then
    ItemTextScrollFrame:ClearAllPoints()
    ItemTextScrollFrame:SetPoint(
      "TOPLEFT",
      backdrop,
      "TOPLEFT",
      TEXT_CONFIG.MARGIN_LEFT,
      -TEXT_CONFIG.MARGIN_TOP
    )
    ItemTextScrollFrame:SetWidth(contentWidth)
    ItemTextScrollFrame:SetHeight(contentHeight)

    ApplyScrollbarLayout(ItemTextScrollFrame, ItemTextScrollFrameScrollBar)
  end

  if ItemTextPageText then
    ItemTextPageText:SetWidth(contentWidth + TEXT_CONFIG.TEXT_RIGHT_PADDING)
    ItemTextPageText:SetJustifyH("LEFT")
  end
end

-------------------------
-- GOSSIP FRAME (NPC Dialogue)
-------------------------

--- Override Blizzard's GossipResize to handle width
-- Blizzard only sets height, causing text overflow
-- @param titleButton Button to resize
function GossipResize(titleButton)
  if not titleButton then return end
  
  local contentWidth = TEXT_CONFIG.FRAME_WIDTH - TEXT_CONFIG.MARGIN_LEFT - TEXT_CONFIG.MARGIN_RIGHT
  
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

--- Apply wide layout to gossip dialog frame
local function ApplyGossipLayout()
  if not GossipFrame then return end

  local backdrop = GetVisualBackdrop(GossipFrame, GossipFrameInset)
  if not backdrop then backdrop = GossipFrame end

  GossipFrame:SetWidth(TEXT_CONFIG.FRAME_WIDTH)
  GossipFrame:SetHeight(TEXT_CONFIG.FRAME_HEIGHT)
  GossipFrame:ClearAllPoints()
  GossipFrame:SetPoint(
    TEXT_CONFIG.ANCHOR_POINT,
    UIParent,
    TEXT_CONFIG.ANCHOR_RELATIVE,
    TEXT_CONFIG.OFFSET_X,
    TEXT_CONFIG.OFFSET_Y
  )

  local contentWidth = TEXT_CONFIG.FRAME_WIDTH - TEXT_CONFIG.MARGIN_LEFT - TEXT_CONFIG.MARGIN_RIGHT - 40
  local contentHeight = TEXT_CONFIG.FRAME_HEIGHT - TEXT_CONFIG.MARGIN_TOP - TEXT_CONFIG.MARGIN_BOTTOM - 90

  if GossipGreetingScrollFrame then
    GossipGreetingScrollFrame:ClearAllPoints()
    GossipGreetingScrollFrame:SetPoint(
      "TOPLEFT",
      backdrop,
      "TOPLEFT",
      TEXT_CONFIG.MARGIN_LEFT,
      -TEXT_CONFIG.MARGIN_TOP
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

--- Hook GossipFrameUpdate to apply layout after Blizzard updates
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
-- EVENT HANDLERS
-------------------------

-- Quest Frame Events
local questEventFrame = CreateFrame("Frame")
questEventFrame:RegisterEvent("QUEST_DETAIL")
questEventFrame:RegisterEvent("QUEST_PROGRESS")
questEventFrame:RegisterEvent("QUEST_COMPLETE")
questEventFrame:RegisterEvent("QUEST_GREETING")
questEventFrame:SetScript("OnEvent", function()
  this:SetScript("OnUpdate", function()
    ApplyQuestLayout()
    FixTextWidths()
    this:SetScript("OnUpdate", nil)
  end)
end)

-- Gossip Frame Events
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

-- Item Text Events (Books/Notes)
local itemTextEventFrame = CreateFrame("Frame")
itemTextEventFrame:RegisterEvent("ITEM_TEXT_BEGIN")
itemTextEventFrame:RegisterEvent("ITEM_TEXT_READY")
itemTextEventFrame:SetScript("OnEvent", function()
  this:SetScript("OnUpdate", function()
    ApplyItemTextLayout()
    this:SetScript("OnUpdate", nil)
  end)
end)

-------------------------
-- ONSHOW HOOKS
-------------------------

-- Quest Frame OnShow
local originalQuestOnShow = QuestFrame:GetScript("OnShow")
QuestFrame:SetScript("OnShow", function()
  if originalQuestOnShow then originalQuestOnShow() end
  ApplyQuestLayout()
  this:SetScript("OnUpdate", function()
    FixTextWidths()
    this:SetScript("OnUpdate", nil)
  end)
end)

-- Item Text OnShow
if ItemTextFrame then
  local originalItemTextOnShow = ItemTextFrame:GetScript("OnShow")
  ItemTextFrame:SetScript("OnShow", function()
    if originalItemTextOnShow then originalItemTextOnShow() end
    ApplyItemTextLayout()
  end)
end

-- Gossip Frame OnShow
if GossipFrame then
  local originalGossipOnShow = GossipFrame:GetScript("OnShow")
  GossipFrame:SetScript("OnShow", function()
    if originalGossipOnShow then originalGossipOnShow() end
    ApplyGossipLayout()
  end)
end

-------------------------
-- INITIALIZATION
-------------------------

local function Init()
  local timer = 0
  local initFrame = CreateFrame("Frame")
  initFrame:SetScript("OnUpdate", function()
    timer = timer + arg1
    if timer > 0.5 then
      ApplyQuestLayout()
      FixTextWidths()
      this:SetScript("OnUpdate", nil)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBetterQuestText|r loaded")
    end
  end)
end

Init()