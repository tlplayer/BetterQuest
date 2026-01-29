-- SoundQueue.lua
-- All-in-one voice-over system for WoW 1.12.1
-- NO CENTRAL UpdateUI - Each function handles its own UI

SoundQueue = {
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    isPaused = false,
    updateFrame = nil,
    history = {},
    maxHistorySize = 50,
    maxQueueDisplay = 5,
    
    portraitConfig = {
        WIDTH = 64,
        HEIGHT = 64,
        PATH = "Interface\\AddOns\\BetterQuest\\Textures\\",
        DEFAULT_NPC = "Interface\\Icons\\INV_Misc_QuestionMark",
        DEFAULT_BOOK = "Interface\\AddOns\\BetterQuest\\Textures\\Book",
    },
}

-------------------------------------------------
-- DEBUG & UTILS
-------------------------------------------------

local function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[SoundQueue]|r " .. tostring(msg))
end

local function NormalizePath(path)
    if not path then return nil end
    return string.gsub(path, "/+", "\\")
end

-------------------------------------------------
-- PORTRAIT HELPERS
-------------------------------------------------

local function GetNPCMetadata(npcName)
    if GetNPCMetadata then
        return GetNPCMetadata(npcName)
    elseif NPC_DATABASE and npcName then
        local normalized = string.gsub(npcName, "['']", "")
        return NPC_DATABASE[normalized]
    end
    return nil
end

local function IsBookInteraction()
    return ItemTextFrame and ItemTextFrame:IsShown()
end

local function GetPortraitTexture(soundData)
    if not soundData then
        return SoundQueue.portraitConfig.DEFAULT_NPC
    end
    
    if IsBookInteraction() then
        return SoundQueue.portraitConfig.DEFAULT_BOOK
    end
    
    local npcName = soundData.npcName
    if npcName then
        local metadata = GetNPCMetadata(npcName)
        if metadata and metadata.race then
            local filename = metadata.race
            if metadata.sex == "female" then
                filename = filename .. "_female"
            end
            return SoundQueue.portraitConfig.PATH .. filename .. ".tga"
        end
    end
    
    return SoundQueue.portraitConfig.DEFAULT_NPC
end

-------------------------------------------------
-- UI HELPERS - Direct updates, no central function
-------------------------------------------------

local function ShowFrame()
    if SoundQueue.frame then
        SoundQueue.frame:Show()
    end
end

local function HideFrame()
    if SoundQueue.frame then
        SoundQueue.frame:Hide()
    end
end

local function UpdatePortrait(soundData)
    if not SoundQueue.frame or not SoundQueue.frame.portrait then return end
    
    local portraitTexture = GetPortraitTexture(soundData)
    if SoundQueue.frame.portrait.texture then
        SoundQueue.frame.portrait.texture:SetTexture(portraitTexture)
    end
end

local function UpdateCurrentInfo(soundData)
    if not SoundQueue.frame then return end
    
    if SoundQueue.frame.npcName and soundData then
        SoundQueue.frame.npcName:SetText(soundData.npcName or "Unknown")
    end
    
    if SoundQueue.frame.title and soundData then
        SoundQueue.frame.title:SetText(soundData.title or "")
    end
end

local function UpdatePauseButton()
    if not SoundQueue.frame or not SoundQueue.frame.pauseBtn then return end
    
    if SoundQueue.isPaused then
        SoundQueue.frame.pauseBtn.pauseIcon:Hide()
        SoundQueue.frame.pauseBtn.playIcon:Show()
    else
        SoundQueue.frame.pauseBtn.pauseIcon:Show()
        SoundQueue.frame.pauseBtn.playIcon:Hide()
    end
end

