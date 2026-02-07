-- ui.lua
-- Every frame, layout hook, portrait, and UI-update callback lives here.
-- Load order: 3 of 4  (utils → soundqueue → ui → core)
--
-- UPDATED: Configuration-first design with shared DialogLayout engine
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
        FRAME_WIDTH  = 800,
        FRAME_HEIGHT = 450,
        
        -- Frame positioning
        ANCHOR_POINT    = "BOTTOM",
        ANCHOR_RELATIVE = "BOTTOM",
        OFFSET_X = 30,
        OFFSET_Y = -60,
        
        -- Portrait configuration
        PORTRAIT_WIDTH  = 160,
        PORTRAIT_HEIGHT = 240,
        PORTRAIT_OFFSET_X = 90,
        PORTRAIT_OFFSET_Y = 95,
        
        -- Content area (margins from frame edges)
        CONTENT_MARGIN_LEFT  = 270,  -- Space for portrait on left
        CONTENT_MARGIN_RIGHT = 80,
        CONTENT_MARGIN_TOP   = 80,
        CONTENT_MARGIN_BOTTOM = 60,
        
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
        BUTTON_OFFSET_X = 80,   -- Distance from center (left/right buttons)
        BUTTON_OFFSET_Y = 30,   -- Distance from bottom (all action buttons)
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

