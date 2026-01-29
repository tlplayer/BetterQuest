-- SoundQueue.lua
-- All-in-one voice-over system for WoW 1.12.1
-- DEBUG ALWAYS ON

SoundQueue = {
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    isPaused = false,
    updateFrame = nil,
    history = {}, -- NEW: History cache
    maxHistorySize = 50, -- NEW: Max history entries
    maxQueueDisplay = 5, -- Max queue items to show
    
    -- Portrait configuration
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
    if not path then
        Debug("NormalizePath received nil")
        return nil
    end
    return string.gsub(path, "/+", "\\")
end

-------------------------------------------------
-- PORTRAIT HELPERS
-------------------------------------------------

local function GetNPCMetadata(npcName)
    -- Try to get NPC metadata if NPC_DATABASE exists
    if GetNPCMetadata then
        return GetNPCMetadata(npcName)
    elseif NPC_DATABASE and npcName then
        local normalized = string.gsub(npcName, "['']", "")
        return NPC_DATABASE[normalized]
    end
    return nil
end

local function IsBookInteraction()
    -- Check if ItemTextFrame exists and is shown (reading a book/letter)
    return ItemTextFrame and ItemTextFrame:IsShown()
end

local function GetPortraitTexture(soundData)
    if not soundData then
        return SoundQueue.portraitConfig.DEFAULT_NPC
    end
    
    -- Check if it's a book interaction
    if IsBookInteraction() then
        return SoundQueue.portraitConfig.DEFAULT_BOOK
    end
    
    -- Try to get NPC portrait
    local npcName = soundData.npcName
    if npcName then
        local metadata = GetNPCMetadata(npcName)
        if metadata and metadata.race then
            -- Build portrait path: race.tga or race_female.tga
            local filename = metadata.race
            if metadata.sex == "female" then
                filename = filename .. "_female"
            end
            local path = SoundQueue.portraitConfig.PATH .. filename .. ".tga"
            return path
        end
    end
    
    -- Fallback to default
    return SoundQueue.portraitConfig.DEFAULT_NPC
end

-------------------------------------------------
-- HISTORY MANAGEMENT
-------------------------------------------------

function SoundQueue:AddToHistory(soundData)
    -- Create a copy for history
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
    
    -- Trim history if too large
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
    
    -- Create a new sound data from history
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
    
    -- Add to front of queue
    table.insert(self.sounds, 1, soundData)
    
    -- If nothing playing, start immediately
    if not self.currentSound or not self.isPlaying then
        self:PlaySound(soundData)
    end
    
    self:UpdateUI()
end

function SoundQueue:ClearHistory()
    self.history = {}
    Debug("History cleared")
end

-------------------------------------------------
-- PLAYBACK
-------------------------------------------------

function SoundQueue:PlaySound(soundData)
    if not soundData then return end

    -- 1. Normalize path for 1.12.1
    soundData.filePath = NormalizePath(soundData.filePath)

    PlaySoundFile(soundData.filePath)
    soundData.handle = 1 -- Just put something here to flag the sound as stoppable

    
    -- 4. Handle timing for Resume vs New Play
    if soundData.isResuming then
        soundData.startTime = GetTime() - soundData.pauseOffset
        soundData.isResuming = nil
        Debug("Resuming from offset: " .. soundData.pauseOffset)
    else
        soundData.startTime = GetTime()
        soundData.pauseOffset = 0
    end

    self.currentSound = soundData
    self.isPlaying = true
    self.isPaused = false

    -- 5. OnUpdate Timer
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function()
            SoundQueue:CheckSoundFinished()
        end)
    end
    self.updateFrame:Show()
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
                self.frame.pauseBtn.pauseIcon:Hide()
        self.frame.pauseBtn.playIcon:Show() -- Show Play Triangle
    else
        -- RESUME
        Debug("Resuming from: " .. current.pauseOffset)
        current.isResuming = true
        self:PlaySound(current)
                self.frame.pauseBtn.pauseIcon:Show() -- Show Stop Square
        self.frame.pauseBtn.playIcon:Hide()
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
    local soundPath, dialogType, questID, seconds = self:FindSound(npcName, dialogText)
    
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
    
    -- Check for duplicates
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.filePath == soundData.filePath then return end
    end
    
    table.insert(self.sounds, soundData)
    
    if table.getn(self.sounds) == 1 then
        self:PlaySound(soundData)
    end
    
    self:UpdateUI()
end

