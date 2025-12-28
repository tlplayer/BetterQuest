-- WideQuestFrame.lua
-- pfUI-aware wide quest layout for WoW 1.12.1
-- Proper backdrop-aware positioning

-------------------------
-- CONFIG
-------------------------
local CONFIG = {
  -- Frame dimensions
  WIDTH = 700,
  HEIGHT = 400,  -- Increased from 360 to 400 (taller)
  
  -- Frame position
  POS_X = 0,
  POS_Y = -60,  -- Changed from 0 to 100 (anchor 100px up from bottom)
  
  -- Content margins
  MARGIN_LEFT = 25,
  MARGIN_RIGHT = 60,  -- Increased from 25 to 60 to prevent text clipping
  MARGIN_TOP = 55,
  
  -- Scroll heights
  HEIGHT_DETAIL_SCROLL = 220,  -- Increased to use taller frame
  HEIGHT_PROGRESS_SCROLL = 220,
  HEIGHT_REWARD_SCROLL = 200,
  
  -- Button offsets from backdrop edges
  BUTTON_OFFSET_X = 20,
  BUTTON_OFFSET_Y = 20,
  
  -- Close button
  CLOSE_OFFSET_X = 8,
  CLOSE_OFFSET_Y = 8,
  
  -- Scrollbar (outside text area, to the right)
  SCROLLBAR_OFFSET_X = 15,  -- Changed from -2 to 15 (outside text)
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
  
  -- Move step
  MOVE_STEP = 20,
}

-------------------------
-- Get Backdrop
-------------------------
local function GetBackdrop()
  -- pfUI creates QuestFrame.backdrop
  return QuestFrame.backdrop or QuestFrame
end

-------------------------
-- Apply Layout
-------------------------
local function ApplyLayout()
  if not QuestFrame then return end
  
  local backdrop = GetBackdrop()
  
  -- Size QuestFrame
  QuestFrame:SetWidth(CONFIG.WIDTH)
  QuestFrame:SetHeight(CONFIG.HEIGHT)
  
  -- Position QuestFrame
  QuestFrame:ClearAllPoints()
  QuestFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", CONFIG.POS_X, CONFIG.POS_Y)
  
  -- Content width
  local contentWidth = CONFIG.WIDTH - CONFIG.MARGIN_LEFT - CONFIG.MARGIN_RIGHT
  
  ------------------------------------------------
  -- Scroll Frames (relative to QuestFrame)
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
  -- Buttons (relative to backdrop)
  ------------------------------------------------
  if QuestFrameAcceptButton then
    QuestFrameAcceptButton:ClearAllPoints()
    QuestFrameAcceptButton:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  if QuestFrameCompleteButton then
    QuestFrameCompleteButton:ClearAllPoints()
    QuestFrameCompleteButton:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  if QuestFrameDeclineButton then
    QuestFrameDeclineButton:ClearAllPoints()
    QuestFrameDeclineButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  if QuestFrameGoodbyeButton then
    QuestFrameGoodbyeButton:ClearAllPoints()
    QuestFrameGoodbyeButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", CONFIG.BUTTON_OFFSET_X, CONFIG.BUTTON_OFFSET_Y)
  end
  
  ------------------------------------------------
  -- Close Button (relative to backdrop)
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
  local textWidth = CONFIG.WIDTH - CONFIG.MARGIN_LEFT - CONFIG.MARGIN_RIGHT
  
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
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccWideQuestFrame|r loaded")
    end
  end)
end

-------------------------
-- Commands
-------------------------
SLASH_WIDEQUEST1 = "/wq"
SlashCmdList["WIDEQUEST"] = function(msg)
  if msg == "up" then
    CONFIG.POS_Y = CONFIG.POS_Y + CONFIG.MOVE_STEP
    ApplyLayout()
  elseif msg == "down" then
    CONFIG.POS_Y = CONFIG.POS_Y - CONFIG.MOVE_STEP
    ApplyLayout()
  elseif msg == "reset" then
    CONFIG.POS_Y = 0
    ApplyLayout()
  elseif msg == "reload" then
    ApplyLayout()
    FixTextWidths()
  end
end

Init()