-- Computed values (derived from config)
local COMPUTED = {
    DIALOG_CONTENT_WIDTH = CONFIG.DIALOG.FRAME_WIDTH 
        - CONFIG.DIALOG.CONTENT_MARGIN_LEFT 
        - CONFIG.DIALOG.CONTENT_MARGIN_RIGHT,
        
    DIALOG_CONTENT_HEIGHT = CONFIG.DIALOG.FRAME_HEIGHT 
        - CONFIG.DIALOG.CONTENT_MARGIN_TOP 
        - CONFIG.DIALOG.CONTENT_MARGIN_BOTTOM,
        
    DIALOG_TEXT_WIDTH = nil,  -- Computed in GetDialogTextWidth()
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
--   DIALOG LAYOUT ENGINE — Shared logic for Quest/Gossip/Book
-- =====================================================================

local DialogLayout = {}

-- Unified portrait update
function DialogLayout:UpdatePortrait(frame, portraitType, customKey)
    if not PortraitManager or not frame then return end
    PortraitManager:SetPortrait(frame, portraitType or PortraitManager.Type.NPC, customKey)
end

-- Unified portrait hide
function DialogLayout:HidePortrait(frame)
    if PortraitManager then
        PortraitManager:HidePortrait(frame)
    end
end

-- Unified SoundQueue hook for dialogs (CHAINED, not overwriting)
function DialogLayout:HookSoundQueue(dialogType, frame)
    if not SoundQueue then return end

    -- Chain OnVoiceStart
    local prevStart = SoundQueue.OnVoiceStart
    SoundQueue.OnVoiceStart = function(self, data)
        if prevStart then prevStart(self, data) end
        
        if data and data.dialog_type == dialogType then
            if data.npc_name then
                PortraitManager:SetActiveNPC(data.npc_name)
            end
            DialogLayout:UpdatePortrait(frame)
        end
    end

    -- Chain OnVoiceStop
    local prevStop = SoundQueue.OnVoiceStop
    SoundQueue.OnVoiceStop = function(self)
        if prevStop then prevStop(self) end
        DialogLayout:HidePortrait(frame)
    end
end

-- =====================================================================
--   UNIVERSAL FRAME LAYOUT (Quest/Gossip/Book unified)
-- =====================================================================

local function ApplyFrameLayout(frameObj)
    if not frameObj or not frameObj.frame or not frameObj.type then return end

    local f = frameObj.frame
    local frameType = frameObj.type
    local scrollFrames = frameObj.scrollFrames or {}
    local portrait = frameObj.portrait
    local buttons = frameObj.buttons or {}
    local backdrop = frameObj.backdrop or f
    local textFields = frameObj.textFields or {}

    -- Main frame sizing & anchoring
    if frameType == "Quest" or frameType == "Gossip" then
        f:SetWidth(CONFIG.DIALOG.FRAME_WIDTH)
        f:SetHeight(CONFIG.DIALOG.FRAME_HEIGHT)
        f:ClearAllPoints()
        f:SetPoint(CONFIG.DIALOG.ANCHOR_POINT, UIParent, CONFIG.DIALOG.ANCHOR_RELATIVE, 
            CONFIG.DIALOG.OFFSET_X, CONFIG.DIALOG.OFFSET_Y)
    elseif frameType == "Book" or frameType == "ItemText" then
        f:SetWidth(CONFIG.BOOK.FRAME_WIDTH)
        f:SetHeight(CONFIG.BOOK.FRAME_HEIGHT)
        f:ClearAllPoints()
        f:SetPoint(CONFIG.BOOK.ANCHOR_POINT, UIParent, CONFIG.BOOK.ANCHOR_RELATIVE, 
            CONFIG.BOOK.OFFSET_X, CONFIG.BOOK.OFFSET_Y)
    end

    -- Portrait
    if portrait and portrait:IsVisible then
        portrait:ClearAllPoints()
        if frameType == "Quest" or frameType == "Gossip" then
            portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 
                CONFIG.DIALOG.PORTRAIT_OFFSET_X, -CONFIG.DIALOG.PORTRAIT_OFFSET_Y)
            portrait:SetWidth(CONFIG.DIALOG.PORTRAIT_WIDTH)
            portrait:SetHeight(CONFIG.DIALOG.PORTRAIT_HEIGHT)
        elseif frameType == "Book" or frameType == "ItemText" then
            portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 
                CONFIG.BOOK.MARGIN_LEFT, -CONFIG.BOOK.MARGIN_TOP)
            portrait:SetWidth(CONFIG.BOOK.FRAME_WIDTH - CONFIG.BOOK.MARGIN_LEFT - CONFIG.BOOK.MARGIN_RIGHT)
            portrait:SetHeight(CONFIG.BOOK.FRAME_HEIGHT - CONFIG.BOOK.MARGIN_TOP - CONFIG.BOOK.MARGIN_BOTTOM)
        end
    end

    -- ScrollFrames
    for _, s in ipairs(scrollFrames) do
        if s.frame then
            s.frame:ClearAllPoints()
            local parent = backdrop
            if frameType == "Quest" or frameType == "Gossip" then
                s.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 
                    CONFIG.DIALOG.CONTENT_MARGIN_LEFT, -CONFIG.DIALOG.CONTENT_MARGIN_TOP)
                s.frame:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
                s.frame:SetHeight(s.height or 200)
            elseif frameType == "Book" or frameType == "ItemText" then
                local width  = parent:GetWidth()  - CONFIG.BOOK.MARGIN_LEFT - CONFIG.BOOK.MARGIN_RIGHT
                local height = parent:GetHeight() - CONFIG.BOOK.MARGIN_TOP  - CONFIG.BOOK.MARGIN_BOTTOM
                s.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 
                    CONFIG.BOOK.MARGIN_LEFT, -CONFIG.BOOK.MARGIN_TOP)
                s.frame:SetWidth(width)
                s.frame:SetHeight(height)
            end
            if s.child then s.child:SetWidth(s.frame:GetWidth()) end
        end
    end

    -- Buttons (bottom-anchored for Quest/Gossip)
    local yOffset = 0
    for _, btn in ipairs(buttons) do
        if btn and btn:IsVisible then
            btn:ClearAllPoints()
            if frameType == "Quest" or frameType == "Gossip" then
                local xOffset = ((yOffset % 2 == 0) and -CONFIG.DIALOG.BUTTON_OFFSET_X or CONFIG.DIALOG.BUTTON_OFFSET_X)
                btn:SetPoint("BOTTOM", backdrop, "BOTTOM", xOffset, CONFIG.DIALOG.BUTTON_OFFSET_Y)
                yOffset = yOffset + 1
            end
        end
    end

    -- Close button
    if frameObj.closeButton then
        frameObj.closeButton:ClearAllPoints()
        frameObj.closeButton:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 
            -CONFIG.DIALOG.CLOSE_OFFSET_X, -CONFIG.DIALOG.CLOSE_OFFSET_Y)
    end

    -- Text fields
    for _, ftext in ipairs(textFields) do
        if ftext then
            local width = GetDialogTextWidth()
            ftext:SetWidth(width)
            ftext:SetJustifyH(CONFIG.DIALOG.TEXT_JUSTIFY)
        end
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


