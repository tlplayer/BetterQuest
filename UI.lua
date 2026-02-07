-- ui.lua
-- Every frame, layout hook, portrait, and UI-update callback lives here.
-- Load order: 3 of 4  (utils → soundqueue → ui → core)
--
-- UPDATED: Configuration-first design with shared configs
--
-- Globals exported:
--   PortraitManager          — unified portrait module
--   GossipResize(titleButton)— called by Blizzard's gossip UI, MUST be global
--
-- Attaches onto SoundQueue (must already exist):
--   SoundQueue:InitializeUI()
--   SoundQueue:UpdatePortrait(soundData)
--   SoundQueue:UpdateCurrentInfo(soundData)
--   SoundQueue:UpdatePauseButton()
--   SoundQueue:UpdateStatusText()
--   SoundQueue:UpdateQueueList()
--   SoundQueue:ShowFrame()
--   SoundQueue:HideFrame()
--
-- External dependencies:
--   Debug, NormalizeDialogText, IsBookInteraction   ← utils.lua
--   SoundQueue                                      ← soundqueue.lua
--   GetNPCMetadata, NPC_DATABASE                    ← data layer (external)

-- =====================================================================
--   CONFIGURATION — All settings in one place at the top
-- =====================================================================

local CONFIG = {
    -- ================================================================
    -- SHARED DIALOG CONFIGURATION (Quest & Gossip)
    -- ================================================================
    DIALOG = {
        -- Frame dimensions
        FRAME_WIDTH  = 700,
        FRAME_HEIGHT = 400,
        
        -- Frame positioning
        ANCHOR_POINT    = "BOTTOM",
        ANCHOR_RELATIVE = "BOTTOM",
        OFFSET_X = 30,
        OFFSET_Y = -60,
        
        -- Portrait configuration
        PORTRAIT_WIDTH  = 160,
        PORTRAIT_HEIGHT = 260,
        PORTRAIT_OFFSET_X = 30,
        PORTRAIT_OFFSET_Y = 60,
        
        -- Content area (margins from frame edges)
        CONTENT_MARGIN_LEFT  = 200,  -- Space for portrait on left
        CONTENT_MARGIN_RIGHT = 60,
        CONTENT_MARGIN_TOP   = 60,
        CONTENT_MARGIN_BOTTOM = 100,
        
        -- Text area (can differ from content area)
        TEXT_WIDTH_OVERRIDE = 600,  -- Set to number to override, nil uses content width
        TEXT_EXTRA_PADDING_RIGHT = 0,
        TEXT_JUSTIFY = "LEFT",
        
        -- Scroll frame heights by dialog type
        SCROLL_HEIGHT_DETAIL   = 250,
        SCROLL_HEIGHT_PROGRESS = 250,
        SCROLL_HEIGHT_REWARD   = 230,
        SCROLL_HEIGHT_GREETING = 250,
        SCROLL_HEIGHT_GOSSIP   = 250,
        
        -- Button positioning
        BUTTON_OFFSET_X = 80,   -- Distance from center
        BUTTON_OFFSET_Y = 30,   -- Distance from bottom
        CLOSE_OFFSET_X  = 15,   -- Distance from right edge
        CLOSE_OFFSET_Y  = 15,   -- Distance from top edge
        
        -- Gossip-specific button config
        GOSSIP_BUTTON_HEIGHT_PADDING = 4,
        GOSSIP_BUTTON_TEXT_LEFT      = 25,
        GOSSIP_BUTTON_TEXT_RIGHT     = 5,
        GOSSIP_BUTTON_ICON_LEFT      = 3,
        
        -- Scrollbar positioning
        SCROLLBAR_OFFSET_X      = -20,
        SCROLLBAR_OFFSET_TOP    = 16,
        SCROLLBAR_OFFSET_BOTTOM = 16,
    },
    
    -- ================================================================
    -- PORTRAIT MANAGER CONFIGURATION
    -- ================================================================
    PORTRAIT = {
        DEBUG = false,
        
        -- Default textures by type
        DEFAULT_NPC    = "Interface\\AddOns\\BetterQuest\\portraits\\default.tga",
        DEFAULT_BOOK   = "Interface\\Icons\\INV_Misc_Book_09",
        DEFAULT_ITEM   = "Interface\\Icons\\INV_Misc_QuestionMark",
        DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",
        
        -- Portrait path
        PORTRAIT_PATH = "Interface\\AddOns\\BetterQuest\\portraits\\",
    },
    
    -- ================================================================
    -- BOOK/NOTE/LETTER CONFIGURATION
    -- ================================================================
    BOOK = {
        FRAME_WIDTH  = 620,
        FRAME_HEIGHT = 400,
        
        ANCHOR_POINT    = "BOTTOM",
        ANCHOR_RELATIVE = "BOTTOM",
        OFFSET_X = 0,
        OFFSET_Y = -60,
        
        MARGIN_LEFT   = 30,
        MARGIN_RIGHT  = 50,
        MARGIN_TOP    = 40,
        MARGIN_BOTTOM = 120,
        
        TEXT_RIGHT_PADDING = 40,
    },
    
    -- ================================================================
    -- SOUND QUEUE MINI-PLAYER CONFIGURATION
    -- ================================================================
    SOUNDQUEUE = {
        FRAME_WIDTH  = 300,
        FRAME_HEIGHT = 80,
        
        ANCHOR_POINT = "BOTTOMRIGHT",
        OFFSET_X = -20,
        OFFSET_Y = 100,
        
        PORTRAIT_SIZE = 60,
        PORTRAIT_LEFT = 10,
        
        INFO_LEFT = 80,
        INFO_TOP_NPC = -15,
        INFO_TOP_TITLE = -35,
        INFO_WIDTH = 180,
        
        STATUS_LEFT = 80,
        STATUS_BOTTOM = 15,
        
        QUEUE_LEFT = 80,
        QUEUE_TOP = -55,
        QUEUE_WIDTH = 200,
        QUEUE_HEIGHT = 80,
        QUEUE_MAX_DISPLAY = 5,
        QUEUE_BUTTON_HEIGHT = 15,
        QUEUE_BUTTON_SPACING = 16,
        
        CLOSE_BUTTON_SIZE = 20,
        CONTROL_BUTTON_SIZE = 24,
        BACK_BUTTON_SIZE = 20,
        
        BACK_BUTTON_RIGHT = -50,
        BACK_BUTTON_BOTTOM = 10,
        
        PAUSE_BUTTON_RIGHT = -25,
        PAUSE_BUTTON_BOTTOM = 8,
        
        BG_ALPHA = 0.7,
    },
}



