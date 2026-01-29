-- SoundQueue.lua
-- All-in-one voice-over system for WoW 1.12.1
-- RESTORED FEATURES with infinite loop protection and enhanced UI logic

SoundQueue = {
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    isPaused = false,
    updateFrame = nil,
    history = {},
    maxHistorySize = 50,
    maxQueueDisplay = 5,
    lastTriggerText = "", -- ANTI-SPAM: Prevents infinite loops/freezes from event spam
    
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
-- UI HELPERS (Direct Updates)
-------------------------------------------------

local function UpdateQueueList()
    if not SoundQueue.frame or not SoundQueue.frame.queueButtons then return end
    
    local queueSize = table.getn(SoundQueue.sounds)
    local displayCount = 0
    
    -- Start from index 2 as index 1 is currently playing
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

local function UpdateStatusText()
    if not SoundQueue.frame or not SoundQueue.frame.status then return end
    
    if SoundQueue.isPaused then
        SoundQueue.frame.status:SetText("|cffff0000PAUSED|r")
    elseif SoundQueue.currentSound then
        local elapsed = GetTime() - SoundQueue.currentSound.startTime
        local remaining = SoundQueue.currentSound.duration - elapsed
        if remaining < 0 then remaining = 0 end
        SoundQueue.frame.status:SetText(string.format("|cff00ff00Playing|r %.0fs", remaining))
    else
        SoundQueue.frame.status:SetText("")
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
    if not self.history[index] then return end
    local entry = self.history[index]
    
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
    else
        -- Stop current and jump to history item
        self:StopSound(self.currentSound)
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
    if not soundData then return end
    soundData.filePath = NormalizePath(soundData.filePath)
    if not soundData.filePath then return end

    PlaySoundFile(soundData.filePath)

    if soundData.isResuming then
        soundData.startTime = GetTime() - soundData.pauseOffset
        soundData.isResuming = nil
    else
        soundData.startTime = GetTime()
        soundData.pauseOffset = 0
    end

    self.currentSound = soundData
    self.isPlaying = true
    self.isPaused = false

    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function() SoundQueue:CheckSoundFinished() end)
    end
    self.updateFrame:Show()
    
    -- UI Direct Updates
    if self.frame then
        self.frame:Show()
        self.frame.portrait.texture:SetTexture(GetPortraitTexture(soundData))
        self.frame.npcName:SetText(soundData.npcName or "Unknown")
        self.frame.title:SetText(soundData.title or "")
        UpdatePauseButton()
        UpdateStatusText()
        UpdateQueueList()
    end
end

function SoundQueue:StopSound(soundData)
    if not soundData then return end
    SetCVar("MasterSoundEffects", 0)
    SetCVar("MasterSoundEffects", 1)
end

function SoundQueue:TogglePause()
    local current = self.currentSound
    if not current then return end

    if not self.isPaused then
        local elapsed = GetTime() - current.startTime
        current.pauseOffset = elapsed
        self:StopSound(current)
        self.isPaused = true
        self.isPlaying = false
        UpdatePauseButton()
        UpdateStatusText()
    else
        current.isResuming = true
        self:PlaySound(current)
    end
end

function SoundQueue:CheckSoundFinished()
    if not self.currentSound or self.isPaused then return end
    UpdateStatusText()
    
    local elapsed = GetTime() - self.currentSound.startTime
    if elapsed >= self.currentSound.duration then
        self:RemoveSound(self.currentSound)
    end
end

-------------------------------------------------
-- QUEUE MANAGEMENT
-------------------------------------------------

function SoundQueue:AddSound(npcName, dialogText, title)
    -- VITAL: Anti-spam filter to prevent freezing/infinite loops from redundant events
    if not dialogText or dialogText == "" or dialogText == self.lastTriggerText then return end
    self.lastTriggerText = dialogText

    if not FindDialogSound then return end
    local soundPath, dialogType, questID, seconds = FindDialogSound(npcName, dialogText)
    
    if not soundPath then return end
    
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
    
    -- Duplicate check in queue
    for i = 1, table.getn(self.sounds) do
        if self.sounds[i].filePath == soundData.filePath then return end
    end
    
    table.insert(self.sounds, soundData)
    
    if table.getn(self.sounds) == 1 then
        self:PlaySound(soundData)
    else
        UpdateQueueList()
    end