-------------------------------------------------------------------------
-- BOOK PORTRAITS
-------------------------------------------------------------------------
function PortraitManager:FindBookPortrait(itemName)
    if BookDB and BookDB.portraits and itemName then
        if BookDB.portraits[itemName] then
            return BookDB.portraits[itemName]
        end
    end
    return CONFIG.PORTRAIT.DEFAULT_BOOK
end

-------------------------------------------------------------------------
-- DISPLAY
-------------------------------------------------------------------------
function PortraitManager:SetPortrait(parentFrame, portraitType, customTexture)
    local portrait = GetOrCreatePortraitFrame(parentFrame)
    if not portrait then return false end

    local texturePath
    if customTexture then
        texturePath = customTexture
    elseif portraitType == self.Type.NPC then
        texturePath = self:FindNPCPortrait()
    elseif portraitType == self.Type.BOOK then
        texturePath = CONFIG.PORTRAIT.DEFAULT_BOOK
    elseif portraitType == self.Type.ITEM then
        texturePath = CONFIG.PORTRAIT.DEFAULT_ITEM
    elseif portraitType == self.Type.OBJECT then
        texturePath = CONFIG.PORTRAIT.DEFAULT_OBJECT
    else
        texturePath = CONFIG.PORTRAIT.DEFAULT_NPC
    end

    -- Validate before calling SetTexture
    if type(texturePath) == "string" and texturePath ~= "" then
        portrait.texture:SetTexture(texturePath)
    else
        PMDebug("BLOCKED bad texture path: " .. tostring(texturePath))
        portrait.texture:SetTexture(CONFIG.PORTRAIT.DEFAULT_NPC)
    end

    local success, err = pcall(function() portrait:Show() end)
    if not success then
        PMDebug("ERROR showing portrait: " .. tostring(err))
        return false
    end

    currentPortrait.type    = portraitType
    currentPortrait.texture = texturePath
    currentPortrait.frame   = parentFrame

    PMDebug("Portrait set: " .. texturePath)
    return true
end

function PortraitManager:UpdateNPCPortrait(parentFrame)
    return self:SetPortrait(parentFrame or QuestFrame, self.Type.NPC)
end

function PortraitManager:UpdateBookPortrait(parentFrame, itemName)
    local tex = self:FindBookPortrait(itemName)
    return self:SetPortrait(parentFrame or ItemTextFrame, self.Type.BOOK, tex)
end

function PortraitManager:HidePortrait(parentFrame)
    local f = parentFrame or currentPortrait.frame
    if f and f.widePortrait then
        f.widePortrait:Hide()
    end
    currentPortrait.type    = nil
    currentPortrait.texture = nil
    currentPortrait.frame   = nil
end


function PortraitManager:Initialize()
    PMDebug("PortraitManager initialized")
    if not NPC_DATABASE then
        print("|cffff0000[PortraitManager]|r WARNING: NPC_DATABASE not loaded!")
    else
        PMDebug("NPC_DATABASE loaded successfully")
    end
end

-- Boot immediately so it is ready before any frame hooks fire
PortraitManager:Initialize()


-- =====================================================================
--   SECTION 2 — SoundQueue Mini-Player UI (Pipeline Architecture)
--         (attached onto the SoundQueue table)
-- =====================================================================

-- UI INVARIANTS (LIFECYCLE-AWARE):
-- 1. RefreshUI() guarantees UI exists (calls InitializeUI if needed)
-- 2. Queue (sounds[]) is the source of truth for visibility
-- 3. Only RefreshUI() may update multiple UI regions
-- 4. Render stages must not mutate SoundQueue state
-- 5. State-mutating functions must call RefreshUI()
-- 6. No UI mutation outside pipeline stages

-------------------------------------------------------------------------
-- COMPONENT BASE (Lua 5.0 compatible interface pattern)
-------------------------------------------------------------------------
local Component = {}
Component.__index = Component

function Component:new(o)
    return setmetatable(o or {}, self)
