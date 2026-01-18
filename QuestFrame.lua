-- QuestFrame.lua
-- Wide quest frame with NPC portraits
-- SoundQueue-integrated
-- WoW 1.12.1 compatible

-------------------------
-- CONFIGURATION
-------------------------

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

    SCROLLBAR_OFFSET_X = -8,
    SCROLLBAR_OFFSET_TOP = 16,
    SCROLLBAR_OFFSET_BOTTOM = 16,
}

local PORTRAIT_CONFIG = {
    WIDTH = 125,
    HEIGHT = 220,
    OFFSET_X = 15,
    OFFSET_Y = 50,
}

-------------------------
-- PORTRAIT CREATION
-------------------------

local function EnsurePortrait(parent)
    if parent.widePortrait then return parent.widePortrait end

    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetWidth(PORTRAIT_CONFIG.WIDTH)
    portrait:SetHeight(PORTRAIT_CONFIG.HEIGHT)
    portrait:SetPoint(
        "TOPLEFT",
        parent,
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

    parent.widePortrait = portrait
    return portrait
end

-------------------------
-- PORTRAIT UPDATE
-------------------------

local function UpdateNPCPortrait()
    if not QuestFrame then return end

    if PortraitManager then
        PortraitManager:UpdateNPCPortrait(QuestFrame)
        return
    end

    -- Fallback portrait
    local portrait = EnsurePortrait(QuestFrame)
    portrait.texture:SetTexture("Interface\\CharacterFrame\\TempPortrait")
    portrait:Show()
end

local function HidePortrait()
    if QuestFrame and QuestFrame.widePortrait then
        QuestFrame.widePortrait:Hide()
    end
end

-------------------------
-- QUEST FRAME LAYOUT
-------------------------

local function GetBackdrop()
    return QuestFrame.backdrop or QuestFrame
end

local function ApplyQuestLayout()
    if not QuestFrame then return end

    local backdrop = GetBackdrop()

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

    UpdateNPCPortrait()

    local contentWidth =
        QUEST_CONFIG.WIDTH -
        QUEST_CONFIG.MARGIN_LEFT -
        QUEST_CONFIG.MARGIN_RIGHT

    local function LayoutScroll(scrollFrame, child, height)
        if not scrollFrame then return end

        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint(
            "TOPLEFT",
            QuestFrame,
            "TOPLEFT",
            QUEST_CONFIG.MARGIN_LEFT,
            -QUEST_CONFIG.MARGIN_TOP
        )
        scrollFrame:SetWidth(contentWidth)
        scrollFrame:SetHeight(height)

        if child then
            child:SetWidth(contentWidth)
        end
    end

    LayoutScroll(
        QuestDetailScrollFrame,
        QuestDetailScrollChildFrame,
        QUEST_CONFIG.SCROLL_HEIGHT_DETAIL
    )

    LayoutScroll(
        QuestProgressScrollFrame,
        QuestProgressScrollChildFrame,
        QUEST_CONFIG.SCROLL_HEIGHT_PROGRESS
    )

    LayoutScroll(
        QuestRewardScrollFrame,
        QuestRewardScrollChildFrame,
        QUEST_CONFIG.SCROLL_HEIGHT_REWARD
    )

    if QuestFrameAcceptButton then
        QuestFrameAcceptButton:SetPoint(
            "BOTTOMLEFT",
            backdrop,
            "BOTTOMLEFT",
            QUEST_CONFIG.BUTTON_OFFSET_X,
            QUEST_CONFIG.BUTTON_OFFSET_Y
        )
    end

    if QuestFrameDeclineButton then
        QuestFrameDeclineButton:SetPoint(
            "BOTTOMRIGHT",
            backdrop,
            "BOTTOMRIGHT",
            -QUEST_CONFIG.BUTTON_OFFSET_X,
            QUEST_CONFIG.BUTTON_OFFSET_Y
        )
    end

    if QuestFrameCompleteButton then
        QuestFrameCompleteButton:SetPoint(
            "BOTTOMLEFT",
            backdrop,
            "BOTTOMLEFT",
            QUEST_CONFIG.BUTTON_OFFSET_X,
            QUEST_CONFIG.BUTTON_OFFSET_Y
        )
    end

    if QuestFrameGoodbyeButton then
        QuestFrameGoodbyeButton:SetPoint(
            "BOTTOMRIGHT",
            backdrop,
            "BOTTOMRIGHT",
            -QUEST_CONFIG.BUTTON_OFFSET_X,
            QUEST_CONFIG.BUTTON_OFFSET_Y
        )
    end

    if QuestFrameCloseButton then
        QuestFrameCloseButton:SetPoint(
            "TOPRIGHT",
            backdrop,
            "TOPRIGHT",
            -QUEST_CONFIG.CLOSE_OFFSET_X,
            -QUEST_CONFIG.CLOSE_OFFSET_Y
        )
    end
end

local function FixTextWidths()
    local width =
        QUEST_CONFIG.WIDTH -
        QUEST_CONFIG.MARGIN_LEFT -
        QUEST_CONFIG.MARGIN_RIGHT -
        10

    local fields = {
        QuestTitleText,
        QuestDescription,
        QuestObjectiveText,
        QuestProgressText,
        QuestRewardText,
    }

    for _, f in ipairs(fields) do
        if f then
            f:SetWidth(width)
            f:SetJustifyH("LEFT")
        end
    end
end

-------------------------
-- SOUNDQUEUE INTEGRATION
-------------------------

local function HookSoundQueue()
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
        HidePortrait()
    end
end

-------------------------
-- EVENTS
-------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_PROGRESS")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("QUEST_GREETING")

eventFrame:SetScript("OnEvent", function()
    this:SetScript("OnUpdate", function()
        ApplyQuestLayout()
        FixTextWidths()
        this:SetScript("OnUpdate", nil)
    end)
end)

-------------------------
-- ONSHOW
-------------------------

local originalOnShow = QuestFrame:GetScript("OnShow")
QuestFrame:SetScript("OnShow", function()
    if originalOnShow then originalOnShow() end
    ApplyQuestLayout()
    FixTextWidths()
end)

-------------------------
-- INIT
-------------------------

local function Init()
    local t = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
        t = t + arg1
        if t > 0.5 then
            ApplyQuestLayout()
            FixTextWidths()
            HookSoundQueue()
            this:SetScript("OnUpdate", nil)
        end
    end)
end

Init()