local function UpdateStatusText()
    if not SoundQueue.frame or not SoundQueue.frame.status then return end
    
    if SoundQueue.isPaused then
        SoundQueue.frame.status:SetText("|cffff0000PAUSED|r")
    else
        local current = SoundQueue.currentSound
        if current then
            local elapsed = GetTime() - current.startTime
            local remaining = current.duration - elapsed
            if remaining < 0 then remaining = 0 end
            SoundQueue.frame.status:SetText(string.format("|cff00ff00Playing|r %.0fs", remaining))
        end
    end
end

local function UpdateQueueList()
    if not SoundQueue.frame or not SoundQueue.frame.queueButtons then return end
    
    local queueSize = table.getn(SoundQueue.sounds)
    local displayCount = 0
    
    for i = 2, queueSize do
        displayCount = displayCount + 1
        if displayCount <= SoundQueue.maxQueueDisplay then
            local soundData = SoundQueue.sounds[i]
            local btn = SoundQueue.frame.queueButtons[displayCount]
            if btn and btn.text then
                btn.index = i
                btn.text:SetText(string.format("%d. %s - %s", displayCount, soundData.npcName or "Unknown", soundData.title or ""))
                btn:Show()
            end
        end
    end
    
    for i = displayCount + 1, SoundQueue.maxQueueDisplay do
        if SoundQueue.frame.queueButtons[i] then
            SoundQueue.frame.queueButtons[i]:Hide()
        end
    end
    
    if SoundQueue.frame.queueHeader then
        if displayCount > 0 then
            SoundQueue.frame.queueHeader:Show()
        else
            SoundQueue.frame.queueHeader:Hide()
        end
    end
end

-------------------------------------------------
-- HISTORY MANAGEMENT
-------------------------------------------------

function SoundQueue:AddToHistory(soundData)
    local historyEntry = {
        npcName = soundData.npcName,
        text = soundData.text,
        title = soundData.title,
        filePath = soundData.filePath,
        dialogType = soundData.dialogType,
        questID = soundData.questID,
        duration = soundData.duration,
        timestamp = time(),
    }
    
    table.insert(self.history, 1, historyEntry)
    
    while table.getn(self.history) > self.maxHistorySize do
        table.remove(self.history)
    end
end

function SoundQueue:PlayFromHistory(index)
    if not self.history[index] then
        Debug("History entry " .. index .. " not found")
        return
    end
    
    local entry = self.history[index]
    Debug("Replaying from history: " .. (entry.npcName or "Unknown"))
    
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

    soundData.filePath = NormalizePath(soundData.filePath)
    
    if not soundData.filePath then
        Debug("ERROR: No valid file path")
        return
    end

    PlaySoundFile(soundData.filePath)
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
    
    -- Update UI directly - no central function
    UpdatePortrait(soundData)
    UpdateCurrentInfo(soundData)
    UpdatePauseButton()
    UpdateStatusText()
    UpdateQueueList()
    ShowFrame()
    
    Debug("PlaySound complete")
end

function SoundQueue:StopSound(soundData)
    if not soundData then return end
    SetCVar("MasterSoundEffects", 0)
    SetCVar("MasterSoundEffects", 1)
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
        
        -- Update UI directly
        UpdatePauseButton()
        UpdateStatusText()
    else
        -- RESUME
        Debug("Resuming")
        current.isResuming = true
        self:PlaySound(current)
        -- PlaySound handles all UI updates
    end
end

function SoundQueue:CheckSoundFinished()
    if not self.currentSound or self.isPaused then return end
    
    -- Update time display while playing
    UpdateStatusText()
    
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

function SoundQueue:FindSound(npcName, dialogText)
    if not npcName or not dialogText or not FindDialogSound then return nil end
    return FindDialogSound(npcName, dialogText)
end

function SoundQueue:AddSound(npcName, dialogText, title)
    Debug("AddSound: " .. tostring(npcName))
    
    local soundPath, dialogType, questID, seconds = self:FindSound(npcName, dialogText)
    
    if not soundPath then 
        Debug("No sound found")
        return 
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
            return 
        end
    end
    
    table.insert(self.sounds, soundData)
    Debug("Added to queue (size: " .. table.getn(self.sounds) .. ")")
    
    if table.getn(self.sounds) == 1 then
        self:PlaySound(soundData)
    else
        -- Just update the queue list
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
        UpdateQueueList()
    end