function SoundQueue:RemoveSound(soundData)
    local removedIndex = nil
    for i, queuedSound in ipairs(self.sounds) do
        if queuedSound == soundData then
            removedIndex = i
            table.remove(self.sounds, i)
            break
        end
    end
    
    if removedIndex == 1 then
        -- Add to history before removing
        self:AddToHistory(soundData)
        
        self.currentSound = nil
        self.isPlaying = false
        self.isPaused = false
        
        local nextSound = self:GetCurrentSound()
        if nextSound then
            self:PlaySound(nextSound)
        else
            if self.updateFrame then self.updateFrame:Hide() end
        end
    end
    
    self:UpdateUI()
end

-------------------------------------------------
-- PLAYBACK
-------------------------------------------------

function SoundQueue:CheckSoundFinished()
    -- If paused, we don't tick the timer forward
    if not self.currentSound or self.isPaused then return end
    
    local elapsed = GetTime() - self.currentSound.startTime
    if elapsed >= self.currentSound.duration then
        Debug("Sound finished naturally")
        self:RemoveSound(self.currentSound)
    end
end

-------------------------------------------------
-- UI - QUEUE BUTTONS
-------------------------------------------------

function SoundQueue:CreateQueueButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)
    button.index = index
    
    -- Background highlight on hover
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture(1, 0.2, 0.2, 0.3)
    button.bg:Hide()
    
    -- Text label
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", 5, 0)
    button.text:SetPoint("RIGHT", -5, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetTextColor(0.7, 0.7, 0.7)
    
    button:SetScript("OnEnter", function()
        this.bg:Show()
        this.text:SetTextColor(1, 0.3, 0.3)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to remove from queue")
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        this.bg:Hide()
        local soundData = SoundQueue.sounds[this.index]
        if soundData then
            if this.index == 1 then
                this.text:SetTextColor(1, 1, 1)
            else
                this.text:SetTextColor(0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Hide()
    end)
    
    button:SetScript("OnClick", function()
        local soundData = SoundQueue.sounds[this.index]
        if soundData then
            Debug("Removing from queue: " .. (soundData.npcName or "Unknown"))
            SoundQueue:RemoveSound(soundData)
        end
    end)
    
    return button
end

-------------------------------------------------
-- UI
-------------------------------------------------

function SoundQueue:InitializeUI()
    if self.frame then return end
    
    self.frame = CreateFrame("Frame", "BetterQuestVoiceOverFrame", UIParent)
    self.frame:SetWidth(370) -- Wider to accommodate portrait
    self.frame:SetHeight(120)
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetClampedToScreen(true) -- Prevent from being dragged off-screen
    self.frame:RegisterForDrag("LeftButton")
    
    -- Make the frame draggable
    self.frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    
    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, 0.8)
    
    -- PORTRAIT FRAME
    self.frame.portrait = CreateFrame("Frame", nil, self.frame)
    self.frame.portrait:SetWidth(self.portraitConfig.WIDTH)
    self.frame.portrait:SetHeight(self.portraitConfig.HEIGHT)
    self.frame.portrait:SetPoint("TOPLEFT", 10, -10)
    
    -- Portrait background
    self.frame.portrait.bg = self.frame.portrait:CreateTexture(nil, "BACKGROUND")
    self.frame.portrait.bg:SetAllPoints()
    self.frame.portrait.bg:SetTexture(0, 0, 0, 1)
    
    -- Portrait texture
    self.frame.portrait.texture = self.frame.portrait:CreateTexture(nil, "ARTWORK")
    self.frame.portrait.texture:SetAllPoints()
    self.frame.portrait.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Slight crop for better framing
    
    -- Portrait border (optional decorative frame)
    self.frame.portrait.border = self.frame.portrait:CreateTexture(nil, "OVERLAY")
    self.frame.portrait.border:SetAllPoints()
    self.frame.portrait.border:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\PortraitFrameAtlas")
    self.frame.portrait.border:SetTexCoord(0, 0.8125, 0, 0.8125)
    
    -- Currently Playing Header
    self.frame.header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.header:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, 0)
    self.frame.header:SetText("Now Playing:")
    self.frame.header:SetTextColor(0.5, 0.5, 0.5)
    
    -- Currently playing area as a clickable button
    self.frame.currentBtn = CreateFrame("Button", nil, self.frame)
    self.frame.currentBtn:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, -14)
    self.frame.currentBtn:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", -30, -52)
    
    -- Background highlight on hover
    self.frame.currentBtn.bg = self.frame.currentBtn:CreateTexture(nil, "BACKGROUND")
    self.frame.currentBtn.bg:SetAllPoints()
    self.frame.currentBtn.bg:SetTexture(1, 0.2, 0.2, 0.3)
    self.frame.currentBtn.bg:Hide()
    
    -- Currently playing NPC name (bigger, brighter)
    self.frame.npcName = self.frame.currentBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.npcName:SetPoint("TOPLEFT", 0, 0)
    self.frame.npcName:SetTextColor(1, 1, 1)
    
    -- Quest/Dialog title
    self.frame.title = self.frame.currentBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.title:SetPoint("TOPLEFT", 0, -16)
    self.frame.title:SetTextColor(0.9, 0.9, 0.5)
    
    self.frame.currentBtn:SetScript("OnEnter", function()
        this.bg:Show()
        self.frame.npcName:SetTextColor(1, 0.3, 0.3)
        self.frame.title:SetTextColor(1, 0.5, 0.5)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to skip")
        GameTooltip:Show()
    end)
    
    self.frame.currentBtn:SetScript("OnLeave", function()
        this.bg:Hide()
        self.frame.npcName:SetTextColor(1, 1, 1)
        self.frame.title:SetTextColor(0.9, 0.9, 0.5)
        GameTooltip:Hide()
    end)
    
    self.frame.currentBtn:SetScript("OnClick", function()
        local current = SoundQueue:GetCurrentSound()
        if current then
            Debug("Skipping current: " .. (current.npcName or "Unknown"))
            -- Stop the sound first
            SoundQueue:StopSound(current)
            SoundQueue:RemoveSound(current)
        end
    end)
    
    -- Queue List Container
    self.frame.queueContainer = CreateFrame("Frame", nil, self.frame)
    self.frame.queueContainer:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT", 10, -55)
    self.frame.queueContainer:SetPoint("BOTTOMRIGHT", -10, 35)
    
    -- Queue header
    self.frame.queueHeader = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.queueHeader:SetPoint("BOTTOMLEFT", self.frame.queueContainer, "TOPLEFT", 0, 2)
    self.frame.queueHeader:SetText("Queue:")
    self.frame.queueHeader:SetTextColor(0.5, 0.5, 0.5)
    
    -- Create queue buttons
    self.frame.queueButtons = {}
    for i = 1, self.maxQueueDisplay do
        local btn = self:CreateQueueButton(self.frame.queueContainer, i + 1) -- +1 because index 1 is currently playing
        if i == 1 then
            btn:SetPoint("TOPLEFT", 0, 0)
            btn:SetPoint("TOPRIGHT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", self.frame.queueButtons[i-1], "BOTTOMLEFT", 0, -2)
            btn:SetPoint("TOPRIGHT", self.frame.queueButtons[i-1], "BOTTOMRIGHT", 0, -2)
        end
        self.frame.queueButtons[i] = btn
    end
    
    -- Status text with time
    self.frame.status = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.status:SetPoint("BOTTOMLEFT", 10, 10)

    -- CLOSE BUTTON (X) - Hide frame but keep playing
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

    -- BACK BUTTON (<<) - Replay previous from history
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
        else
            Debug("No history available")
        end
    end)
    self.frame.backBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Replay Last")
        if table.getn(SoundQueue.history) > 0 then
            GameTooltip:AddLine(SoundQueue.history[1].npcName or "Unknown", 1, 1, 1)
        else
            GameTooltip:AddLine("No history", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    self.frame.backBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- PAUSE/PLAY BUTTON - Shows || for pause, > for play
    self.frame.pauseBtn = CreateFrame("Button", nil, self.frame)
    self.frame.pauseBtn:SetWidth(24)
    self.frame.pauseBtn:SetHeight(24)
    self.frame.pauseBtn:SetPoint("BOTTOMRIGHT", -25, 8)
    self.frame.pauseBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
    -- Create pause icon (two vertical bars)
    self.frame.pauseBtn.pauseIcon = self.frame.pauseBtn:CreateTexture(nil, "ARTWORK")
    self.frame.pauseBtn.pauseIcon:SetAllPoints()
    self.frame.pauseBtn.pauseIcon:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\QuestLogStopButton")
    
    -- Create play icon (triangle pointing right)
    self.frame.pauseBtn.playIcon = self.frame.pauseBtn:CreateTexture(nil, "ARTWORK")
    self.frame.pauseBtn.playIcon:SetAllPoints()
    self.frame.pauseBtn.playIcon:SetTexture("Interface\\AddOns\\BetterQuest\\Textures\\QuestLogPlayButton")
    
    self.frame.pauseBtn:SetScript("OnClick", function() 
        SoundQueue:TogglePause() 
    end)
    self.frame.pauseBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        if SoundQueue.isPaused then
            GameTooltip:SetText("Resume")
        else
            GameTooltip:SetText("Pause")
        end
        GameTooltip:Show()
    end)
    self.frame.pauseBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    self.frame:Hide()
