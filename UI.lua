-- ui.lua
-- Every frame, layout hook, portrait, and UI-update callback lives here.
-- Load order: 3 of 4  (utils → soundqueue → ui → core)
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

local PORTRAIT_CONFIG = {
    WIDTH  = 125,
    HEIGHT = 220,
    OFFSET_X = 15,
    OFFSET_Y = 50,

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
    portrait.bg:SetTexture(0, 0, 0, 1)

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

function SoundQueue:UpdateStatusText()
    if not self.frame or not self.frame.status then return end

    local current = self.currentSound
    if current then
        local elapsed
        if self.isPaused then
            elapsed = current.pauseOffset
        else
            elapsed = GetTime() - current.startTime
        end
        self.frame.status:SetText(string.format("%.1fs / %.1fs", elapsed, current.duration))
    else
        self.frame.status:SetText("")
    end
end

function SoundQueue:UpdateQueueList()
    if not self.frame or not self.frame.queueButtons then return end

    for i = 1, self.maxQueueDisplay do
        local button   = self.frame.queueButtons[i]
        local soundData = self.sounds[i + 1]   -- [1] is currently playing

        if soundData then
            button.text:SetText(string.format("%d. %s", i, soundData.npcName or "Unknown"))
            button:Show()
        else
            button:Hide()
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
-- Queue-item button factory
-------------------------------------------------------------------------
function SoundQueue:CreateQueueButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)
    button.index = index

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture(1, 0.2, 0.2, 0.3)
    button.bg:Hide()

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", 5, 0)
    button.text:SetPoint("RIGHT", -5, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetTextColor(0.7, 0.7, 0.7)

    button:SetScript("OnEnter", function()
        this.bg:Show()
        this.text:SetTextColor(1, 0.3, 0.3)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to remove")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        this.bg:Hide()
        this.text:SetTextColor(0.7, 0.7, 0.7)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        local soundData = SoundQueue.sounds[this.index]
        if soundData then SoundQueue:RemoveSound(soundData) end
    end)

    return button
end

-------------------------------------------------------------------------
-- Sub-frame initializers  (modular, called once from InitializeUI)
-------------------------------------------------------------------------

function SoundQueue:InitMainFrame()
    self.frame = CreateFrame("Frame", "BetterQuestVoiceOverFrame", UIParent)
    self.frame:SetWidth(370)
    self.frame:SetHeight(120)
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetClampedToScreen(true)
    self.frame:RegisterForDrag("LeftButton")

    self.frame:SetScript("OnDragStart", function() this:StartMoving() end)
    self.frame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)

    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, 0.8)
end

function SoundQueue:InitPortrait()
    self.frame.portrait = CreateFrame("Frame", nil, self.frame)
    self.frame.portrait:SetWidth(self.portraitConfig.WIDTH)
    self.frame.portrait:SetHeight(self.portraitConfig.HEIGHT)
    self.frame.portrait:SetPoint("TOPLEFT", 10, -10)

    self.frame.portrait.bg = self.frame.portrait:CreateTexture(nil, "BACKGROUND")
    self.frame.portrait.bg:SetAllPoints()
    self.frame.portrait.bg:SetTexture(0, 0, 0, 1)

    self.frame.portrait.texture = self.frame.portrait:CreateTexture(nil, "ARTWORK")
    self.frame.portrait.texture:SetAllPoints()
    self.frame.portrait.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
end

function SoundQueue:InitNPCInfo()
    self.frame.header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.header:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, 0)
    self.frame.header:SetText("Now Playing:")
    self.frame.header:SetTextColor(0.5, 0.5, 0.5)

    -- Clickable "current track" area → click to skip
    self.frame.currentBtn = CreateFrame("Button", nil, self.frame)
    self.frame.currentBtn:SetPoint("TOPLEFT",     self.frame.portrait, "TOPRIGHT", 10, -14)
    self.frame.currentBtn:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", -30, -52)

    self.frame.currentBtn.bg = self.frame.currentBtn:CreateTexture(nil, "BACKGROUND")
    self.frame.currentBtn.bg:SetAllPoints()
    self.frame.currentBtn.bg:SetTexture(1, 0.2, 0.2, 0.3)
    self.frame.currentBtn.bg:Hide()

    self.frame.npcName = self.frame.currentBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.npcName:SetPoint("TOPLEFT", 0, 0)
    self.frame.npcName:SetTextColor(1, 1, 1)

    self.frame.title = self.frame.currentBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.title:SetPoint("TOPLEFT", 0, -16)
    self.frame.title:SetTextColor(0.9, 0.9, 0.5)

    self.frame.currentBtn:SetScript("OnEnter", function()
        this.bg:Show()
        SoundQueue.frame.npcName:SetTextColor(1, 0.3, 0.3)
        SoundQueue.frame.title:SetTextColor(1, 0.5, 0.5)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to skip")
        GameTooltip:Show()
    end)
    self.frame.currentBtn:SetScript("OnLeave", function()
        this.bg:Hide()
        SoundQueue.frame.npcName:SetTextColor(1, 1, 1)
        SoundQueue.frame.title:SetTextColor(0.9, 0.9, 0.5)
        GameTooltip:Hide()
    end)
    self.frame.currentBtn:SetScript("OnClick", function()
        local current = SoundQueue:GetCurrentSound()
        if current then
            SoundQueue:StopSound(current)
            SoundQueue:RemoveSound(current)
        end
    end)
