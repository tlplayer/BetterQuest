--=====================================================================
-- ui.lua
-- All dialog frame layout, sizing, and portrait wiring lives here.
-- Load order: utils → soundqueue → ui → core
--=====================================================================

UI = {}

-----------------------------------------------------------------------
-- COMPUTED HELPERS
-----------------------------------------------------------------------

function UI:GetDialogTextWidth()
    if not COMPUTED.DIALOG_TEXT_WIDTH then
        local base = COMPUTED.DIALOG_CONTENT_WIDTH
        if CONFIG.DIALOG.TEXT_WIDTH_OVERRIDE then
            base = CONFIG.DIALOG.TEXT_WIDTH_OVERRIDE
        end
        COMPUTED.DIALOG_TEXT_WIDTH = base + CONFIG.DIALOG.TEXT_EXTRA_PADDING_RIGHT
    end
    return COMPUTED.DIALOG_TEXT_WIDTH
end

-----------------------------------------------------------------------
-- GENERIC DIALOG FRAME LAYOUT
-----------------------------------------------------------------------

function UI:ApplyDialogFrame(frame)
    if not frame then return end

    frame:SetWidth(CONFIG.DIALOG.FRAME_WIDTH)
    frame:SetHeight(CONFIG.DIALOG.FRAME_HEIGHT)
    frame:ClearAllPoints()
    frame:SetPoint(
        CONFIG.DIALOG.ANCHOR_POINT,
        UIParent,
        CONFIG.DIALOG.ANCHOR_RELATIVE,
        CONFIG.DIALOG.OFFSET_X,
        CONFIG.DIALOG.OFFSET_Y
    )
end

-----------------------------------------------------------------------
-- GENERIC SCROLL FRAME LAYOUT
-----------------------------------------------------------------------

function UI:ApplyScrollFrame(scrollFrame, height)
    if not scrollFrame then return end
    Config = Utils:GetConfig()


    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint(
        "TOPLEFT",
        scrollFrame:GetParent(),
        "TOPLEFT",
        CONFIG.DIALOG.CONTENT_MARGIN_LEFT,
        -CONFIG.DIALOG.CONTENT_MARGIN_TOP
    )
    scrollFrame:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
    scrollFrame:SetHeight(height)
end

function UI:ApplyScrollChild(scrollChild)
    if scrollChild then
        scrollChild:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
    end
end

function UI:ApplyScrollbar(scrollFrame, scrollbar)
    if not scrollFrame or not scrollbar then return end

    scrollbar:ClearAllPoints()
    scrollbar:SetPoint(
        "TOPRIGHT",
        scrollFrame,
        "TOPRIGHT",
        CONFIG.DIALOG.SCROLLBAR_OFFSET_X,
        -CONFIG.DIALOG.SCROLLBAR_OFFSET_TOP
    )
    scrollbar:SetPoint(
        "BOTTOMRIGHT",
        scrollFrame,
        "BOTTOMRIGHT",
        CONFIG.DIALOG.SCROLLBAR_OFFSET_X,
        CONFIG.DIALOG.SCROLLBAR_OFFSET_BOTTOM
    )
end

-----------------------------------------------------------------------
-- GOSSIP BUTTON RESIZE (Blizzard callback)
-----------------------------------------------------------------------
-- MUST be global — Blizzard calls this by name

function GossipResize(titleButton)
    if not titleButton then return end

    titleButton:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
    titleButton:SetHeight(
        titleButton:GetTextHeight()
        + CONFIG.DIALOG.GOSSIP_BUTTON_HEIGHT_PADDING
    )

    local text = getglobal(titleButton:GetName() .. "Text")
    if text then
        text:ClearAllPoints()
        text:SetPoint(
            "LEFT",
            titleButton,
            "LEFT",
            CONFIG.DIALOG.GOSSIP_BUTTON_TEXT_LEFT,
            0
        )
        text:SetWidth(
            COMPUTED.DIALOG_CONTENT_WIDTH
            - CONFIG.DIALOG.GOSSIP_BUTTON_TEXT_LEFT
            - CONFIG.DIALOG.GOSSIP_BUTTON_TEXT_RIGHT
        )
        text:SetJustifyH("LEFT")
    end

    local icon = getglobal(titleButton:GetName() .. "GossipIcon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint(
            "LEFT",
            titleButton,
            "LEFT",
            CONFIG.DIALOG.GOSSIP_BUTTON_ICON_LEFT,
            0
        )
    end
end

-----------------------------------------------------------------------
-- PORTRAIT HELPERS
-----------------------------------------------------------------------

function UI:UpdateNPCPortrait(frame)
    if PortraitManager then
        PortraitManager:UpdateNPCPortrait(frame)
    end
end

function UI:HidePortrait(frame)
    if PortraitManager then
        PortraitManager:HidePortrait(frame)
    end
end

-----------------------------------------------------------------------
-- GOSSIP FRAME LAYOUT
-----------------------------------------------------------------------

local function ApplyGossipLayout()
    if not GossipFrame then return end

    UI:ApplyDialogFrame(GossipFrame)
    UI:UpdateNPCPortrait(GossipFrame)

    UI:ApplyScrollFrame(
        GossipGreetingScrollFrame,
        CONFIG.DIALOG.SCROLL_HEIGHT_GOSSIP
    )

    UI:ApplyScrollChild(GossipGreetingScrollChildFrame)
    UI:ApplyScrollbar(
        GossipGreetingScrollFrame,
        GossipGreetingScrollFrameScrollBar
    )
end

-----------------------------------------------------------------------
-- SOUNDQUEUE → GOSSIP PORTRAIT HOOK
-----------------------------------------------------------------------

local function HookGossipSoundQueue()
    if not SoundQueue then return end

    SoundQueue.OnVoiceStart = function(_, data)
        if not data then return end
        if data.dialog_type ~= "gossip" then return end

        if PortraitManager and data.npc_name then
            PortraitManager:SetActiveNPC(data.npc_name)
        end

        UI:UpdateNPCPortrait(GossipFrame)
    end

    SoundQueue.OnVoiceStop = function()
        UI:HidePortrait(GossipFrame)
    end
end

-----------------------------------------------------------------------
-- EVENTS
-----------------------------------------------------------------------

local gossipEventFrame = CreateFrame("Frame")
gossipEventFrame:RegisterEvent("GOSSIP_SHOW")
gossipEventFrame:RegisterEvent("GOSSIP_CLOSED")

gossipEventFrame:SetScript("OnEvent", function()
    if event == "GOSSIP_CLOSED" then
        UI:HidePortrait(GossipFrame)
        return
    end

    this:SetScript("OnUpdate", function()
        ApplyGossipLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

-----------------------------------------------------------------------
-- BLIZZARD OVERRIDES
-----------------------------------------------------------------------

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

local originalGossipOnShow = GossipFrame:GetScript("OnShow")
GossipFrame:SetScript("OnShow", function()
    if originalGossipOnShow then
        originalGossipOnShow()
    end
    ApplyGossipLayout()
end)

-----------------------------------------------------------------------
-- DELAYED INIT (PFUI SAFE)
-----------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
local timer = 0

initFrame:SetScript("OnUpdate", function()
    timer = timer + arg1
    if timer > 0.5 then
        ApplyGossipLayout()
        HookGossipSoundQueue()
        this:SetScript("OnUpdate", nil)
    end
end)