end

function SoundQueue:UpdateUI()
    if not self.frame then self:InitializeUI() end
    
    local current = self:GetCurrentSound()
    if not current then
        self.frame:Hide()
        return
    end
    
    -- Update portrait
    local portraitTexture = GetPortraitTexture(current)
    self.frame.portrait.texture:SetTexture(portraitTexture)
    
    -- Update currently playing info
    self.frame.npcName:SetText(current.npcName or "Unknown")
    self.frame.title:SetText(current.title or "")
    
    -- Update pause button texture based on state
    if self.isPaused then
        -- Show PLAY icon (triangle) when paused
        self.frame.pauseBtn.pauseIcon:Hide()
        self.frame.pauseBtn.playIcon:Show()
        self.frame.status:SetText("|cffff0000PAUSED|r")
    else
        -- Show PAUSE icon (||) when playing  
        self.frame.pauseBtn.pauseIcon:Show()
        self.frame.pauseBtn.playIcon:Hide()
        
        -- Show elapsed time
        local elapsed = GetTime() - current.startTime
        local remaining = current.duration - elapsed
        if remaining < 0 then remaining = 0 end
        self.frame.status:SetText(string.format("|cff00ff00Playing|r %.0fs", remaining))
    end
    
    -- Update queue list (skip index 1 which is currently playing)
    local queueSize = table.getn(self.sounds)
    local displayCount = 0
    
    for i = 2, queueSize do
        displayCount = displayCount + 1
        if displayCount <= self.maxQueueDisplay then
            local soundData = self.sounds[i]
            local btn = self.frame.queueButtons[displayCount]
            btn.index = i
            btn.text:SetText(string.format("%d. %s - %s", displayCount, soundData.npcName or "Unknown", soundData.title or ""))
            btn:Show()
        end
    end
    
    -- Hide unused buttons
    for i = displayCount + 1, self.maxQueueDisplay do
        self.frame.queueButtons[i]:Hide()
    end
    
    -- Show/hide queue header
    if displayCount > 0 then
        self.frame.queueHeader:Show()
    else
        self.frame.queueHeader:Hide()
    end
    
    self.frame:Show()