-- Helper to get text width (allows override)
local function GetDialogTextWidth()
    if not COMPUTED.DIALOG_TEXT_WIDTH then
        local base = COMPUTED.DIALOG_CONTENT_WIDTH
        if CONFIG.DIALOG.TEXT_WIDTH_OVERRIDE then
            base = CONFIG.DIALOG.TEXT_WIDTH_OVERRIDE
        end
        COMPUTED.DIALOG_TEXT_WIDTH = base + CONFIG.DIALOG.TEXT_EXTRA_PADDING_RIGHT
    end
    return COMPUTED.DIALOG_TEXT_WIDTH
end

-- =====================================================================
--   PFUI COMPATIBILITY
-- =====================================================================

-- Makes any frame fully transparent and removes its background
local function MakeFrameTransparent(frame)
    if not frame then return end

    -- Remove the background texture if it exists
    if frame.bg and frame.bg.SetTexture then
        frame.bg:SetTexture(nil)
        frame.bg:Hide()
    end

    -- Remove all texture regions in the frame
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:Hide()
        end
    end

    -- Make the frame itself fully transparent
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
end


-- =====================================================================
--   SECTION 1 — PortraitManager
-- =====================================================================

-------------------------------------------------------------------------
-- PORTRAIT MANAGER  (replaces the two identical copies in the old code)
-------------------------------------------------------------------------
PortraitManager = {}
PortraitManager.Type = {
    NPC    = "npc",
    BOOK   = "book",
    ITEM   = "item",
    OBJECT = "object",
    CUSTOM = "custom",
}
PortraitManager.DEBUG = CONFIG.PORTRAIT.DEBUG