end

function Component:update(state) end
function Component:render(ui, state) end

-------------------------------------------------------------------------
-- HELPER: Portrait texture resolver
-------------------------------------------------------------------------
local function GetPortraitTexture(soundData)
    if not soundData or not soundData.npcName then
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end
    if IsBookInteraction() then
        return CONFIG.PORTRAIT.DEFAULT_BOOK
    end

    local metadata = GetNPCMetadata(soundData.npcName)
    if metadata and metadata.race and metadata.sex then
        local filename = metadata.race
        if metadata.sex == "female" then filename = filename .. "_female" end
        return CONFIG.PORTRAIT.PORTRAIT_PATH .. filename .. ".tga"
    end
    return CONFIG.PORTRAIT.DEFAULT_NPC
end

-------------------------------------------------------------------------
-- PIPELINE STAGES (Each is a Component)
-------------------------------------------------------------------------

-- Stage: Portrait
local PortraitStage = Component:new{}
function PortraitStage:render(ui, state)
    if not ui.portrait or not ui.portrait.texture then return end
    ui.portrait.texture:SetTexture(GetPortraitTexture(state.currentSound))
end

-- Stage: Current Info (NPC name + title)
local InfoStage = Component:new{}
function InfoStage:render(ui, state)
    -- FIX #3: Add nil guards
    if not ui.npcName or not ui.title then return end
    
    local current = state.currentSound
    ui.npcName:SetText(current and current.npcName or "")
    ui.title:SetText(current and current.title or "")
end

-- Stage: Pause/Play Button
local PauseButtonStage = Component:new{}
function PauseButtonStage:render(ui, state)
    -- FIX #3: Add nil guards
    if not ui.pauseBtn or not ui.pauseBtn.pauseIcon or not ui.pauseBtn.playIcon then return end
    
    if state.isPaused then
        ui.pauseBtn.pauseIcon:Hide()
        ui.pauseBtn.playIcon:Show()
    else
        ui.pauseBtn.pauseIcon:Show()
        ui.pauseBtn.playIcon:Hide()
    end
end

-- Stage: Status Text (elapsed / duration)
local StatusStage = Component:new{}
function StatusStage:render(ui, state)
    if not ui.statusText then return end
    
    local current = state.currentSound
    if not current then
        ui.statusText:SetText("")
        return
    end

    local elapsed = GetTime() - current.startTime
    if state.isPaused then
        elapsed = current.pauseOffset
    end

    ui.statusText:SetFormattedText("%.1fs / %.1fs", elapsed, current.duration)
end

-- Stage: Queue List
local QueueStage = Component:new{}
function QueueStage:render(ui, state)
    if not ui.queueButtons then return end

    for i, btn in ipairs(ui.queueButtons) do
        local soundData = state.sounds[i + 1]  -- skip currently playing

        if soundData then
            -- BUG FIX: Bind soundData directly, not index
            btn.soundData = soundData
            btn.text:SetText(string.format("%d. %s", i, soundData.npcName or "Unknown"))
            btn:Show()
        else
            btn.soundData = nil
            btn:Hide()
        end
    end
end

-- Stage: Frame Visibility
local VisibilityStage = Component:new{}
function VisibilityStage:render(ui, state)
    -- FIX #2: Queue is source of truth (sounds[1] = current)
    if table.getn(state.sounds) > 0 then
        ui:Show()
    else
        ui:Hide()
    end
end

-------------------------------------------------------------------------
-- PIPELINE REGISTRATION
-------------------------------------------------------------------------
SoundQueue.pipeline = {
    PortraitStage,
    InfoStage,
    PauseButtonStage,
    StatusStage,
    QueueStage,
    VisibilityStage,
}

-------------------------------------------------------------------------
-- SINGLE REFRESH CHOKE POINT
-------------------------------------------------------------------------
function SoundQueue:RefreshUI(reason)
    -- FIX #1: Guarantee UI exists (restore temporal invariant)
    if not self.frame then
        self:InitializeUI()
    end
    if not self.frame then return end  -- InitializeUI failed

    local state = {
        currentSound = self.currentSound,
        sounds       = self.sounds or {},
        isPaused     = self.isPaused,
    }

    -- Run all stages in order
    for _, stage in ipairs(self.pipeline) do
        if stage.update then stage:update(state) end
    end

    for _, stage in ipairs(self.pipeline) do
        if stage.render then stage:render(self.frame, state) end
    end

    if reason then
        Debug("UI refreshed: " .. reason)
    end
