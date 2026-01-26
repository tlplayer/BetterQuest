-- SoundQueue.lua
-- All-in-one voice-over system for WoW 1.12.1
-- DEBUG ALWAYS ON

SoundQueue = {
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    isPaused = false, -- NEW: Track pause state
    updateFrame = nil,
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


--CONTROLS

function SoundQueue:PlaySound(soundData)
    if not soundData then return end

    Utils:PlaySound(soundData)  -- safe 1.12 wrapper
    soundData.startTime = GetTime()
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
    self:UpdateUI()
end

local function StopSound(soundData)
    if not soundData then return end
    Utils:StopSound(soundData)  -- use Utils
    Debug("Stopped sound: " .. tostring(soundData.filePath))
end

function SoundQueue:TogglePause()
    local current = self.currentSound
    if not current then
        Debug("TogglePause called but no current sound")
        return
    end

    self.isPaused = not self.isPaused

    if self.isPaused then
        local elapsed = GetTime() - (current.startTime or GetTime())
        current.remaining = (current.duration or 0) - elapsed
        if current.remaining < 0 then current.remaining = 0 end
        StopSound(current)
        Debug("Paused sound with remaining: " .. tostring(current.remaining))
    else
        current.startTime = GetTime()
        current.duration = current.remaining or current.duration
        self:PlaySound(current)
        Debug("Resumed sound")
    end

    self:UpdateUI()
end

function SoundQueue:SkipCurrent()
    local current = self.currentSound
    if not current then
        Debug("SkipCurrent called but no current sound")
        return
    end

    StopSound(current)
    self:RemoveSound(current)
    Debug("Skipped current sound: " .. (current.npcName or "Unknown"))
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

-------------------------------------------------
-- PLAYBACK
-------------------------------------------------

function SoundQueue:PlaySound(soundData)
    if not soundData then return end
    
    local path = NormalizePath(soundData.filePath)
    local willPlay, handle = PlaySoundFile(path)
    soundData.handle = handle
    
    soundData.startTime = GetTime()
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
    self:UpdateUI()
end

function SoundQueue:CheckSoundFinished()
    -- If paused, we don't tick the timer forward
    if not self.currentSound or self.isPaused then return end
    
    local elapsed = GetTime() - self.currentSound.startTime
    if elapsed >= self.currentSound.duration then
        Debug("Sound finished naturally")
        self:RemoveSound(self.currentSound)
    end
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
-- UI
-------------------------------------------------

function SoundQueue:InitializeUI()
    if self.frame then return end
    
    self.frame = CreateFrame("Frame", "BetterQuestVoiceOverFrame", UIParent)
    self.frame:SetWidth(300)
    self.frame:SetHeight(80)
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    
    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, 0.7)
    
    self.frame.npcName = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.npcName:SetPoint("TOPLEFT", 10, -10)
    
    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.title:SetPoint("TOPLEFT", 10, -25)
    self.frame.title:SetTextColor(0.7, 0.7, 0.7)
    
    self.frame.status = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.status:SetPoint("BOTTOMLEFT", 10, 10)

    -- SKIP BUTTON (X)
    self.frame.skipBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.skipBtn:SetPoint("TOPRIGHT", -2, -2)
    self.frame.skipBtn:SetWidth(24)
    self.frame.skipBtn:SetHeight(24)
    self.frame.skipBtn:SetScript("OnClick", function() SoundQueue:SkipCurrent() end)

    -- PAUSE BUTTON (Arrow)
    self.frame.pauseBtn = CreateFrame("Button", nil, self.frame)
    self.frame.pauseBtn:SetWidth(20)
    self.frame.pauseBtn:SetHeight(20)
    self.frame.pauseBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    self.frame.pauseBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    self.frame.pauseBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    self.frame.pauseBtn:SetScript("OnClick", function() SoundQueue:TogglePause() end)
    
    self.frame:Hide()
end

function SoundQueue:UpdateUI()
    if not self.frame then self:InitializeUI() end
    
    local current = self:GetCurrentSound()
    if not current then
        self.frame:Hide()
        return
    end
    
    self.frame.npcName:SetText(current.npcName or "Unknown")
    self.frame.title:SetText(current.title or "")
    
    if self.isPaused then
        self.frame.status:SetText("|cffff0000PAUSED|r")
    else
        self.frame.status:SetText("|cff00ff00Playing...|r")
    end
    
    self.frame:Show()
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
end

SoundQueue:Initialize()