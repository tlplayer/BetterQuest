-- SoundQueue.lua (REFACTORED - OPTIMIZED)
-- Modular voice-over system for WoW 1.12.1
-- UI components separated into individual initialization functions
-- Fuzzy matching upgraded to Myers' bit-parallel edit distance (O(n) vs O(n²))
do
SoundQueue = {
    -- Queue & playback state
    sounds        = {},
    currentSound  = nil,
    isPlaying     = false,
    isPaused      = false,
    updateFrame   = nil,       -- Frame that drives CheckSoundFinished

    -- History
    history        = {},
    maxHistorySize = 50,

    -- UI caps
    maxQueueDisplay = 5,

    -- Portrait data referenced by ui.lua when building textures
    portraitConfig = {
        WIDTH          = 80,
        HEIGHT         = 80,
        PATH           = "Interface\\AddOns\\BetterQuest\\Textures\\",
        DEFAULT_NPC    = "Interface\\Icons\\INV_Misc_QuestionMark",
        DEFAULT_BOOK   = "Interface\\AddOns\\BetterQuest\\Textures\\Book",
        PORTRAIT_PATH  = "Interface\\AddOns\\BetterQuest\\portraits\\",
    },
}
end

-------------------------------------------------
-- UI UPDATE FUNCTIONS (Modular)
-------------------------------------------------

 function SoundQueue:UpdatePortrait(soundData)
    if not SoundQueue.frame or not SoundQueue.frame.portrait then return end
    
    local texture = GetPortraitTexture(soundData)
    SoundQueue.frame.portrait.texture:SetTexture(texture)
end

function SoundQueue:UpdateCurrentInfo(soundData)
    if not SoundQueue.frame then return end
    
    if soundData then
        SoundQueue.frame.npcName:SetText(soundData.npcName or "Unknown")
        SoundQueue.frame.title:SetText(soundData.title or "")
    else
        SoundQueue.frame.npcName:SetText("")
        SoundQueue.frame.title:SetText("")
    end
end

 function SoundQueue:UpdatePauseButton()
    if not SoundQueue.frame or not SoundQueue.frame.pauseBtn then return end
    
    if SoundQueue.isPaused then
        SoundQueue.frame.pauseBtn.pauseIcon:Hide()
        SoundQueue.frame.pauseBtn.playIcon:Show()
    else
        SoundQueue.frame.pauseBtn.pauseIcon:Show()
        SoundQueue.frame.pauseBtn.playIcon:Hide()
    end
end

 function SoundQueue:UpdateStatusText()
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

 function SoundQueue:UpdateQueueList()
    if not SoundQueue.frame or not SoundQueue.frame.queueButtons then return end
    
    for i = 1, SoundQueue.maxQueueDisplay do
        local button = SoundQueue.frame.queueButtons[i]
        local soundData = SoundQueue.sounds[i + 1]
        
        if soundData then
            button.text:SetText(string.format("%d. %s", i, soundData.npcName or "Unknown"))
            button:Show()
        else
            button:Hide()
        end
    end
end

function SoundQueue:ShowFrame()
    if SoundQueue.frame then
        SoundQueue.frame:Show()
    end
end

 function SoundQueue:HideFrame()
    if SoundQueue.frame then
        SoundQueue.frame:Hide()
    end
end

-------------------------------------------------
-- HISTORY
-------------------------------------------------

function SoundQueue:AddToHistory(soundData)
    if not soundData then return end
    
    table.insert(self.history, 1, {
        npcName = soundData.npcName,
        text = soundData.text,
        title = soundData.title,
        filePath = soundData.filePath,
        dialogType = soundData.dialogType,
        questID = soundData.questID,
        duration = soundData.duration,
        startTime = 0,
        pauseOffset = 0,
    })
    
    while table.getn(self.history) > self.maxHistorySize do
        table.remove(self.history)
    end
end

function SoundQueue:PlayFromHistory(index)
    local entry = self.history[index]
    if not entry then return end
    
    local soundData = {
        npcName = entry.npcName,
        text = entry.text,
        title = entry.title,
        filePath = entry.filePath,
        dialogType = entry.dialogType,
        questID = entry.questID,
        duration = entry.duration,
        startTime = 0,
        pauseOffset = 0,
    }
    
    table.insert(self.sounds, 1, soundData)
    
    if not self.isPlaying then
        self:PlaySound(soundData)
    end
end

function SoundQueue:ClearHistory()
    self.history = {}
    Debug("History cleared")
end

-------------------------------------------------
-- PLAYBACK CORE
-------------------------------------------------