end

function SoundQueue:InitQueueContainer()
    self.frame.queueContainer = CreateFrame("Frame", nil, self.frame)
    self.frame.queueContainer:SetPoint("TOPLEFT",     self.frame.portrait, "TOPRIGHT", 10, -55)
    self.frame.queueContainer:SetPoint("BOTTOMRIGHT", -10, 35)

    self.frame.queueHeader = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.queueHeader:SetPoint("BOTTOMLEFT", self.frame.queueContainer, "TOPLEFT", 0, 2)
    self.frame.queueHeader:SetText("Queue:")
    self.frame.queueHeader:SetTextColor(0.5, 0.5, 0.5)

    self.frame.queueButtons = {}
    for i = 1, self.maxQueueDisplay do
        local btn = self:CreateQueueButton(self.frame.queueContainer, i + 1)
        if i == 1 then
            btn:SetPoint("TOPLEFT",  0, 0)
            btn:SetPoint("TOPRIGHT", 0, 0)
        else
            btn:SetPoint("TOPLEFT",  self.frame.queueButtons[i-1], "BOTTOMLEFT",  0, -2)
            btn:SetPoint("TOPRIGHT", self.frame.queueButtons[i-1], "BOTTOMRIGHT", 0, -2)
        end
        self.frame.queueButtons[i] = btn
    end
end

function SoundQueue:InitControls()
    -- Elapsed / duration readout
    self.frame.status = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.status:SetPoint("BOTTOMLEFT", 10, 10)

    -- Close button (hides UI but keeps audio going)
    self.frame.closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
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
--   SECTION 3 — QuestFrame Layout
-- =====================================================================

do  -- block-scope so all locals are invisible to the rest of ui.lua

local QUEST_CONFIG = {
    WIDTH  = 620,
    HEIGHT = 400,
    POS_X  = 0,
    POS_Y  = -60,

    MARGIN_LEFT  = 140,
    MARGIN_RIGHT = 50,
    MARGIN_TOP   = 50,

    SCROLL_HEIGHT_DETAIL   = 220,
    SCROLL_HEIGHT_PROGRESS = 220,
    SCROLL_HEIGHT_REWARD   = 200,

    BUTTON_OFFSET_X = 20,
    BUTTON_OFFSET_Y = 20,
    CLOSE_OFFSET_X  = 8,
    CLOSE_OFFSET_Y  = 8,
}

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

    UpdateNPCPortrait()

    LayoutScroll(QuestDetailScrollFrame,   QuestDetailScrollChildFrame,   QUEST_CONFIG.SCROLL_HEIGHT_DETAIL)
    LayoutScroll(QuestProgressScrollFrame, QuestProgressScrollChildFrame, QUEST_CONFIG.SCROLL_HEIGHT_PROGRESS)
    LayoutScroll(QuestRewardScrollFrame,   QuestRewardScrollChildFrame,   QUEST_CONFIG.SCROLL_HEIGHT_REWARD)

    -- Re-anchor all Blizzard buttons to the backdrop
    if QuestFrameAcceptButton then
        QuestFrameAcceptButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT",
            QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameDeclineButton then
        QuestFrameDeclineButton:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT",
            -QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameCompleteButton then
        QuestFrameCompleteButton:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT",
            QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameGoodbyeButton then
        QuestFrameGoodbyeButton:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT",
            -QUEST_CONFIG.BUTTON_OFFSET_X, QUEST_CONFIG.BUTTON_OFFSET_Y)
    end
    if QuestFrameCloseButton then
        QuestFrameCloseButton:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT",
            -QUEST_CONFIG.CLOSE_OFFSET_X, -QUEST_CONFIG.CLOSE_OFFSET_Y)
    end
end

local function FixTextWidths()
    local width = QUEST_CONFIG.WIDTH - QUEST_CONFIG.MARGIN_LEFT - QUEST_CONFIG.MARGIN_RIGHT - 10
    local fields = {
        QuestTitleText, QuestDescription, QuestObjectiveText,
        QuestProgressText, QuestRewardText,
    }
    for _, f in ipairs(fields) do
        if f then
            f:SetWidth(width)
            f:SetJustifyH("LEFT")
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
--   SECTION 4 — GossipFrame Layout  (single authoritative copy)
-- =====================================================================

do  -- block-scope

local GOSSIP_CONFIG = {
    FRAME = {
        WIDTH    = 620,
        HEIGHT   = 350,
        OFFSET_X = 0,
        OFFSET_Y = -250,
    },
    PORTRAIT = {
        WIDTH  = 125,
        HEIGHT = 220,
        LEFT   = 15,
        TOP    = 50,
    },
    CONTENT = {
        GAP_FROM_PORTRAIT      = -10,
        RIGHT                  = 60,
        TOP                    = 40,
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
        OFFSET_X      = 16,
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
    portrait.bg:SetTexture(0, 0, 0, 1)

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

    GossipFrame:SetWidth(GOSSIP_CONFIG.FRAME.WIDTH)
    GossipFrame:SetHeight(GOSSIP_CONFIG.FRAME.HEIGHT)
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint("CENTER", UIParent, "CENTER",
        GOSSIP_CONFIG.FRAME.OFFSET_X, GOSSIP_CONFIG.FRAME.OFFSET_Y)

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