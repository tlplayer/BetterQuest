-- ui.lua
-- Every frame, layout hook, portrait, and UI-update callback lives here.
-- Load order: 3 of 4  (utils → soundqueue → ui → core)
--
-- UPDATED: Integrated QuestUI.tga background with portrait positioning
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
PortraitManager.DEBUG = false

-- Module-private state
local currentPortrait = {
    type    = nil,
    texture = nil,
    frame   = nil,
}
local activeNPCName = nil

local QUEST_UI_TEXTURE = "Interface\\AddOns\\BetterQuest\\Textures\\QuestUI.tga"

local PORTRAIT_CONFIG = {
    -- Updated to match QuestUI.tga dark frame position
    WIDTH  = 140,
    HEIGHT = 180,
    OFFSET_X = 25,
    OFFSET_Y = 85,

    DEFAULT_NPC    = "Interface\\AddOns\\BetterQuest\\portraits\\default.tga",
    DEFAULT_BOOK   = "Interface\\Icons\\INV_Misc_Book_09",
    DEFAULT_ITEM   = "Interface\\Icons\\INV_Misc_QuestionMark",
    DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",

    PORTRAIT_PATH  = "Interface\\AddOns\\BetterQuest\\portraits\\",
}

-- Debug helper scoped to PortraitManager
local function PMDebug(msg)
    if PortraitManager.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. msg)
    end
end

-- Build "portraits/race.tga" or "portraits/race_female.tga"
local function BuildPortraitPath(race, sex)
    if not race or race == "" then return PORTRAIT_CONFIG.DEFAULT_NPC end
    local filename = race
    if sex == "female" then filename = filename .. "_female" end
    return PORTRAIT_CONFIG.PORTRAIT_PATH .. filename .. ".tga"
end

-- Get-or-create the wide portrait sub-frame on any parent.
-- Reuses an existing one; only creates if absent.  (Fixes the old double-definition bug.)
local function GetOrCreatePortraitFrame(parentFrame)
    if not parentFrame then return nil end
    if parentFrame.widePortrait then return parentFrame.widePortrait end

    local portrait = CreateFrame("Frame", nil, parentFrame)
    portrait:SetWidth(PORTRAIT_CONFIG.WIDTH)
    portrait:SetHeight(PORTRAIT_CONFIG.HEIGHT)
    portrait:SetPoint("TOPLEFT", parentFrame, "TOPLEFT",
        PORTRAIT_CONFIG.OFFSET_X, -PORTRAIT_CONFIG.OFFSET_Y)

    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints()
    portrait.bg:SetTexture(0, 0, 0, 0)  -- Transparent since QuestUI.tga has the frame

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
        return PORTRAIT_CONFIG.DEFAULT_NPC
    end
    if npc.race and npc.race ~= "" then
        local path = BuildPortraitPath(npc.race, npc.sex)
        PMDebug("Using portrait: " .. path)
        return path
    end
    PMDebug("No race found, using default")
    return PORTRAIT_CONFIG.DEFAULT_NPC
end

function PortraitManager:FindNPCPortraitByKey(key)
    if not key or key == "" then return PORTRAIT_CONFIG.DEFAULT_NPC end
    return PORTRAIT_CONFIG.PORTRAIT_PATH .. key .. ".tga"
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
    return PORTRAIT_CONFIG.DEFAULT_BOOK
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
        texturePath = PORTRAIT_CONFIG.DEFAULT_BOOK
    elseif portraitType == self.Type.ITEM then
        texturePath = PORTRAIT_CONFIG.DEFAULT_ITEM
    elseif portraitType == self.Type.OBJECT then
        texturePath = PORTRAIT_CONFIG.DEFAULT_OBJECT
    else
        texturePath = PORTRAIT_CONFIG.DEFAULT_NPC
    end

    -- Validate before calling SetTexture (removes the stray print() from the old code)
    if type(texturePath) == "string" and texturePath ~= "" then
        portrait.texture:SetTexture(texturePath)
    else
        PMDebug("BLOCKED bad texture path: " .. tostring(texturePath))
        portrait.texture:SetTexture(PORTRAIT_CONFIG.DEFAULT_NPC)
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

function PortraitManager:GetCurrentPortrait()
    return currentPortrait
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
--   SECTION 2 — SoundQueue Mini-Player UI
--         (attached onto the SoundQueue table)
-- =====================================================================