function SoundQueue:PlaySound(soundData)
    Debug("PlaySound called for: " .. tostring(soundData and soundData.npcName))
    
    if not soundData then return end

    soundData.filePath = Utils:NormalizePath(soundData.filePath)
    
    if not soundData.filePath then
        Debug("ERROR: No valid file path")
        return
    end

    Utils:PlaySound(soundData)
    soundData.handle = 1

    if soundData.isResuming then
        soundData.startTime = GetTime() - soundData.pauseOffset
        soundData.isResuming = nil
        Debug("Resuming from: " .. soundData.pauseOffset)
    else
        soundData.startTime = GetTime()
        soundData.pauseOffset = 0
    end

    self.currentSound = soundData
    self.isPlaying = true
    self.isPaused = false

    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function()
            SoundQueue:CheckSoundFinished()
        end)
    end
    self.updateFrame:Show()
    
    
    SoundQueue:UpdatePortrait(soundData)
    SoundQueue:UpdateCurrentInfo(soundData)
    SoundQueue:UpdatePauseButton()
    SoundQueue:UpdateStatusText()
    SoundQueue:UpdateQueueList()
    SoundQueue:ShowFrame()
    
    Debug("PlaySound complete")
end

function SoundQueue:StopSound(soundData)
    if not soundData then return end
    Utils:StopSound(soundData)
    soundData.handle = nil
end

function SoundQueue:TogglePause()
    local current = self.currentSound
    if not current then return end

    if not self.isPaused then
        -- PAUSE
        Debug("Pausing")
        local elapsed = GetTime() - current.startTime
        current.pauseOffset = elapsed
        self:StopSound(current)
        self.isPaused = true
        self.isPlaying = false
        
        SoundQueue:UpdatePauseButton()
        SoundQueue:UpdateStatusText()
    else
        -- RESUME
        Debug("Resuming")
        current.isResuming = true
        self:PlaySound(current)
    end
end

function SoundQueue:CheckSoundFinished()
    if not self.currentSound or self.isPaused then return end
    
    SoundQueue:UpdateStatusText()
    
    local elapsed = GetTime() - self.currentSound.startTime
    if elapsed >= self.currentSound.duration then
        Debug("Sound finished naturally")
        self:RemoveSound(self.currentSound)
    end
end

-------------------------------------------------
-- QUEUE MANAGEMENT
-------------------------------------------------

function SoundQueue:GetQueueSize()
    return table.getn(self.sounds)
end

function SoundQueue:GetCurrentSound()
    return self.sounds[1]
end

function SoundQueue:AddSound(npcName, dialogText, title)
    Debug("Adding Sound to queue: " .. npcName, dialogText, title)

    if not npcName or not dialogText then return nil end
    Debug("Adding Sound to queue: " .. tostring(npcName))
 
    local soundPath, dialogType, questID, seconds = Utils:FindDialogSound(npcName, dialogText)
    print(soundPath)
    
    if not soundPath then 
        Debug("No sound found - logging to BetterQuestDB")
        return nil
    end
    
    local soundData = {
        npcName = npcName,
        text = dialogText,
        title = title or (questID and ("Quest " .. questID) or npcName),
        filePath = soundPath,
        dialogType = dialogType,
        questID = questID,
        duration = seconds or 15,
        startTime = 0,
        pauseOffset = 0,
    }
    
    -- Check for duplicates
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.filePath == soundData.filePath then 
            Debug("Duplicate, skipping")
            return nil
        end
    end
    
    table.insert(self.sounds, soundData)
    Debug("Added to queue (size: " .. table.getn(self.sounds) .. ")")
    
    if table.getn(self.sounds) == 1 then
        Debug("Beginning to play the sound")
        self:PlaySound(soundData)
    else
        UpdateQueueList()
    end
end

function SoundQueue:RemoveSound(soundData)
    if not soundData then return end
    
    Debug("RemoveSound: " .. tostring(soundData.npcName))
    
    local removedIndex = nil
    for i = 1, table.getn(self.sounds) do
        if self.sounds[i] == soundData then
            removedIndex = i
            break
        end
    end
    
    if not removedIndex then
        Debug("Sound not found")
        return
    end
    
    table.remove(self.sounds, removedIndex)
    Debug("Removed from queue")
    
    if removedIndex == 1 then
        -- Was playing
        self:AddToHistory(soundData)
        
        self.currentSound = nil
        self.isPlaying = false
        self.isPaused = false
        
        local nextSound = self:GetCurrentSound()
        if nextSound then
            Debug("Playing next")
            self:PlaySound(nextSound)
        else
            Debug("Queue empty")
            if self.updateFrame then 
                self.updateFrame:Hide() 
            end
            HideFrame()
        end
    else
        -- Was queued
        SoundQueue:UpdateQueueList()
    end
end

-------------------------------------------------
-- UI COMPONENTS (Modular Initialization)
-------------------------------------------------

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
        if soundData then
            SoundQueue:RemoveSound(soundData)
        end
    end)
    
    return button
end

-- Initialize main frame
function SoundQueue:InitMainFrame()
    self.frame = CreateFrame("Frame", "BetterQuestVoiceOverFrame", UIParent)
    self.frame:SetWidth(370)
    self.frame:SetHeight(120)
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetClampedToScreen(true)
    self.frame:RegisterForDrag("LeftButton")
    
    self.frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    
    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, 0.8)
