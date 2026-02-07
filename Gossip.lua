-- =====================================================================
--   SECTION 4 — GossipFrame Layout (PFUI-Compatible)
-- =====================================================================

do  -- block-scope

local function EnsureGossipPortrait(parent)
    if parent.widePortrait then return parent.widePortrait end

    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetWidth(CONFIG.DIALOG.PORTRAIT_WIDTH)
    portrait:SetHeight(CONFIG.DIALOG.PORTRAIT_HEIGHT)
    portrait:SetPoint("TOPLEFT", parent, "TOPLEFT",
        CONFIG.DIALOG.PORTRAIT_OFFSET_X, -CONFIG.DIALOG.PORTRAIT_OFFSET_Y)

    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints()
    portrait.bg:SetTexture(0, 0, 0, 0)  -- Transparent - let PFUI handle backgrounds

    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints()
    portrait.texture:SetTexCoord(0, 1, 0, 1)

    parent.widePortrait = portrait
    return portrait
end

local function UpdateGossipPortrait()
    if not GossipFrame then return end
    if PortraitManager then
        PortraitManager:UpdateNPCPortrait(GossipFrame)
        return
    end
    -- Fallback if PortraitManager somehow isn't loaded
    local portrait = EnsureGossipPortrait(GossipFrame)
    portrait.texture:SetTexture("Interface\\CharacterFrame\\TempPortrait")
    portrait:Show()
end

local function HideGossipPortrait()
    if GossipFrame and GossipFrame.widePortrait then
        GossipFrame.widePortrait:Hide()
    end
end

local function ApplyGossipLayout()
    if not GossipFrame then return end
    local backdrop = GossipFrame.backdrop or GossipFrame

    GossipFrame:SetWidth(CONFIG.DIALOG.FRAME_WIDTH)
    GossipFrame:SetHeight(CONFIG.DIALOG.FRAME_HEIGHT)
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint(CONFIG.DIALOG.ANCHOR_POINT, UIParent, CONFIG.DIALOG.ANCHOR_RELATIVE,
        CONFIG.DIALOG.OFFSET_X, CONFIG.DIALOG.OFFSET_Y)

    -- Update portrait (no custom background - let PFUI handle it)
    UpdateGossipPortrait()

    if GossipGreetingScrollFrame then
        GossipGreetingScrollFrame:ClearAllPoints()
        GossipGreetingScrollFrame:SetPoint("TOPLEFT", backdrop, "TOPLEFT",
            CONFIG.DIALOG.CONTENT_MARGIN_LEFT, -CONFIG.DIALOG.CONTENT_MARGIN_TOP)
        GossipGreetingScrollFrame:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
        GossipGreetingScrollFrame:SetHeight(CONFIG.DIALOG.SCROLL_HEIGHT_GOSSIP)
    end

    if GossipGreetingScrollChildFrame then
        GossipGreetingScrollChildFrame:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
    end

    if GossipGreetingScrollFrameScrollBar then
        GossipGreetingScrollFrameScrollBar:ClearAllPoints()
        GossipGreetingScrollFrameScrollBar:SetPoint("TOPRIGHT",
            GossipGreetingScrollFrame, "TOPRIGHT",
            CONFIG.DIALOG.SCROLLBAR_OFFSET_X, -CONFIG.DIALOG.SCROLLBAR_OFFSET_TOP)
        GossipGreetingScrollFrameScrollBar:SetPoint("BOTTOMRIGHT",
            GossipGreetingScrollFrame, "BOTTOMRIGHT",
            CONFIG.DIALOG.SCROLLBAR_OFFSET_X, CONFIG.DIALOG.SCROLLBAR_OFFSET_BOTTOM)
    end
end

-- GossipResize: MUST be global — Blizzard's GossipFrame calls it by name
function GossipResize(titleButton)
    if not titleButton then return end

    titleButton:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
    titleButton:SetHeight(titleButton:GetTextHeight() + CONFIG.DIALOG.GOSSIP_BUTTON_HEIGHT_PADDING)

    local text = getglobal(titleButton:GetName() .. "Text")
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", titleButton, "LEFT", CONFIG.DIALOG.GOSSIP_BUTTON_TEXT_LEFT, 0)
        text:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH 
            - CONFIG.DIALOG.GOSSIP_BUTTON_TEXT_LEFT 
            - CONFIG.DIALOG.GOSSIP_BUTTON_TEXT_RIGHT)
        text:SetJustifyH("LEFT")
    end

    local icon = getglobal(titleButton:GetName() .. "GossipIcon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", titleButton, "LEFT", CONFIG.DIALOG.GOSSIP_BUTTON_ICON_LEFT, 0)
    end
end

-- SoundQueue hook for gossip portraits
local function HookGossipSoundQueue()
    if not SoundQueue then return end

    SoundQueue.OnVoiceStart = function(_, data)
        if not data then return end
        if data.dialog_type ~= "gossip" then return end
        if PortraitManager and data.npc_name then
            PortraitManager:SetActiveNPC(data.npc_name)
        end
        UpdateGossipPortrait()
    end

    SoundQueue.OnVoiceStop = function()
        HideGossipPortrait()
    end
end

-- Events
local gossipEventFrame = CreateFrame("Frame")
gossipEventFrame:RegisterEvent("GOSSIP_SHOW")
gossipEventFrame:RegisterEvent("GOSSIP_CLOSED")

gossipEventFrame:SetScript("OnEvent", function()
    if event == "GOSSIP_CLOSED" then
        HideGossipPortrait()
        return
    end
    this:SetScript("OnUpdate", function()
        ApplyGossipLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

-- Override GossipFrameUpdate so layout re-applies when Blizzard refreshes buttons
local OriginalGossipFrameUpdate = GossipFrameUpdate
function GossipFrameUpdate()
    if OriginalGossipFrameUpdate then OriginalGossipFrameUpdate() end
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
        ApplyGossipLayout()
        this:SetScript("OnUpdate", nil)
    end)
end

-- OnShow hook
local originalGossipOnShow = GossipFrame:GetScript("OnShow")
GossipFrame:SetScript("OnShow", function()
    if originalGossipOnShow then originalGossipOnShow() end
    ApplyGossipLayout()
end)

-- Delayed init
local gossipInitFrame = CreateFrame("Frame")
local gossipInitTimer = 0
gossipInitFrame:SetScript("OnUpdate", function()
    gossipInitTimer = gossipInitTimer + arg1
    if gossipInitTimer > 0.5 then
        ApplyGossipLayout()
        HookGossipSoundQueue()
        this:SetScript("OnUpdate", nil)
    end
end)

end  -- end GossipFrame do-block
