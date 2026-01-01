-- WideQuestFrame.lua
-- pfUI-aware wide quest layout for WoW 1.12.1
-- Simple and working version

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
  MARGIN_LEFT = 25,
  MARGIN_RIGHT = 50,
  MARGIN_TOP = 50,

  -- Text Margins
  TEXT_MARGIN_LEFT = 25,
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
  TEXT_RIGHT_PADDING =-20,

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
  
  -- Content width
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
  -- Buttons - Accept/Complete forced to LEFT (Blizzard resets Complete here)
  -- Decline/Goodbye on RIGHT for consistency
  ------------------------------------------------
  
  -- Accept button (LEFT)
  if QuestFrameAcceptButton then
    QuestFrameAcceptButton:ClearAllPoints()
    QuestFrameAcceptButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  -- Complete button (LEFT - Blizzard forces this position)
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
  local textWidth = CONFIG.WIDTH - CONFIG.MARGIN_LEFT - CONFIG.MARGIN_RIGHT -10
  
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

  -- Size & position ROOT frame
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
    ItemTextPageText:SetWidth(contentWidth+WIDE_TEXT_CONFIG.TEXT_RIGHT_PADDING)
    ItemTextPageText:SetJustifyH("LEFT")
  end
end
-------------------------------------------------
-- GossipFrame (NPC dialogue text) - Complete Fix
-------------------------------------------------

-- Store the original GossipResize function
local OriginalGossipResize = GossipResize

-- Replace Blizzard's GossipResize to handle width AND height
function GossipResize(titleButton)
  if not titleButton then return end
  
  local contentWidth = WIDE_TEXT_CONFIG.FRAME_WIDTH - WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT - WIDE_TEXT_CONFIG.CONTENT_MARGIN_RIGHT
  
  -- Set height like Blizzard does
  titleButton:SetHeight(titleButton:GetTextHeight() + 2)
  
  -- ALSO set width (this is what Blizzard doesn't do)
  titleButton:SetWidth(contentWidth)
  
  
  -- Don't interfere with OnClick handler - it's already set in XML
  -- Don't touch titleButton.type - Blizzard sets this after calling GossipResize
  
  -- Fix the text element inside the button
  local buttonText = getglobal(titleButton:GetName() .. "Text")
  if buttonText then
    buttonText:ClearAllPoints()
    buttonText:SetPoint("LEFT", titleButton, "LEFT", 25, 0) -- Leave room for icon
    buttonText:SetWidth(contentWidth - 30)
    buttonText:SetJustifyH("LEFT")
  end
  
  -- Make sure the icon stays in place
  local buttonIcon = getglobal(titleButton:GetName() .. "GossipIcon")
  if buttonIcon then
    buttonIcon:ClearAllPoints()
    buttonIcon:SetPoint("LEFT", titleButton, "LEFT", 3, 0)
  end
end

local function ApplyGossipLayout()
  if not GossipFrame then return end

  -- Get backdrop (pfUI creates this around the frame)
  local backdrop = GetVisualBackdrop(GossipFrame, GossipFrameInset)
  if not backdrop then backdrop = GossipFrame end

  -- Set root frame dimensions
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

  local contentWidth = WIDE_TEXT_CONFIG.FRAME_WIDTH - WIDE_TEXT_CONFIG.CONTENT_MARGIN_LEFT - WIDE_TEXT_CONFIG.CONTENT_MARGIN_RIGHT-40
  local contentHeight = WIDE_TEXT_CONFIG.FRAME_HEIGHT - WIDE_TEXT_CONFIG.CONTENT_MARGIN_TOP - WIDE_TEXT_CONFIG.CONTENT_MARGIN_BOTTOM-90

  -- Size the scroll frame that contains everything
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
    
    -- CRITICAL: Enable mouse on scroll frame so clicks pass through
    GossipGreetingScrollFrame:EnableMouse(true)
    
    if GossipGreetingScrollFrameScrollBar then
      ApplyScrollbarLayout(GossipGreetingScrollFrame, GossipGreetingScrollFrameScrollBar)
    end
  end

  -- Size the greeting panel (child of scroll frame)
  -- CRITICAL: This must be WIDER than the buttons for clicks to work
  if GossipGreetingScrollChildFrame then
    GossipGreetingScrollChildFrame:SetWidth(contentWidth)
    
    -- CRITICAL: Disable mouse on child frame so clicks pass to buttons
    GossipGreetingScrollChildFrame:EnableMouse(true)
    
  end
end

-- Store original GossipFrameUpdate to hook it
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
    -- Delay slightly to ensure frame is ready
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
-- OnShow Hooks (Blizzard resets layout)
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

for i = 1, NUMGOSSIPBUTTONS do
  local b = getglobal("GossipTitleButton"..i)
  if b and b:IsShown() then
    b:SetScript("OnClick", function()
      DEFAULT_CHAT_FRAME:AddMessage("Clicked "..b:GetName())
      SelectGossipOption(b:GetID())
    end)
  end
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
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBetterQuest|r loaded")
    end
  end)
end

Init()