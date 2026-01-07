-- GossipFrame.lua
-- Wide gossip dialog with portrait support
-- SoundQueue-integrated
-- WoW 1.12.1 compatible

-------------------------
-- CONFIGURATION
-------------------------

local GOSSIP_CONFIG = {
    WIDTH = 620,
    HEIGHT = 350,

    OFFSET_X = 0,
    OFFSET_Y = -250,

    MARGIN_LEFT = 140,
    MARGIN_RIGHT = 40,
    MARGIN_TOP = 40,
    MARGIN_BOTTOM = 40,

    SCROLLBAR_OFFSET_X = 16,
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
-- PORTRAIT
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

local function UpdateNPCPortrait()
    if not GossipFrame then return end

    if PortraitManager then
        PortraitManager:UpdateNPCPortrait(GossipFrame)
        return
    end

    local portrait = EnsurePortrait(GossipFrame)
    portrait.texture:SetTexture("Interface\\CharacterFrame\\TempPortrait")
    portrait:Show()
end

local function HidePortrait()
    if GossipFrame and GossipFrame.widePortrait then
        GossipFrame.widePortrait:Hide()
    end
end

-------------------------
-- LAYOUT
-------------------------

local function GetBackdrop()
    return GossipFrame.backdrop or GossipFrame
end

local function ApplyGossipLayout()
    if not GossipFrame then return end

    local backdrop = GetBackdrop()

    GossipFrame:SetWidth(GOSSIP_CONFIG.WIDTH)
    GossipFrame:SetHeight(GOSSIP_CONFIG.HEIGHT)
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        GOSSIP_CONFIG.OFFSET_X,
        GOSSIP_CONFIG.OFFSET_Y
    )

    UpdateNPCPortrait()

    local contentWidth =
        GOSSIP_CONFIG.WIDTH -
        GOSSIP_CONFIG.MARGIN_LEFT -
        GOSSIP_CONFIG.MARGIN_RIGHT

    local contentHeight =
        GOSSIP_CONFIG.HEIGHT -
        GOSSIP_CONFIG.MARGIN_TOP -
        GOSSIP_CONFIG.MARGIN_BOTTOM -
        80

    if GossipGreetingScrollFrame then
        GossipGreetingScrollFrame:ClearAllPoints()
        GossipGreetingScrollFrame:SetPoint(
            "TOPLEFT",
            backdrop,
            "TOPLEFT",
            GOSSIP_CONFIG.MARGIN_LEFT,
            -GOSSIP_CONFIG.MARGIN_TOP
        )
        GossipGreetingScrollFrame:SetWidth(contentWidth)
        GossipGreetingScrollFrame:SetHeight(contentHeight)
    end

    if GossipGreetingScrollChildFrame then
        GossipGreetingScrollChildFrame:SetWidth(contentWidth)
    end

    if GossipGreetingScrollFrameScrollBar then
        GossipGreetingScrollFrameScrollBar:ClearAllPoints()
        GossipGreetingScrollFrameScrollBar:SetPoint(
            "TOPRIGHT",
            GossipGreetingScrollFrame,
            "TOPRIGHT",
            GOSSIP_CONFIG.SCROLLBAR_OFFSET_X,
            -GOSSIP_CONFIG.SCROLLBAR_OFFSET_TOP
        )
        GossipGreetingScrollFrameScrollBar:SetPoint(
            "BOTTOMRIGHT",
            GossipGreetingScrollFrame,
            "BOTTOMRIGHT",
            GOSSIP_CONFIG.SCROLLBAR_OFFSET_X,
            GOSSIP_CONFIG.SCROLLBAR_OFFSET_BOTTOM
        )
    end
end

-------------------------
-- BUTTON WIDTH FIX
-------------------------

-- Blizzard only adjusts height; width must be fixed manually
function GossipResize(titleButton)
    if not titleButton then return end

    local contentWidth =
        GOSSIP_CONFIG.WIDTH -
        GOSSIP_CONFIG.MARGIN_LEFT -
        GOSSIP_CONFIG.MARGIN_RIGHT

    titleButton:SetHeight(titleButton:GetTextHeight() + 4)
    titleButton:SetWidth(contentWidth)

    local text = getglobal(titleButton:GetName() .. "Text")
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", titleButton, "LEFT", 25, 0)
        text:SetWidth(contentWidth - 30)
        text:SetJustifyH("LEFT")
    end

    local icon = getglobal(titleButton:GetName() .. "GossipIcon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", titleButton, "LEFT", 3, 0)
    end
end

-------------------------
-- SOUNDQUEUE INTEGRATION
-------------------------

local function HookSoundQueue()
    if not SoundQueue then return end

    SoundQueue.OnVoiceStart = function(_, data)
        if not data then return end
        if data.dialog_type ~= "gossip" then return end

        if PortraitManager and data.npc_name then
            PortraitManager:SetActiveNPC(data.npc_name)
        end

        UpdateNPCPortrait()
    end

    SoundQueue.OnVoiceStop = function()
        HidePortrait()
    end
end

-------------------------
-- EVENTS
-------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")

eventFrame:SetScript("OnEvent", function()
    if event == "GOSSIP_CLOSED" then
        HidePortrait()
        return
    end

    this:SetScript("OnUpdate", function()
        ApplyGossipLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

-------------------------
-- OVERRIDE UPDATE
-------------------------

local OriginalGossipFrameUpdate = GossipFrameUpdate
function GossipFrameUpdate()
    if OriginalGossipFrameUpdate then
        OriginalGossipFrameUpdate()
    end

    -- Delay so Blizzard creates buttons first
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
        ApplyGossipLayout()
        this:SetScript("OnUpdate", nil)
    end)
end

-------------------------
-- ONSHOW
-------------------------

local originalOnShow = GossipFrame:GetScript("OnShow")
GossipFrame:SetScript("OnShow", function()
    if originalOnShow then originalOnShow() end
    ApplyGossipLayout()
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
            ApplyGossipLayout()
            HookSoundQueue()
            this:SetScript("OnUpdate", nil)
        end
    end)
end

Init()