-------------------------------------------------------------------------
-- Portrait-texture resolver for the mini-player
-------------------------------------------------------------------------
local function GetPortraitTexture(soundData)
    if not soundData or not soundData.npcName then
        return SoundQueue.portraitConfig.DEFAULT_NPC
    end
    if IsBookInteraction() then
        return SoundQueue.portraitConfig.DEFAULT_BOOK
    end

    local metadata = GetNPCMetadata and GetNPCMetadata(soundData.npcName)
    if metadata and metadata.race and metadata.sex then
        local filename = metadata.race
        if metadata.sex == "female" then filename = filename .. "_female" end
        return SoundQueue.portraitConfig.PORTRAIT_PATH .. filename .. ".tga"
    end
    return SoundQueue.portraitConfig.DEFAULT_NPC
end

-------------------------------------------------------------------------
-- UI-update callbacks  (overwrite the no-op stubs in soundqueue.lua)
-------------------------------------------------------------------------
function SoundQueue:UpdatePortrait(soundData)
    if not self.frame
    or not self.frame.portrait
    or not self.frame.portrait.texture then return end

    self.frame.portrait.texture:SetTexture(GetPortraitTexture(soundData))
end

function SoundQueue:UpdateCurrentInfo(soundData)
    if not self.frame then return end
    if soundData then
        self.frame.npcName:SetText(soundData.npcName or "Unknown")
        self.frame.title:SetText(soundData.title or "")
    else
        self.frame.npcName:SetText("")
        self.frame.title:SetText("")
    end
end

function SoundQueue:UpdatePauseButton()
    if not self.frame or not self.frame.pauseBtn then return end
    if self.isPaused then
        self.frame.pauseBtn.pauseIcon:Hide()
        self.frame.pauseBtn.playIcon:Show()
    else
        self.frame.pauseBtn.pauseIcon:Show()
        self.frame.pauseBtn.playIcon:Hide()
    end
end

local function UpdateStatusText()
    if not SoundQueue.frame or not SoundQueue.frame.status then return end
    
    local current = SoundQueue.currentSound
    if current then
        local elapsed = GetTime() - current.startTime
        local remaining = current.duration - elapsed
        
        if SoundQueue.isPaused then
            elapsed = current.pauseOffset
            remaining = current.duration - elapsed
        end
        
        local statusText = string.format("%.1fs / %.1fs", elapsed, current.duration)
        SoundQueue.frame.status:SetText(statusText)
    else
        SoundQueue.frame.status:SetText("")
    end
end

function SoundQueue:InitQueueList()
    -- Container frame for queued sounds
    self.frame.queueContainer = CreateFrame("Frame", nil, self.frame)
    self.frame.queueContainer:SetPoint("TOPLEFT", 80, -55)
    self.frame.queueContainer:SetWidth(200)
    self.frame.queueContainer:SetHeight(80)

    -- Pool of buttons for queued sounds
    self.frame.queueButtons = {}
    for i = 1, 5 do  -- show up to 5 queued sounds
        local btn = CreateFrame("Button", nil, self.frame.queueContainer)
        btn:SetHeight(15)
        btn:SetWidth(180)
        btn:SetPoint("TOPLEFT", 0, -(i-1)*16)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetAllPoints()
        btn.text:SetJustifyH("LEFT")

        -- Make a local copy of i for the closure
        local index = i
        btn:SetScript("OnClick", function()
            if not SoundQueue.sounds then return end
            local soundData = SoundQueue.sounds[index+1]  -- skip currently playing
            if soundData then
                SoundQueue:RemoveSound(soundData)
            end
        end)

        btn:Hide()
        self.frame.queueButtons[i] = btn
    end
end

function SoundQueue:UpdateQueueList()
    if not self.frame or not self.frame.queueButtons then return end
    if not self.sounds then return end

    for i, btn in ipairs(self.frame.queueButtons) do
        local soundData = self.sounds[i+1]  -- skip currently playing
        if soundData then
            btn.text:SetText(string.format("%d. %s", i, soundData.npcName or "Unknown"))
            btn:Show()
        else
            btn:Hide()
        end
    end
end


function SoundQueue:ShowFrame()
    if self.frame then self.frame:Show() end
end

function SoundQueue:HideFrame()
    if self.frame then self.frame:Hide() end