end

-------------------------------------------------
-- UI - QUEUE BUTTONS
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

-------------------------------------------------
-- UI INITIALIZATION
-------------------------------------------------

function SoundQueue:InitializeUI()
    if self.frame then return end
    
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
    
    -- PORTRAIT
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
    
    self.frame.portrait.border = self.frame.portrait:CreateTexture(nil, "OVERLAY")
    self.frame.portrait.border:SetAllPoints()
    self.frame.portrait.border:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\PortraitFrameAtlas")
    self.frame.portrait.border:SetTexCoord(0, 0.8125, 0, 0.8125)
    
    -- HEADER
    self.frame.header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.header:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, 0)
    self.frame.header:SetText("Now Playing:")
    self.frame.header:SetTextColor(0.5, 0.5, 0.5)
    
    -- CURRENT PLAYING (clickable)
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
    
    -- QUEUE CONTAINER
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
    
    -- STATUS
    self.frame.status = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.status:SetPoint("BOTTOMLEFT", 10, 10)

    -- CLOSE BUTTON
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

    -- BACK BUTTON
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

    -- PAUSE/PLAY BUTTON
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
    
    self.frame:Hide()
    Debug("UI Initialized")
end

-------------------------------------------------
-- SLASH COMMANDS
-------------------------------------------------

SLASH_SOUNDQUEUE1 = "/bq"
SLASH_SOUNDQUEUE2 = "/soundqueue"

SlashCmdList["SOUNDQUEUE"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "show" then
        if SoundQueue.frame and SoundQueue:GetCurrentSound() then
            ShowFrame()
        end
    elseif msg == "history" then
        if table.getn(SoundQueue.history) == 0 then
            Debug("No history")
        else
            Debug("=== History (" .. table.getn(SoundQueue.history) .. ") ===")
            for i = 1, math.min(10, table.getn(SoundQueue.history)) do
                local entry = SoundQueue.history[i]
                Debug(i .. ". " .. (entry.npcName or "Unknown") .. " - " .. (entry.title or ""))
            end
        end
    elseif msg == "clear" then
        SoundQueue:ClearHistory()
    elseif string.find(msg, "play ") == 1 then
        local index = tonumber(string.sub(msg, 6))
        if index then
            SoundQueue:PlayFromHistory(index)
        end
    elseif msg == "pause" then
        SoundQueue:TogglePause()
    else
        Debug("Commands: show, history, play <n>, clear, pause")
    end
end

-------------------------------------------------
-- INITIALIZE
-------------------------------------------------

function SoundQueue:Initialize()
    Debug("Initializing...")
    
    if not FindDialogSound then 
        Debug("ERROR: FindDialogSound not found!")
        return 
    end
    
    self:InitializeUI()
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_DETAIL")
    eventFrame:RegisterEvent("QUEST_PROGRESS")
    eventFrame:RegisterEvent("QUEST_COMPLETE")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "QUEST_DETAIL" then
            SoundQueue:AddSound(UnitName("npc"), GetQuestText(), GetTitleText())
        elseif event == "QUEST_PROGRESS" then
            SoundQueue:AddSound(UnitName("npc"), GetProgressText(), GetTitleText())
        elseif event == "QUEST_COMPLETE" then
            SoundQueue:AddSound(UnitName("npc"), GetRewardText(), GetTitleText())
        elseif event == "GOSSIP_SHOW" then
            SoundQueue:AddSound(UnitName("npc"), GetGossipText(), UnitName("npc"))
        end
    end)
    
    Debug("Ready! Type /bq for commands")
end

SoundQueue:Initialize()