end

-------------------------------------------------------------------------
-- BACKWARDS COMPATIBILITY STUBS (called from soundqueue.lua)
-- FIX #5: Make these no-ops to avoid recursive refresh loops
-------------------------------------------------------------------------
function SoundQueue:UpdatePortrait()      end  -- Use RefreshUI() instead
function SoundQueue:UpdateCurrentInfo()   end  -- Use RefreshUI() instead
function SoundQueue:UpdatePauseButton()   end  -- Use RefreshUI() instead
function SoundQueue:UpdateStatusText()    end  -- Use RefreshUI() instead
function SoundQueue:UpdateQueueList()     end  -- Use RefreshUI() instead
function SoundQueue:ShowFrame()           if self.frame then self.frame:Show() end end
function SoundQueue:HideFrame()           if self.frame then self.frame:Hide() end end

-------------------------------------------------------------------------
-- QUEUE BUTTON SETUP (BUG FIX: Bind soundData, not index)
-------------------------------------------------------------------------
function SoundQueue:InitQueueList()
    -- BUG FIX: Compute correct container height
    local containerHeight = CONFIG.SOUNDQUEUE.QUEUE_MAX_DISPLAY 
        * CONFIG.SOUNDQUEUE.QUEUE_BUTTON_SPACING

    self.frame.queueContainer = CreateFrame("Frame", nil, self.frame)
    self.frame.queueContainer:SetPoint("TOPLEFT", 
        CONFIG.SOUNDQUEUE.QUEUE_LEFT, 
        -CONFIG.SOUNDQUEUE.QUEUE_TOP)
    self.frame.queueContainer:SetWidth(CONFIG.SOUNDQUEUE.QUEUE_WIDTH)
    self.frame.queueContainer:SetHeight(containerHeight)

    self.frame.queueButtons = {}
    for i = 1, CONFIG.SOUNDQUEUE.QUEUE_MAX_DISPLAY do
        local btn = CreateFrame("Button", nil, self.frame.queueContainer)
        btn:SetHeight(CONFIG.SOUNDQUEUE.QUEUE_BUTTON_HEIGHT)
        btn:SetWidth(CONFIG.SOUNDQUEUE.QUEUE_WIDTH - 20)
        btn:SetPoint("TOPLEFT", 0, -(i-1)*CONFIG.SOUNDQUEUE.QUEUE_BUTTON_SPACING)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetAllPoints()
        btn.text:SetJustifyH("LEFT")

        -- BUG FIX: Bind soundData directly in OnClick, not index
        btn:SetScript("OnClick", function()
            if this.soundData then
                SoundQueue:RemoveSound(this.soundData)
            end
        end)
        
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to remove from queue")
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:Hide()
        self.frame.queueButtons[i] = btn
    end
end

-------------------------------------------------------------------------
-- UI Construction
-------------------------------------------------------------------------
function SoundQueue:InitMainFrame()
    self.frame = CreateFrame("Frame", "BetterQuestSoundFrame", UIParent)
    self.frame:SetWidth(CONFIG.SOUNDQUEUE.FRAME_WIDTH)
    self.frame:SetHeight(CONFIG.SOUNDQUEUE.FRAME_HEIGHT)
    self.frame:SetPoint(CONFIG.SOUNDQUEUE.ANCHOR_POINT, 
        CONFIG.SOUNDQUEUE.OFFSET_X, 
        CONFIG.SOUNDQUEUE.OFFSET_Y)
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function() this:StartMoving() end)
    self.frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, CONFIG.SOUNDQUEUE.BG_ALPHA)
end