end

-- Initialize portrait (without embedded border)
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
    
    -- Border removed - portraits should not have embedded borders
end

-- Initialize NPC info display
function SoundQueue:InitNPCInfo()
    self.frame.header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.header:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, 0)
    self.frame.header:SetText("Now Playing:")
    self.frame.header:SetTextColor(0.5, 0.5, 0.5)
    
    self.frame.currentBtn = CreateFrame("Button", nil, self.frame)
    self.frame.currentBtn:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, -14)
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

-- Initialize queue container
function SoundQueue:InitQueueContainer()
    self.frame.queueContainer = CreateFrame("Frame", nil, self.frame)
    self.frame.queueContainer:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, -55)
    self.frame.queueContainer:SetPoint("BOTTOMRIGHT", -10, 35)
    
    self.frame.queueHeader = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.queueHeader:SetPoint("BOTTOMLEFT", self.frame.queueContainer, "TOPLEFT", 0, 2)
    self.frame.queueHeader:SetText("Queue:")
    self.frame.queueHeader:SetTextColor(0.5, 0.5, 0.5)
    
    self.frame.queueButtons = {}
    for i = 1, self.maxQueueDisplay do
        local btn = self:CreateQueueButton(self.frame.queueContainer, i + 1)
        if i == 1 then
            btn:SetPoint("TOPLEFT", 0, 0)
            btn:SetPoint("TOPRIGHT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", self.frame.queueButtons[i-1], "BOTTOMLEFT", 0, -2)
            btn:SetPoint("TOPRIGHT", self.frame.queueButtons[i-1], "BOTTOMRIGHT", 0, -2)
        end
        self.frame.queueButtons[i] = btn
    end
end

-- Initialize control buttons (pause/play/back)
function SoundQueue:InitControls()
    -- Status text
    self.frame.status = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.status:SetPoint("BOTTOMLEFT", 10, 10)

    -- Close button
    self.frame.closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    self.frame.closeBtn:SetWidth(20)
    self.frame.closeBtn:SetHeight(20)
    self.frame.closeBtn:SetScript("OnClick", function()
        SoundQueue.frame:Hide()
    end)
    self.frame.closeBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Hide (keeps playing)")
        GameTooltip:Show()
    end)
    self.frame.closeBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Back button (replay last)
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
    self.frame.backBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Pause/Play button
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
    
    self.frame.pauseBtn:SetScript("OnClick", function() 
        SoundQueue:TogglePause() 
    end)
    self.frame.pauseBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(SoundQueue.isPaused and "Resume" or "Pause")
        GameTooltip:Show()
    end)
    self.frame.pauseBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Main UI initialization (now modular)
function SoundQueue:InitializeUI()
    if self.frame then return end
    
    self:InitMainFrame()
    self:InitPortrait()
    self:InitNPCInfo()
    self:InitQueueContainer()
    self:InitControls()
    
    self.frame:Hide()
    Debug("UI Initialized (Modular)")
end


-------------------------------------------------
-- DELAYED TRIGGER LOGIC
-------------------------------------------------

function SoundQueue:QueueTrigger(npcName, eventType)
    if self.delayFrameActive then return end
    self.delayFrameActive = true
    if not self.delayFrame then
        self.delayFrame = CreateFrame("Frame")
    end

    local waitTime = 0.1
    local startTime = GetTime()

    self.delayFrame:SetScript("OnUpdate", function()
        if GetTime() - startTime >= waitTime then
            this:SetScript("OnUpdate", nil)
            
            local text, title
            if eventType == "QUEST_DETAIL" then
                text, title = GetQuestText(), GetTitleText()
            elseif eventType == "QUEST_PROGRESS" then
                text, title = GetProgressText(), GetTitleText()
            elseif eventType == "QUEST_COMPLETE" then
                text, title = GetRewardText(), GetTitleText()
            elseif eventType == "GOSSIP_SHOW" then
                text, title = GetGossipText(), "Gossip"
            end

            if text and text ~= "" then
                SoundQueue:AddSound(npcName, text, title)
            end
            
            SoundQueue.delayFrameActive = false
        end
    end)
end

-------------------------------------------------
-- INITIALIZE
-------------------------------------------------

function SoundQueue:Initialize()
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    
    initFrame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "BetterQuest" then
            
            local gameEventFrame = CreateFrame("Frame")
            gameEventFrame:RegisterEvent("QUEST_DETAIL")
            gameEventFrame:RegisterEvent("QUEST_PROGRESS")
            gameEventFrame:RegisterEvent("QUEST_COMPLETE")
            gameEventFrame:RegisterEvent("GOSSIP_SHOW")
            
            gameEventFrame:SetScript("OnEvent", function()
                SoundQueue:QueueTrigger(UnitName("npc"), event)
            end)
            
        end
    end)
end

SoundQueue:Initialize()