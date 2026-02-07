-- =====================================================================
--   SECTION 3 — QuestFrame Layout (PFUI-Compatible)
-- =====================================================================

do  -- block-scope so all locals are invisible to the rest of ui.lua

local function GetBackdrop()
    return QuestFrame.backdrop or QuestFrame
end

local function UpdateNPCPortrait()
    if not QuestFrame then return end
    if PortraitManager then
        PortraitManager:UpdateNPCPortrait(QuestFrame)
        return
    end
end

local function HideQuestPortrait()
    if QuestFrame and QuestFrame.widePortrait then
        QuestFrame.widePortrait:Hide()
    end
end

local function LayoutScroll(scrollFrame, child, height)
    if not scrollFrame then return end

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", QuestFrame, "TOPLEFT",
        CONFIG.DIALOG.CONTENT_MARGIN_LEFT, -CONFIG.DIALOG.CONTENT_MARGIN_TOP)
    scrollFrame:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
    scrollFrame:SetHeight(height)

    if child then 
        child:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH) 
    end
end

local function ApplyQuestLayout()
    if not QuestFrame then return end
    local backdrop = GetBackdrop()

    QuestFrame:SetWidth(CONFIG.DIALOG.FRAME_WIDTH)
    QuestFrame:SetHeight(CONFIG.DIALOG.FRAME_HEIGHT)
    QuestFrame:ClearAllPoints()
    QuestFrame:SetPoint(CONFIG.DIALOG.ANCHOR_POINT, UIParent, CONFIG.DIALOG.ANCHOR_RELATIVE, 
        CONFIG.DIALOG.OFFSET_X, CONFIG.DIALOG.OFFSET_Y)

    -- Update portrait (no custom background - let PFUI handle it)
    UpdateNPCPortrait()

    LayoutScroll(QuestDetailScrollFrame,   QuestDetailScrollChildFrame,   CONFIG.DIALOG.SCROLL_HEIGHT_DETAIL)
    LayoutScroll(QuestProgressScrollFrame, QuestProgressScrollChildFrame, CONFIG.DIALOG.SCROLL_HEIGHT_PROGRESS)
    LayoutScroll(QuestRewardScrollFrame,   QuestRewardScrollChildFrame,   CONFIG.DIALOG.SCROLL_HEIGHT_REWARD)
    LayoutScroll(QuestGreetingScrollFrame, QuestGreetingScrollChildFrame, CONFIG.DIALOG.SCROLL_HEIGHT_GREETING)

    -- Re-anchor all Blizzard buttons
    if QuestFrameAcceptButton then
        QuestFrameAcceptButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            -CONFIG.DIALOG.BUTTON_OFFSET_X, CONFIG.DIALOG.BUTTON_OFFSET_Y)
    end
    if QuestFrameDeclineButton then
        QuestFrameDeclineButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            CONFIG.DIALOG.BUTTON_OFFSET_X, CONFIG.DIALOG.BUTTON_OFFSET_Y)
    end
    if QuestFrameCompleteButton then
        QuestFrameCompleteButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            -CONFIG.DIALOG.BUTTON_OFFSET_X, CONFIG.DIALOG.BUTTON_OFFSET_Y)
    end
    if QuestFrameGoodbyeButton then
        QuestFrameGoodbyeButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            CONFIG.DIALOG.BUTTON_OFFSET_X, CONFIG.DIALOG.BUTTON_OFFSET_Y)
    end
    if QuestFrameCloseButton then
        QuestFrameCloseButton:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT",
            -CONFIG.DIALOG.CLOSE_OFFSET_X, -CONFIG.DIALOG.CLOSE_OFFSET_Y)
    end
    
    -- Greeting buttons alignment
    if QuestGreetingFrameCancelButton then
        QuestGreetingFrameCancelButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            CONFIG.DIALOG.BUTTON_OFFSET_X, CONFIG.DIALOG.BUTTON_OFFSET_Y)
    end
end

local function FixTextWidths()
    local width = GetDialogTextWidth()
    local fields = {
        QuestTitleText, QuestDescription, QuestObjectiveText,
        QuestProgressText, QuestRewardText,
        GreetingText,
    }
    for _, f in ipairs(fields) do
        if f then
            f:SetWidth(width)
            f:SetJustifyH(CONFIG.DIALOG.TEXT_JUSTIFY)
        end
    end
    
    -- Fix Greeting title buttons alignment
    for i=1, 32 do
        local button = getglobal("QuestTitleButton"..i)
        if button and button:IsShown() then
            button:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
            local text = getglobal("QuestTitleButton"..i.."QuestTitle")
            if text then
                text:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH - 20)
                text:SetJustifyH("LEFT")
            end
        end
    end
end

-- SoundQueue hook: update portrait when voice starts on a quest dialog
local function HookQuestSoundQueue()
    if not SoundQueue then return end

    SoundQueue.OnVoiceStart = function(_, data)
        if not data then return end
        if data.dialog_type == "quest" or data.dialog_type == "gossip" then
            if PortraitManager and data.npc_name then
                PortraitManager:SetActiveNPC(data.npc_name)
            end
            UpdateNPCPortrait()
        end
    end

    SoundQueue.OnVoiceStop = function()
        HideQuestPortrait()
    end
end

-- Event frame for quest UI events
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

-- OnShow hook
local originalQuestOnShow = QuestFrame:GetScript("OnShow")
QuestFrame:SetScript("OnShow", function()
    if originalQuestOnShow then originalQuestOnShow() end
    ApplyQuestLayout()
    FixTextWidths()
end)

-- Delayed init (gives Blizzard frames time to exist)
local questInitFrame = CreateFrame("Frame")
local questInitTimer = 0
questInitFrame:SetScript("OnUpdate", function()
    questInitTimer = questInitTimer + arg1
    if questInitTimer > 0.5 then
        ApplyQuestLayout()
        FixTextWidths()
        HookQuestSoundQueue()
        this:SetScript("OnUpdate", nil)
    end
end)

end  -- end QuestFrame do-block