function SoundQueue:InitPortrait()
    self.frame.portrait = CreateFrame("Frame", nil, self.frame)
    self.frame.portrait:SetWidth(CONFIG.SOUNDQUEUE.PORTRAIT_SIZE)
    self.frame.portrait:SetHeight(CONFIG.SOUNDQUEUE.PORTRAIT_SIZE)
    self.frame.portrait:SetPoint("LEFT", CONFIG.SOUNDQUEUE.PORTRAIT_LEFT, 0)

    self.frame.portrait.texture = self.frame.portrait:CreateTexture(nil, "ARTWORK")
    self.frame.portrait.texture:SetAllPoints()
    self.frame.portrait.texture:SetTexture(CONFIG.PORTRAIT.DEFAULT_NPC)
end

function SoundQueue:InitNPCInfo()
    self.frame.npcName = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.npcName:SetPoint("TOPLEFT", 
        CONFIG.SOUNDQUEUE.INFO_LEFT, 
        CONFIG.SOUNDQUEUE.INFO_TOP_NPC)
    self.frame.npcName:SetText("Unknown NPC")

    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.frame.title:SetPoint("TOPLEFT", 
        CONFIG.SOUNDQUEUE.INFO_LEFT, 
        CONFIG.SOUNDQUEUE.INFO_TOP_TITLE)
    self.frame.title:SetWidth(CONFIG.SOUNDQUEUE.INFO_WIDTH)
    self.frame.title:SetJustifyH("LEFT")
    self.frame.title:SetText("Waiting...")
end

function SoundQueue:InitQueueContainer()
    self.frame.statusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.frame.statusText:SetPoint("BOTTOMLEFT", 
        CONFIG.SOUNDQUEUE.STATUS_LEFT, 
        CONFIG.SOUNDQUEUE.STATUS_BOTTOM)
    self.frame.statusText:SetText("")
end

function SoundQueue:InitControls()
    -- Close button
    self.frame.closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.closeBtn:SetPoint("TOPRIGHT", 0, 0)
    self.frame.closeBtn:SetWidth(CONFIG.SOUNDQUEUE.CLOSE_BUTTON_SIZE)
    self.frame.closeBtn:SetHeight(CONFIG.SOUNDQUEUE.CLOSE_BUTTON_SIZE)
    self.frame.closeBtn:SetScript("OnClick", function() SoundQueue.frame:Hide() end)
    self.frame.closeBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Hide (keeps playing)")
        GameTooltip:Show()
    end)
    self.frame.closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Back button (replay last from history)
    self.frame.backBtn = CreateFrame("Button", nil, self.frame)
    self.frame.backBtn:SetWidth(CONFIG.SOUNDQUEUE.BACK_BUTTON_SIZE)
    self.frame.backBtn:SetHeight(CONFIG.SOUNDQUEUE.BACK_BUTTON_SIZE)
    self.frame.backBtn:SetPoint("BOTTOMRIGHT", 
        CONFIG.SOUNDQUEUE.BACK_BUTTON_RIGHT, 
        CONFIG.SOUNDQUEUE.BACK_BUTTON_BOTTOM)
    self.frame.backBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    self.frame.backBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    self.frame.backBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    self.frame.backBtn:SetScript("OnClick", function()
        if table.getn(SoundQueue.history) > 0 then
            SoundQueue:PlayFromHistory(1)
        end
    end)
    self.frame.backBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Replay Last")
        if table.getn(SoundQueue.history) > 0 then
            GameTooltip:AddLine(SoundQueue.history[1].npcName or "Unknown", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    self.frame.backBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Pause / Play toggle
    self.frame.pauseBtn = CreateFrame("Button", nil, self.frame)
    self.frame.pauseBtn:SetWidth(CONFIG.SOUNDQUEUE.CONTROL_BUTTON_SIZE)
    self.frame.pauseBtn:SetHeight(CONFIG.SOUNDQUEUE.CONTROL_BUTTON_SIZE)
    self.frame.pauseBtn:SetPoint("BOTTOMRIGHT", 
        CONFIG.SOUNDQUEUE.PAUSE_BUTTON_RIGHT, 
        CONFIG.SOUNDQUEUE.PAUSE_BUTTON_BOTTOM)
    self.frame.pauseBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    self.frame.pauseBtn.pauseIcon = self.frame.pauseBtn:CreateTexture(nil, "ARTWORK")
    self.frame.pauseBtn.pauseIcon:SetAllPoints()
    self.frame.pauseBtn.pauseIcon:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\QuestLogStopButton")

    self.frame.pauseBtn.playIcon = self.frame.pauseBtn:CreateTexture(nil, "ARTWORK")
    self.frame.pauseBtn.playIcon:SetAllPoints()
    self.frame.pauseBtn.playIcon:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\QuestLogPlayButton")
    self.frame.pauseBtn.playIcon:Hide()

    self.frame.pauseBtn:SetScript("OnClick", function() SoundQueue:TogglePause() end)
    self.frame.pauseBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(SoundQueue.isPaused and "Resume" or "Pause")
        GameTooltip:Show()
    end)
    self.frame.pauseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Master init — called once from core.lua via SoundQueue:InitializeUI()