end

-------------------------------------------------------------------------
-- UI Construction
-------------------------------------------------------------------------
function SoundQueue:InitMainFrame()
    self.frame = CreateFrame("Frame", "BetterQuestSoundFrame", UIParent)
    self.frame:SetWidth(300)
    self.frame:SetHeight(80)
    self.frame:SetPoint("BOTTOMRIGHT", -20, 100)
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function() this:StartMoving() end)
    self.frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, 0.7)
end

function SoundQueue:InitPortrait()
    self.frame.portrait = CreateFrame("Frame", nil, self.frame)
    self.frame.portrait:SetWidth(60)
    self.frame.portrait:SetHeight(60)
    self.frame.portrait:SetPoint("LEFT", 10, 0)

    self.frame.portrait.texture = self.frame.portrait:CreateTexture(nil, "ARTWORK")
    self.frame.portrait.texture:SetAllPoints()
    self.frame.portrait.texture:SetTexture(self.portraitConfig.DEFAULT_NPC)
end

function SoundQueue:InitNPCInfo()
    self.frame.npcName = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.npcName:SetPoint("TOPLEFT", 80, -15)
    self.frame.npcName:SetText("Unknown NPC")

    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.frame.title:SetPoint("TOPLEFT", 80, -35)
    self.frame.title:SetWidth(180)
    self.frame.title:SetJustifyH("LEFT")
    self.frame.title:SetText("Waiting...")
end

function SoundQueue:InitQueueContainer()
    self.frame.statusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.frame.statusText:SetPoint("BOTTOMLEFT", 80, 15)
    self.frame.statusText:SetText("")
end

function SoundQueue:InitControls()
    -- Close button
    self.frame.closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.closeBtn:SetPoint("TOPRIGHT", 0, 0)
    self.frame.closeBtn:SetWidth(20)
    self.frame.closeBtn:SetHeight(20)
    self.frame.closeBtn:SetScript("OnClick", function() SoundQueue.frame:Hide() end)
    self.frame.closeBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Hide (keeps playing)")
        GameTooltip:Show()
    end)
    self.frame.closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Back button (replay last from history)
    self.frame.backBtn = CreateFrame("Button", nil, self.frame)
    self.frame.backBtn:SetWidth(20)
    self.frame.backBtn:SetHeight(20)
    self.frame.backBtn:SetPoint("BOTTOMRIGHT", -50, 10)
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
    self.frame.pauseBtn:SetWidth(24)
    self.frame.pauseBtn:SetHeight(24)
    self.frame.pauseBtn:SetPoint("BOTTOMRIGHT", -25, 8)
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
    self:InitControls()

    self.frame:Hide()
    Debug("SoundQueue UI initialized")
end


-- =====================================================================
--   SECTION 3 — QuestFrame Layout with QuestUI.tga Background
-- =====================================================================

do  -- block-scope so all locals are invisible to the rest of ui.lua

local QUEST_CONFIG = {
    -- Frame dimensions to match your QuestUI.tga
    WIDTH  = 800,
    HEIGHT = 450,
    POS_X  = 0,
    POS_Y  = -60,

    -- Content area margins (to fit within the parchment area)
    MARGIN_LEFT  = 200,  -- Space for portrait frame on left
    MARGIN_RIGHT = 60,
    MARGIN_TOP   = 80,

    SCROLL_HEIGHT_DETAIL   = 250,
    SCROLL_HEIGHT_PROGRESS = 250,
    SCROLL_HEIGHT_REWARD   = 230,
    SCROLL_HEIGHT_GREETING = 250,

    BUTTON_OFFSET_X = 80,
    BUTTON_OFFSET_Y = 30,
    CLOSE_OFFSET_X  = 15,
    CLOSE_OFFSET_Y  = 15,
}

local function GetBackdrop()
    return QuestFrame.backdrop or QuestFrame
end

