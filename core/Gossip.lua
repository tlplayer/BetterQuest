-- =====================================================================
--   SECTION 4 — GossipFrame Layout (PFUI-Compatible, UI-driven)
-- =====================================================================

do  -- block-scope

-----------------------------------------------------------------------
-- CORE LAYOUT
-----------------------------------------------------------------------

local function ApplyGossipLayout()
    if not GossipFrame then return end

    -- Frame + positioning
    UI:ApplyDialogFrame(GossipFrame)

    -- Portrait
    UI:UpdateNPCPortrait(GossipFrame)

    -- Scroll frame
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
-- Blizzard callback (MUST be global)
-----------------------------------------------------------------------

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
-- SOUNDQUEUE → PORTRAIT BRIDGE
-----------------------------------------------------------------------

local function HookGossipSoundQueue()
    if not SoundQueue then return end

    SoundQueue.OnVoiceStart = function(_, data)
        if not data or data.dialog_type ~= "gossip" then return end

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
-- BLIZZARD REFRESH OVERRIDES
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

end  -- end GossipFrame do-block