function SoundQueue:InitializeUI()
    if self.frame then return end     -- already built

    self:InitMainFrame()
    self:InitPortrait()
    self:InitNPCInfo()
    self:InitQueueContainer()
    self:InitQueueList()
    self:InitControls()

    self.frame:Hide()
    Debug("SoundQueue UI initialized")
end


-- =====================================================================
--   SECTION 3 — QuestFrame Layout (Universal Layout Engine)
-- =====================================================================

do  -- block-scope so all locals are invisible to the rest of ui.lua

local function GetBackdrop()
    return QuestFrame.backdrop or QuestFrame
end

local function ApplyQuestLayout()
    if not QuestFrame then return end
    
    DialogLayout:UpdatePortrait(QuestFrame)
    
    ApplyFrameLayout({
        frame = QuestFrame,
        type = "Quest",
        backdrop = GetBackdrop(),
        scrollFrames = {
            { frame = QuestDetailScrollFrame,   child = QuestDetailScrollChildFrame,   height = CONFIG.DIALOG.SCROLL_HEIGHT_DETAIL },
            { frame = QuestProgressScrollFrame, child = QuestProgressScrollChildFrame, height = CONFIG.DIALOG.SCROLL_HEIGHT_PROGRESS },
            { frame = QuestRewardScrollFrame,   child = QuestRewardScrollChildFrame,   height = CONFIG.DIALOG.SCROLL_HEIGHT_REWARD },
            { frame = QuestGreetingScrollFrame, child = QuestGreetingScrollChildFrame, height = CONFIG.DIALOG.SCROLL_HEIGHT_GREETING },
        },
        portrait = QuestFrame.widePortrait,
        buttons = { 
            QuestFrameAcceptButton, 
            QuestFrameDeclineButton, 
            QuestFrameCompleteButton, 
            QuestFrameGoodbyeButton,
            QuestGreetingFrameCancelButton,
        },
        closeButton = QuestFrameCloseButton,
        textFields = { 
            QuestTitleText, 
            QuestDescription, 
            QuestObjectiveText, 
            QuestProgressText, 
            QuestRewardText, 
            GreetingText,
        }
    })
    
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

-- Event frame for quest UI events
local questEventFrame = CreateFrame("Frame")
questEventFrame:RegisterEvent("QUEST_DETAIL")
questEventFrame:RegisterEvent("QUEST_PROGRESS")
questEventFrame:RegisterEvent("QUEST_COMPLETE")
questEventFrame:RegisterEvent("QUEST_GREETING")