-- Module-private state
local currentPortrait = {
    type    = nil,
    texture = nil,
    frame   = nil,
}
local activeNPCName = nil

-- Debug helper scoped to PortraitManager
local function PMDebug(msg)
    if PortraitManager.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. msg)
    end
end

-- Build "portraits/race.tga" or "portraits/race_female.tga"
local function BuildPortraitPath(race, sex)
    if not race or race == "" then return CONFIG.PORTRAIT.DEFAULT_NPC end
    local filename = race
    if sex == "female" then filename = filename .. "_female" end
    return CONFIG.PORTRAIT.PORTRAIT_PATH .. filename .. ".tga"
end

-- Get-or-create the wide portrait sub-frame on any parent.
-- Reuses an existing one; only creates if absent.
local function GetOrCreatePortraitFrame(parentFrame)
    if not parentFrame then return nil end
    if parentFrame.widePortrait then return parentFrame.widePortrait end

    local portrait = CreateFrame("Frame", nil, parentFrame)
    portrait:SetWidth(CONFIG.DIALOG.PORTRAIT_WIDTH)
    portrait:SetHeight(CONFIG.DIALOG.PORTRAIT_HEIGHT)
    portrait:SetPoint("TOPLEFT", parentFrame, "TOPLEFT",
        CONFIG.DIALOG.PORTRAIT_OFFSET_X, -CONFIG.DIALOG.PORTRAIT_OFFSET_Y)

    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints()
    portrait.bg:SetTexture(0, 0, 0, 0)  -- Transparent - let PFUI handle backgrounds
    
    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints()
    portrait.texture:SetTexCoord(0, 1, 0, 1)

    parentFrame.widePortrait = portrait
    currentPortrait.frame = parentFrame
    return portrait
end

-------------------------------------------------------------------------
-- NPC CONTROL
-------------------------------------------------------------------------
function PortraitManager:SetActiveNPC(name)
    activeNPCName = name
    PMDebug("Active NPC set: " .. tostring(name))
end

function PortraitManager:ClearActiveNPC()
    activeNPCName = nil
end

function PortraitManager:GetNPCInfo()
    local name = activeNPCName or UnitName("npc") or UnitName("target") 
    local normalizedName = NormalizeNPCName(name)

    local metadata = GetNPCMetadata and GetNPCMetadata(normalizedName)
    if not metadata then
        PMDebug("No metadata found for: " .. tostring(name))
        return nil
    end

    return {
        name     = normalizedName,
        race     = metadata.race     or "unknown",
        sex      = metadata.sex      or "male",
        portrait = metadata.portrait or metadata.race or "default",
        zone     = metadata.zone     or GetZoneText() or "Unknown",
        model_id = metadata.model_id,
        narrator = metadata.narrator or "default",
    }
end

function PortraitManager:FindNPCPortrait()
    local npc = self:GetNPCInfo()
    if not npc then
        PMDebug("No NPC info available, using default")
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end
    if npc.race and npc.race ~= "" then
        local path = BuildPortraitPath(npc.race, npc.sex)
        PMDebug("Using portrait: " .. path)
        return path
    end
    PMDebug("No race found, using default")
    return CONFIG.PORTRAIT.DEFAULT_NPC
end

function PortraitManager:FindNPCPortraitByKey(key)
    if not key or key == "" then return CONFIG.PORTRAIT.DEFAULT_NPC end
    return CONFIG.PORTRAIT.PORTRAIT_PATH .. key .. ".tga"
end