end

-------------------------------------------------
-- SLASH COMMANDS
-------------------------------------------------

SLASH_SOUNDQUEUE1 = "/bq"
SLASH_SOUNDQUEUE2 = "/soundqueue"

SlashCmdList["SOUNDQUEUE"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "show" then
        if SoundQueue.frame then
            SoundQueue.frame:Show()
            SoundQueue:UpdateUI()
        end
    elseif msg == "history" then
        if table.getn(SoundQueue.history) == 0 then
            Debug("No history available")
        else
            Debug("=== History (" .. table.getn(SoundQueue.history) .. " entries) ===")
            for i = 1, math.min(10, table.getn(SoundQueue.history)) do
                local entry = SoundQueue.history[i]
                Debug(i .. ". " .. (entry.npcName or "Unknown") .. " - " .. (entry.title or ""))
            end
        end
    elseif msg == "clear" or msg == "clearhistory" then
        SoundQueue:ClearHistory()
    elseif string.find(msg, "play ") == 1 then
        local index = tonumber(string.sub(msg, 6))
        if index then
            SoundQueue:PlayFromHistory(index)
        else
            Debug("Usage: /bq play <number>")
        end
    elseif msg == "pause" then
        SoundQueue:TogglePause()
    else
        Debug("Commands:")
        Debug("/bq show - Show the frame")
        Debug("/bq history - Show recent voiceovers")
        Debug("/bq play <number> - Replay from history")
        Debug("/bq clear - Clear history")
        Debug("/bq pause - Toggle pause/resume")
    end
end

-------------------------------------------------
-- INITIALIZE
-------------------------------------------------

function SoundQueue:Initialize()
    if not FindDialogSound then return end
    
    self:InitializeUI()
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_DETAIL")
    eventFrame:RegisterEvent("QUEST_PROGRESS")
    eventFrame:RegisterEvent("QUEST_COMPLETE")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")
    eventFrame:RegisterEvent("QUEST_FINISHED")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "QUEST_DETAIL" then
            SoundQueue:AddSound(UnitName("npc"), GetQuestText(), GetTitleText())
        elseif event == "QUEST_PROGRESS" then
            SoundQueue:AddSound(UnitName("npc"), GetProgressText(), GetTitleText())
        elseif event == "QUEST_COMPLETE" then
            SoundQueue:AddSound(UnitName("npc"), GetRewardText(), GetTitleText())
        elseif event == "GOSSIP_SHOW" then
            SoundQueue:AddSound(UnitName("npc"), GetGossipText(), UnitName("npc"))
        elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
            -- Optional: Clear queue on close? 
            -- Better to let it finish playing as the player walks away.
        end
    end)
    
    Debug("Initialized - Type /bq for commands")
end

SoundQueue:Initialize()