questEventFrame:SetScript("OnEvent", function()
    this:SetScript("OnUpdate", function()
        ApplyQuestLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

-- OnShow hook
local originalQuestOnShow = QuestFrame:GetScript("OnShow")
QuestFrame:SetScript("OnShow", function()
    if originalQuestOnShow then originalQuestOnShow() end
    ApplyQuestLayout()
end)

-- Delayed init (gives Blizzard frames time to exist)
local questInitFrame = CreateFrame("Frame")
local questInitTimer = 0
questInitFrame:SetScript("OnUpdate", function()
    questInitTimer = questInitTimer + arg1
    if questInitTimer > 0.5 then
        ApplyQuestLayout()
        -- Hook SoundQueue using unified method
        DialogLayout:HookSoundQueue("quest", QuestFrame)
        this:SetScript("OnUpdate", nil)
    end
end)

end  -- end QuestFrame do-block


-- =====================================================================
--   SECTION 4 — GossipFrame Layout (Universal Layout Engine)
-- =====================================================================

do  -- block-scope

local function ApplyGossipLayout()
    if not GossipFrame then return end
    
    DialogLayout:UpdatePortrait(GossipFrame)
    
    ApplyFrameLayout({
        frame = GossipFrame,
        type = "Gossip",
        backdrop = GossipFrame.backdrop or GossipFrame,
        scrollFrames = {
            { frame = GossipGreetingScrollFrame, child = GossipGreetingScrollChildFrame, height = CONFIG.DIALOG.SCROLL_HEIGHT_GOSSIP },
        },
        portrait = GossipFrame.widePortrait,
        buttons = { 
            GossipFrameGreetingGoodbyeButton,
        },
        closeButton = GossipFrameCloseButton,
    })
    
    -- Scrollbar positioning (Gossip-specific)
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

-- Events
local gossipEventFrame = CreateFrame("Frame")
gossipEventFrame:RegisterEvent("GOSSIP_SHOW")
gossipEventFrame:RegisterEvent("GOSSIP_CLOSED")

gossipEventFrame:SetScript("OnEvent", function()
    if event == "GOSSIP_CLOSED" then
        DialogLayout:HidePortrait(GossipFrame)
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
        -- Hook SoundQueue using unified method
        DialogLayout:HookSoundQueue("gossip", GossipFrame)
        this:SetScript("OnUpdate", nil)
    end
end)

end  -- end GossipFrame do-block


-- =====================================================================
--   SECTION 5 — Book / Note / Letter Layout (Universal Layout Engine)
-- =====================================================================

do  -- block-scope

local function GetVisualBackdrop(frame, inset)
    if inset and inset:IsShown() then return inset end
    return frame
end

local function ApplyItemTextLayout()
    if not ItemTextFrame then return end

    local backdrop = GetVisualBackdrop(ItemTextFrame, ItemTextFrameInset)
    if not backdrop then return end

    ApplyFrameLayout({
        frame = ItemTextFrame,
        type = "Book",
        backdrop = backdrop,
        scrollFrames = {
            { frame = ItemTextScrollFrame, child = nil },
        },
        portrait = ItemTextFrame.widePortrait,
        textFields = { ItemTextPageText },
    })
end

-- Play the book's voice-over via SoundQueue
local function PlayBookVoice()
    if not ItemTextFrame or not ItemTextFrame:IsShown() then return end

    local title = ItemTextTitleText and ItemTextTitleText:GetText()
    if not title or title == "" then
        Debug("BookVoice: no title found")
        return
    end

    local text = ItemTextGetText()
    if not text or text == "" then
        Debug("BookVoice: no text found")
        return
    end

    if SoundQueue then
        SoundQueue:AddSound(title, text, title)
    end
end

-- Layout events
local bookLayoutFrame = CreateFrame("Frame")
bookLayoutFrame:RegisterEvent("ITEM_TEXT_BEGIN")
bookLayoutFrame:RegisterEvent("ITEM_TEXT_READY")
bookLayoutFrame:SetScript("OnEvent", function()
    this:SetScript("OnUpdate", function()
        ApplyItemTextLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

-- Voice-over trigger (fires when page text is actually available)
local bookVoiceFrame = CreateFrame("Frame")
bookVoiceFrame:RegisterEvent("ITEM_TEXT_READY")
bookVoiceFrame:SetScript("OnEvent", function()
    PlayBookVoice()
end)

-- OnShow hook
if ItemTextFrame then
    local originalBookOnShow = ItemTextFrame:GetScript("OnShow")
    ItemTextFrame:SetScript("OnShow", function()
        if originalBookOnShow then originalBookOnShow() end
        ApplyItemTextLayout()
    end)
end

-- Hook SoundQueue for book dialogs
local bookInitFrame = CreateFrame("Frame")
local bookInitTimer = 0
bookInitFrame:SetScript("OnUpdate", function()
    bookInitTimer = bookInitTimer + arg1
    if bookInitTimer > 0.5 then
        -- Hook SoundQueue using unified method
        DialogLayout:HookSoundQueue("book", ItemTextFrame)
        this:SetScript("OnUpdate", nil)
    end
end)

end  -- end Book do-block