-- Apply the QuestUI.tga background
local function ApplyQuestBackground()
    if not QuestFrame then return end
    local backdrop = GetBackdrop()
    
    -- Create custom background texture if it doesn't exist
    if not backdrop.customBG then
        backdrop.customBG = backdrop:CreateTexture(nil, "BACKGROUND")
        backdrop.customBG:SetAllPoints(backdrop)
        backdrop.customBG:SetTexture(QUEST_UI_TEXTURE)
        
        -- Hide default Blizzard background elements
        if QuestFrameDetailPanel then QuestFrameDetailPanel:SetAlpha(0) end
        if QuestFrameProgressPanel then QuestFrameProgressPanel:SetAlpha(0) end
        if QuestFrameRewardPanel then QuestFrameRewardPanel:SetAlpha(0) end
        if QuestFrameGreetingPanel then QuestFrameGreetingPanel:SetAlpha(0) end
        
        Debug("QuestFrame custom background applied")
    end
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
    local contentWidth = QUEST_CONFIG.WIDTH - QUEST_CONFIG.MARGIN_LEFT - QUEST_CONFIG.MARGIN_RIGHT

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", QuestFrame, "TOPLEFT",
        QUEST_CONFIG.MARGIN_LEFT, -QUEST_CONFIG.MARGIN_TOP)
    scrollFrame:SetWidth(contentWidth)
    scrollFrame:SetHeight(height)

    if child then child:SetWidth(contentWidth) end
end

