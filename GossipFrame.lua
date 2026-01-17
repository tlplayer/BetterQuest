-- GossipFrame.lua
-- Wide gossip dialog with portrait support
-- SoundQueue-integrated
-- WoW 1.12.1 compatible

---------------------------------------------------------------------
-- LAYOUT OVERVIEW (ASCII MAP)
--
--  +----------------------------------------------------------+
--  |                                                          |
--  |  FRAME                                                   |
--  |  WIDTH x HEIGHT                                          |
--  |                                                          |
--  |  +--------------------+  GAP_FROM_PORTRAIT  +----------+|
--  |  |                    |<------------------>|          ||
--  |  |    PORTRAIT        |                    | CONTENT  ||
--  |  |                    |                    | (SCROLL) ||
--  |  |  WIDTH x HEIGHT    |                    |          ||
--  |  |                    |                    |          ||
--  |  +--------------------+                    +----------+|
--  |      ^                                         ^        |
--  |      | PORTRAIT.TOP                            | CONTENT.TOP
--  |                                                          |
--  |                                      EXTRA_BOTTOM_RESERVED
--  |                                      (Blizzard buttons) |
--  +----------------------------------------------------------+
--
-- Horizontal positioning:
--
-- FRAME.LEFT
--   + PORTRAIT.LEFT
--   + PORTRAIT.WIDTH
--   + CONTENT.GAP_FROM_PORTRAIT
--   = CONTENT.LEFT
--
---------------------------------------------------------------------

-------------------------
-- CONFIG (AUTHOR INTENT)
-------------------------

local CONFIG = {
    FRAME = {
        WIDTH = 620,     -- overall gossip frame width
        HEIGHT = 350,    -- overall gossip frame height
        OFFSET_X = 0,    -- screen center offset X
        OFFSET_Y = -250, -- screen center offset Y
    },

    PORTRAIT = {
        WIDTH = 125,     -- portrait frame width
        HEIGHT = 220,    -- portrait frame height
        LEFT = 15,       -- distance from frame left edge
        TOP = 50,        -- distance from frame top edge
    },

    CONTENT = {
        GAP_FROM_PORTRAIT = -10, -- horizontal gap between portrait and content (can be negative)
        RIGHT = 60,              -- right margin inside frame
        TOP = 40,                -- top margin inside frame
        BOTTOM = 40,             -- bottom margin inside frame
        EXTRA_BOTTOM_RESERVED = 80, -- Blizzard buttons/footer space
    },

    BUTTON = {
        HEIGHT_PADDING = 4, -- extra vertical padding per button
        TEXT_LEFT = 25,     -- text left inset inside button
        TEXT_RIGHT = 5,     -- text right inset
        ICON_LEFT = 3,      -- icon left inset
    },

    SCROLLBAR = {
        OFFSET_X = 16,      -- scrollbar horizontal offset
        OFFSET_TOP = 16,    -- scrollbar top offset
        OFFSET_BOTTOM = 16, -- scrollbar bottom offset
    },
}

-------------------------
-- DERIVED LAYOUT
-------------------------

local LAYOUT = {
    FRAME = {
        WIDTH  = CONFIG.FRAME.WIDTH,
        HEIGHT = CONFIG.FRAME.HEIGHT,
    },

    PORTRAIT = {
        LEFT  = CONFIG.PORTRAIT.LEFT,
        TOP   = CONFIG.PORTRAIT.TOP,
        RIGHT = CONFIG.PORTRAIT.LEFT + CONFIG.PORTRAIT.WIDTH,
    },

    CONTENT = {
        LEFT =
            CONFIG.PORTRAIT.LEFT
            + CONFIG.PORTRAIT.WIDTH
            + CONFIG.CONTENT.GAP_FROM_PORTRAIT,

        WIDTH =
            CONFIG.FRAME.WIDTH
            - (
                CONFIG.PORTRAIT.LEFT
                + CONFIG.PORTRAIT.WIDTH
                + CONFIG.CONTENT.GAP_FROM_PORTRAIT
              )
            - CONFIG.CONTENT.RIGHT,

        HEIGHT =
            CONFIG.FRAME.HEIGHT
            - CONFIG.CONTENT.TOP
            - CONFIG.CONTENT.BOTTOM
            - CONFIG.CONTENT.EXTRA_BOTTOM_RESERVED,
    },
}

-------------------------
-- PORTRAIT
-------------------------

local function EnsurePortrait(parent)
    if parent.widePortrait then return parent.widePortrait end

    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetWidth(CONFIG.PORTRAIT.WIDTH)
    portrait:SetHeight(CONFIG.PORTRAIT.HEIGHT)
    portrait:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        LAYOUT.PORTRAIT.LEFT,
        -LAYOUT.PORTRAIT.TOP
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

    GossipFrame:SetWidth(LAYOUT.FRAME.WIDTH)
    GossipFrame:SetHeight(LAYOUT.FRAME.HEIGHT)
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        CONFIG.FRAME.OFFSET_X,
        CONFIG.FRAME.OFFSET_Y
    )

    UpdateNPCPortrait()

    -- Anchor scroll frame and content inside backdrop
    if GossipGreetingScrollFrame then
        GossipGreetingScrollFrame:ClearAllPoints()
        GossipGreetingScrollFrame:SetPoint(
            "TOPLEFT",
            backdrop,
            "TOPLEFT",
            LAYOUT.CONTENT.LEFT,
            -CONFIG.CONTENT.TOP
        )
        GossipGreetingScrollFrame:SetWidth(LAYOUT.CONTENT.WIDTH)
        GossipGreetingScrollFrame:SetHeight(LAYOUT.CONTENT.HEIGHT)
    end

    if GossipGreetingScrollChildFrame then
        GossipGreetingScrollChildFrame:SetWidth(LAYOUT.CONTENT.WIDTH)
    end

    if GossipGreetingScrollFrameScrollBar then
        GossipGreetingScrollFrameScrollBar:ClearAllPoints()
        GossipGreetingScrollFrameScrollBar:SetPoint(
            "TOPRIGHT",
            GossipGreetingScrollFrame,
            "TOPRIGHT",
            CONFIG.SCROLLBAR.OFFSET_X,
            -CONFIG.SCROLLBAR.OFFSET_TOP
        )
        GossipGreetingScrollFrameScrollBar:SetPoint(
            "BOTTOMRIGHT",
            GossipGreetingScrollFrame,
            "BOTTOMRIGHT",
            CONFIG.SCROLLBAR.OFFSET_X,
            CONFIG.SCROLLBAR.OFFSET_BOTTOM
        )
    end
end

-------------------------
-- BUTTON WIDTH FIX
-------------------------

function GossipResize(titleButton)
    if not titleButton then return end

    titleButton:SetWidth(LAYOUT.CONTENT.WIDTH)
    titleButton:SetHeight(
        titleButton:GetTextHeight()
        + CONFIG.BUTTON.HEIGHT_PADDING
    )

    local text = getglobal(titleButton:GetName() .. "Text")
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", titleButton, "LEFT", CONFIG.BUTTON.TEXT_LEFT, 0)
        text:SetWidth(
            LAYOUT.CONTENT.WIDTH
            - CONFIG.BUTTON.TEXT_LEFT
            - CONFIG.BUTTON.TEXT_RIGHT
        )
        text:SetJustifyH("LEFT")
    end

    local icon = getglobal(titleButton:GetName() .. "GossipIcon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", titleButton, "LEFT", CONFIG.BUTTON.ICON_LEFT, 0)
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