end

function SoundQueue:RemoveSound(soundData)
    if not soundData then return end
    
    local removedIndex = nil
    for i = 1, table.getn(self.sounds) do
        if self.sounds[i] == soundData then
            removedIndex = i
            break
        end
    end
    
    if not removedIndex then return end
    table.remove(self.sounds, removedIndex)
    
    if removedIndex == 1 then
        self:AddToHistory(soundData)
        self:StopSound(soundData)
        self.currentSound = nil
        self.isPlaying = false
        self.isPaused = false
        
        local nextSound = self.sounds[1]
        if nextSound then
            self:PlaySound(nextSound)
        else
            if self.updateFrame then self.updateFrame:Hide() end
            if self.frame then self.frame:Hide() end
        end
    else
        UpdateQueueList()
    end
end

-------------------------------------------------
-- UI INITIALIZATION
-------------------------------------------------

function SoundQueue:InitializeUI()
    if self.frame then return end
    
    local f = CreateFrame("Frame", "BetterQuestVoiceOverFrame", UIParent)
    self.frame = f
    f:SetWidth(370)
    f:SetHeight(120)
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(0, 0, 0, 0.8)
    
    -- PORTRAIT with atlas borders
    f.portrait = CreateFrame("Frame", nil, f)
    f.portrait:SetWidth(self.portraitConfig.WIDTH)
    f.portrait:SetHeight(self.portraitConfig.HEIGHT)
    f.portrait:SetPoint("TOPLEFT", 10, -10)
    
    f.portrait.bg = f.portrait:CreateTexture(nil, "BACKGROUND")
    f.portrait.bg:SetAllPoints()
    f.portrait.bg:SetTexture(0, 0, 0, 1)
    
    f.portrait.texture = f.portrait:CreateTexture(nil, "ARTWORK")
    f.portrait.texture:SetAllPoints()
    f.portrait.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    f.portrait.border = f.portrait:CreateTexture(nil, "OVERLAY")
    f.portrait.border:SetAllPoints()
    f.portrait.border:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\PortraitFrameAtlas")
    f.portrait.border:SetTexCoord(0, 0.8125, 0, 0.8125)
    
    -- HEADER
    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.header:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 10, 0)
    f.header:SetText("Now Playing:")
    f.header:SetTextColor(0.5, 0.5, 0.5)
    
    -- CURRENT PLAYING (clickable to skip)
    f.currentBtn = CreateFrame("Button", nil, f)
    f.currentBtn:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 10, -14)
    f.currentBtn:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -30, -52)
    f.currentBtn.bg = f.currentBtn:CreateTexture(nil, "BACKGROUND")
    f.currentBtn.bg:SetAllPoints()
    f.currentBtn.bg:SetTexture(1, 0.2, 0.2, 0.3)
    f.currentBtn.bg:Hide()
    
    f.npcName = f.currentBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.npcName:SetPoint("TOPLEFT", 0, 0)
    f.title = f.currentBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 0, -16)
    f.title:SetTextColor(0.9, 0.9, 0.5)
    
    f.currentBtn:SetScript("OnEnter", function()
        this.bg:Show()
        SoundQueue.frame.npcName:SetTextColor(1, 0.3, 0.3)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to skip")
        GameTooltip:Show()
    end)
    f.currentBtn:SetScript("OnLeave", function()
        this.bg:Hide()
        SoundQueue.frame.npcName:SetTextColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    f.currentBtn:SetScript("OnClick", function()
        SoundQueue:RemoveSound(SoundQueue.currentSound)
    end)
    
    -- QUEUE LIST CONTAINER
    f.queueContainer = CreateFrame("Frame", nil, f)
    f.queueContainer:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 10, -55)
    f.queueContainer:SetPoint("BOTTOMRIGHT", -10, 35)
    
    f.queueHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.queueHeader:SetPoint("BOTTOMLEFT", f.queueContainer, "TOPLEFT", 0, 2)
    f.queueHeader:SetText("Queue:")
    f.queueHeader:SetTextColor(0.5, 0.5, 0.5)
    
    f.queueButtons = {}
    for i = 1, self.maxQueueDisplay do
        local btn = CreateFrame("Button", nil, f.queueContainer)
        btn:SetHeight(18)
        btn:SetWidth(280)
        if i == 1 then
            btn:SetPoint("TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", f.queueButtons[i-1], "BOTTOMLEFT", 0, -2)
        end
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", 5, 0)
        btn.text:SetTextColor(0.7, 0.7, 0.7)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(1, 0.2, 0.2, 0.3)
        btn.bg:Hide()
        btn:SetScript("OnEnter", function() 
            this.bg:Show() 
            this.text:SetTextColor(1, 0.3, 0.3)
        end)
        btn:SetScript("OnLeave", function() 
            this.bg:Hide() 
            this.text:SetTextColor(0.7, 0.7, 0.7)
        end)
        btn:SetScript("OnClick", function()
            if this.index then SoundQueue:RemoveSound(SoundQueue.sounds[this.index]) end
        end)
        f.queueButtons[i] = btn
    end
    
    -- STATUS TEXT
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.status:SetPoint("BOTTOMLEFT", 10, 10)

    -- CLOSE BUTTON
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    f.closeBtn:SetWidth(20)
    f.closeBtn:SetHeight(20)

    -- BACK BUTTON (REPLAY)
    f.backBtn = CreateFrame("Button", nil, f)
    f.backBtn:SetWidth(20)
    f.backBtn:SetHeight(20)
    f.backBtn:SetPoint("BOTTOMRIGHT", -50, 10)
    f.backBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    f.backBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    f.backBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    f.backBtn:SetScript("OnClick", function() SoundQueue:PlayFromHistory(1) end)
    f.backBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Replay Last")
        if table.getn(SoundQueue.history) > 0 then
            GameTooltip:AddLine(SoundQueue.history[1].npcName, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    f.backBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- PAUSE/PLAY BUTTON
    f.pauseBtn = CreateFrame("Button", nil, f)
    f.pauseBtn:SetWidth(24)
    f.pauseBtn:SetHeight(24)
    f.pauseBtn:SetPoint("BOTTOMRIGHT", -25, 8)
    f.pauseBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
    f.pauseBtn.pauseIcon = f.pauseBtn:CreateTexture(nil, "ARTWORK")
    f.pauseBtn.pauseIcon:SetAllPoints()
    f.pauseBtn.pauseIcon:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\QuestLogStopButton")
    
    f.pauseBtn.playIcon = f.pauseBtn:CreateTexture(nil, "ARTWORK")
    f.pauseBtn.playIcon:SetAllPoints()
    f.pauseBtn.playIcon:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\QuestLogPlayButton")
    
    f.pauseBtn:SetScript("OnClick", function() SoundQueue:TogglePause() end)
    f.pauseBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(SoundQueue.isPaused and "Resume" or "Pause")
        GameTooltip:Show()
    end)
    f.pauseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    f:Hide()
end

-------------------------------------------------
-- INITIALIZE
-------------------------------------------------

function SoundQueue:Initialize()
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
end

SoundQueue:Initialize()

-------------------------------------------------
-- SLASH COMMANDS
-------------------------------------------------

SLASH_SOUNDQUEUE1 = "/bq"
SlashCmdList["SOUNDQUEUE"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "clear" then 
        SoundQueue:ClearHistory()
    elseif cmd == "pause" then 
        SoundQueue:TogglePause()
    elseif cmd == "show" then
        if SoundQueue.frame then SoundQueue.frame:Show() end
    else 
        Debug("Commands: show, clear, pause") 
    end
end