local function ApplyQuestLayout()
    if not QuestFrame then return end
    local backdrop = GetBackdrop()

    QuestFrame:SetWidth(QUEST_CONFIG.WIDTH)
    QuestFrame:SetHeight(QUEST_CONFIG.HEIGHT)
    QuestFrame:ClearAllPoints()
    QuestFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", QUEST_CONFIG.POS_X, QUEST_CONFIG.POS_Y)

    -- Apply custom background
    ApplyQuestBackground()
    
    -- Update portrait
    UpdateNPCPortrait()

    LayoutScroll(QuestDetailScrollFrame,   QuestDetailScrollChildFrame,   QUEST_CONFIG.SCROLL_HEIGHT_DETAIL)
    LayoutScroll(QuestProgressScrollFrame, QuestProgressScrollChildFrame, QUEST_CONFIG.SCROLL_HEIGHT_PROGRESS)
    LayoutScroll(QuestRewardScrollFrame,   QuestRewardScrollChildFrame,   QUEST_CONFIG.SCROLL_HEIGHT_REWARD)
    LayoutScroll(QuestGreetingScrollFrame, QuestGreetingScrollChildFrame, QUEST_CONFIG.SCROLL_HEIGHT_GREETING)

    -- Re-anchor all Blizzard buttons to match QuestUI.tga button positions
    if QuestFrameAcceptButton then
        QuestFrameAcceptButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            -QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameDeclineButton then
        QuestFrameDeclineButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameCompleteButton then
        QuestFrameCompleteButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            -QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameGoodbyeButton then
        QuestFrameGoodbyeButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameCloseButton then
        QuestFrameCloseButton:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT",
            -QUEST_CONFIG.CLOSE_OFFSET_X, -QUEST_CONFIG.CLOSE_OFFSET_Y)
    end
    
    -- Greeting buttons alignment
    if QuestGreetingFrameCancelButton then
        QuestGreetingFrameCancelButton:SetPoint("BOTTOM", backdrop, "BOTTOM",
            QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
end

local function FixTextWidths()
    local width = QUEST_CONFIG.WIDTH - QUEST_CONFIG.MARGIN_LEFT - QUEST_CONFIG.MARGIN_RIGHT - 10
    local fields = {
        QuestTitleText, QuestDescription, QuestObjectiveText,
        QuestProgressText, QuestRewardText,
        GreetingText,
    }
    for _, f in ipairs(fields) do
        if f then
            f:SetWidth(width)
            f:SetJustifyH("LEFT")
        end
    end
    
    -- Fix Greeting title buttons alignment
    for i=1, 32 do
        local button = getglobal("QuestTitleButton"..i)
        if button and button:IsShown() then
            button:SetWidth(width)
            local text = getglobal("QuestTitleButton"..i.."QuestTitle")
            if text then
                text:SetWidth(width - 20)
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


-- =====================================================================
--   SECTION 4 — GossipFrame Layout with QuestUI.tga Background
-- =====================================================================

do  -- block-scope

local GOSSIP_CONFIG = {
    FRAME = {
        WIDTH    = 800,
        HEIGHT   = 450,
        OFFSET_X = 0,
        OFFSET_Y = -60,
    },
    PORTRAIT = {
        WIDTH  = 140,
        HEIGHT = 180,
        LEFT   = 25,
        TOP    = 85,
    },
    CONTENT = {
        GAP_FROM_PORTRAIT      = 10,
        RIGHT                  = 60,
        TOP                    = 80,
        BOTTOM                 = 40,
        EXTRA_BOTTOM_RESERVED  = 80,
    },
    BUTTON = {
        HEIGHT_PADDING = 4,
        TEXT_LEFT      = 25,
        TEXT_RIGHT     = 5,
        ICON_LEFT      = 3,
    },
    SCROLLBAR = {
        OFFSET_X      = -20,
        OFFSET_TOP    = 16,
        OFFSET_BOTTOM = 16,
    },
}

-- Derived layout (computed once at load time)
local GOSSIP_LAYOUT = {
    PORTRAIT = {
        LEFT  = GOSSIP_CONFIG.PORTRAIT.LEFT,
        TOP   = GOSSIP_CONFIG.PORTRAIT.TOP,
        RIGHT = GOSSIP_CONFIG.PORTRAIT.LEFT + GOSSIP_CONFIG.PORTRAIT.WIDTH,
    },
    CONTENT = {
        LEFT =
            GOSSIP_CONFIG.PORTRAIT.LEFT
            + GOSSIP_CONFIG.PORTRAIT.WIDTH
            + GOSSIP_CONFIG.CONTENT.GAP_FROM_PORTRAIT,
        WIDTH =
            GOSSIP_CONFIG.FRAME.WIDTH
            - (GOSSIP_CONFIG.PORTRAIT.LEFT + GOSSIP_CONFIG.PORTRAIT.WIDTH + GOSSIP_CONFIG.CONTENT.GAP_FROM_PORTRAIT)
            - GOSSIP_CONFIG.CONTENT.RIGHT,
        HEIGHT =
            GOSSIP_CONFIG.FRAME.HEIGHT
            - GOSSIP_CONFIG.CONTENT.TOP
            - GOSSIP_CONFIG.CONTENT.BOTTOM
            - GOSSIP_CONFIG.CONTENT.EXTRA_BOTTOM_RESERVED,
    },
}

local function EnsureGossipPortrait(parent)
    if parent.widePortrait then return parent.widePortrait end

    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetWidth(GOSSIP_CONFIG.PORTRAIT.WIDTH)
    portrait:SetHeight(GOSSIP_CONFIG.PORTRAIT.HEIGHT)
    portrait:SetPoint("TOPLEFT", parent, "TOPLEFT",
        GOSSIP_LAYOUT.PORTRAIT.LEFT, -GOSSIP_LAYOUT.PORTRAIT.TOP)

    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints()
    portrait.bg:SetTexture(0, 0, 0, 0)  -- Transparent since QuestUI.tga has the frame

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

-- Apply the QuestUI.tga background to Gossip frame
local function ApplyGossipBackground()
    if not GossipFrame then return end
    local backdrop = GossipFrame.backdrop or GossipFrame
    
    if not backdrop.customBG then
        backdrop.customBG = backdrop:CreateTexture(nil, "BACKGROUND")
        backdrop.customBG:SetAllPoints(backdrop)
        backdrop.customBG:SetTexture(QUEST_UI_TEXTURE)
        
        Debug("GossipFrame custom background applied")
    end
end

local function ApplyGossipLayout()
    if not GossipFrame then return end
    local backdrop = GossipFrame.backdrop or GossipFrame

    GossipFrame:SetWidth(GOSSIP_CONFIG.FRAME.WIDTH)
    GossipFrame:SetHeight(GOSSIP_CONFIG.FRAME.HEIGHT)
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint("BOTTOM", UIParent, "BOTTOM",
        GOSSIP_CONFIG.FRAME.OFFSET_X, GOSSIP_CONFIG.FRAME.OFFSET_Y)

    -- Apply custom background
    ApplyGossipBackground()
    
    -- Update portrait
    UpdateGossipPortrait()

    if GossipGreetingScrollFrame then
        GossipGreetingScrollFrame:ClearAllPoints()
        GossipGreetingScrollFrame:SetPoint("TOPLEFT", backdrop, "TOPLEFT",
            GOSSIP_LAYOUT.CONTENT.LEFT, -GOSSIP_CONFIG.CONTENT.TOP)
        GossipGreetingScrollFrame:SetWidth(GOSSIP_LAYOUT.CONTENT.WIDTH)
        GossipGreetingScrollFrame:SetHeight(GOSSIP_LAYOUT.CONTENT.HEIGHT)
    end

    if GossipGreetingScrollChildFrame then
        GossipGreetingScrollChildFrame:SetWidth(GOSSIP_LAYOUT.CONTENT.WIDTH)
    end

    if GossipGreetingScrollFrameScrollBar then
        GossipGreetingScrollFrameScrollBar:ClearAllPoints()
        GossipGreetingScrollFrameScrollBar:SetPoint("TOPRIGHT",
            GossipGreetingScrollFrame, "TOPRIGHT",
            GOSSIP_CONFIG.SCROLLBAR.OFFSET_X, -GOSSIP_CONFIG.SCROLLBAR.OFFSET_TOP)
        GossipGreetingScrollFrameScrollBar:SetPoint("BOTTOMRIGHT",
            GossipGreetingScrollFrame, "BOTTOMRIGHT",
            GOSSIP_CONFIG.SCROLLBAR.OFFSET_X, GOSSIP_CONFIG.SCROLLBAR.OFFSET_BOTTOM)
    end
end

-- GossipResize: MUST be global — Blizzard's GossipFrame calls it by name
function GossipResize(titleButton)
    if not titleButton then return end

    titleButton:SetWidth(GOSSIP_LAYOUT.CONTENT.WIDTH)
    titleButton:SetHeight(titleButton:GetTextHeight() + GOSSIP_CONFIG.BUTTON.HEIGHT_PADDING)

    local text = getglobal(titleButton:GetName() .. "Text")
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", titleButton, "LEFT", GOSSIP_CONFIG.BUTTON.TEXT_LEFT, 0)
        text:SetWidth(GOSSIP_LAYOUT.CONTENT.WIDTH - GOSSIP_CONFIG.BUTTON.TEXT_LEFT - GOSSIP_CONFIG.BUTTON.TEXT_RIGHT)
        text:SetJustifyH("LEFT")
    end

    local icon = getglobal(titleButton:GetName() .. "GossipIcon")
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", titleButton, "LEFT", GOSSIP_CONFIG.BUTTON.ICON_LEFT, 0)
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


-- =====================================================================
--   SECTION 5 — Book / Note / Letter Layout
-- =====================================================================

do  -- block-scope

local BOOK_CONFIG = {
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
}

local function GetVisualBackdrop(frame, inset)
    if inset and inset:IsShown() then return inset end
    return frame
end

local function ApplyItemTextLayout()
    if not ItemTextFrame then return end

    local backdrop = GetVisualBackdrop(ItemTextFrame, ItemTextFrameInset)
    if not backdrop then return end

    ItemTextFrame:SetWidth(BOOK_CONFIG.FRAME_WIDTH)
    ItemTextFrame:SetHeight(BOOK_CONFIG.FRAME_HEIGHT)
    ItemTextFrame:ClearAllPoints()
    ItemTextFrame:SetPoint(
        BOOK_CONFIG.ANCHOR_POINT, UIParent, BOOK_CONFIG.ANCHOR_RELATIVE,
        BOOK_CONFIG.OFFSET_X, BOOK_CONFIG.OFFSET_Y)

    local contentWidth  = backdrop:GetWidth()  - BOOK_CONFIG.MARGIN_LEFT - BOOK_CONFIG.MARGIN_RIGHT
    local contentHeight = backdrop:GetHeight() - BOOK_CONFIG.MARGIN_TOP  - BOOK_CONFIG.MARGIN_BOTTOM

    if ItemTextScrollFrame then
        ItemTextScrollFrame:ClearAllPoints()
        ItemTextScrollFrame:SetPoint("TOPLEFT", backdrop, "TOPLEFT",
            BOOK_CONFIG.MARGIN_LEFT, -BOOK_CONFIG.MARGIN_TOP)
        ItemTextScrollFrame:SetWidth(contentWidth)
        ItemTextScrollFrame:SetHeight(contentHeight)
    end

    if ItemTextPageText then
        ItemTextPageText:SetWidth(contentWidth + BOOK_CONFIG.TEXT_RIGHT_PADDING)
        ItemTextPageText:SetJustifyH("LEFT")
    end
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

end  -- end Book do-block