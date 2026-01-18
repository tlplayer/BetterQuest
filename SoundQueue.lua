-- SoundQueue.lua
-- Manages sequential voice-over playback with portrait UI

SoundQueue = {
    soundIdCounter = 0,
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    isPaused = false,
    soundHandle = nil,
    updateFrame = nil,
}

-------------------------------------------------
-- Debug
-------------------------------------------------
local function Debug(msg)
    if Config and Config.DEBUG then
        print("|cff88ccff[SoundQueue]|r " .. tostring(msg))
    end
end

-------------------------------------------------
-- Queue Management
-------------------------------------------------

function SoundQueue:GetQueueSize()
    return table.getn(self.sounds)
end

function SoundQueue:IsEmpty()
    return self:GetQueueSize() == 0
end

function SoundQueue:GetCurrentSound()
    return self.sounds[1]
end

function SoundQueue:GetNextSound()
    return self.sounds[2]
end

function SoundQueue:Contains(soundData)
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound == soundData then
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Sound Preparation and Validation
-------------------------------------------------

function SoundQueue:PrepareSound(soundData)
    -- Use the dialog map to find the sound file
    if not soundData.npcName or not soundData.text then
        Debug("Missing npcName or text in soundData")
        return false
    end
    
    local soundPath, dialogType, questID = FindDialogSound(soundData.npcName, soundData.text)
    
    if not soundPath then
        Debug("No sound file found for: " .. soundData.npcName)
        return false
    end
    print(soundPath)
    print(questID)
    
    soundData.filePath = soundPath
    soundData.dialogType = dialogType
    soundData.questID = questID
    
    return true
end

function SoundQueue:TestSound(soundData)
    if not soundData.filePath then
        return false
    end
    
    -- Test if file can be played
    local success, handle = PlaySoundFile(soundData.filePath, "Master")
    if success and handle then
        StopSound(handle)
        return true
    end
    
    return false
end

-------------------------------------------------
-- Add Sound to Queue
-------------------------------------------------

function SoundQueue:AddSoundToQueue(soundData)
    if not self:PrepareSound(soundData) then
        Debug("Sound does not exist for: " .. (soundData.npcName or "unknown"))
        return
    end
    
    if not Utils:IsSoundEnabled() then
        Debug("Your sound is turned off")
        return
    end
    
    if not self:TestSound(soundData) then
        Debug("Sound file exists but failed to play: " .. soundData.filePath)
        return
    end
    
    -- Check if the sound is already in the queue
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.fileName == soundData.fileName then
            return
        end
    end
    
    -- Don't play gossip if there are quest sounds in the queue
    local questSoundExists = false
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.questID then
            questSoundExists = true
            break
        end
    end
    
    if not soundData.questID and questSoundExists then
        return
    end
    
    self.soundIdCounter = self.soundIdCounter + 1
    soundData.id = self.soundIdCounter
    
    table.insert(self.sounds, soundData)
    
    if soundData.addedCallback then
        soundData.addedCallback(soundData)
    end
    
    -- If the sound queue only contains one sound, play it immediately
    if self:GetQueueSize() == 1 and not self.isPaused then
        self:PlaySound(soundData)
    end
    
    SoundQueueUI:UpdateSoundQueueDisplay()
end

-------------------------------------------------
-- Playback Control
-------------------------------------------------

function SoundQueue:PlaySound(soundData)
    if not soundData or not soundData.filePath then
        Debug("Invalid sound data")
        return
    end
    
    self.currentSound = soundData
    self.isPlaying = true
    
    -- Play the sound
    local success, handle = PlaySoundFile(
        soundData.filePath,
        Config.SOUND_CHANNEL or "Dialog"
    )
    
    if not success then
        Debug("Failed to play sound: " .. soundData.filePath)
        self:RemoveSoundFromQueue(soundData, true)
        return
    end
    
    self.soundHandle = handle
    soundData.handle = handle
    
    if soundData.startCallback then
        soundData.startCallback(soundData)
    end
    
    -- Start the update frame to detect when sound finishes
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function(frame, elapsed)
            SoundQueue:OnUpdate(elapsed)
        end)
    end
    self.updateFrame:Show()
    
    Debug("Playing: " .. soundData.npcName)
end

function SoundQueue:OnUpdate(elapsed)
    if not self.soundHandle then
        self.updateFrame:Hide()
        return
    end
    
    -- Check if sound is still playing
    local playing = IsSoundPlaying(self.soundHandle)
    if not playing then
        Debug("Sound finished")
        local soundData = self:GetCurrentSound()
        if soundData then
            self:RemoveSoundFromQueue(soundData, true)
        end
    end
end

function SoundQueue:CanBePaused()
    return self.soundHandle ~= nil
end

function SoundQueue:PauseQueue()
    if self.isPaused then
        return
    end
    
    self.isPaused = true
    
    local currentSound = self:GetCurrentSound()
    if currentSound and self:CanBePaused() then
        StopSound(currentSound.handle)
        self.isPlaying = false
        if self.updateFrame then
            self.updateFrame:Hide()
        end
    end
    
    SoundQueueUI:UpdatePauseDisplay()
end

function SoundQueue:ResumeQueue()
    if not self.isPaused then
        return
    end
    
    self.isPaused = false
    
    local currentSound = self:GetCurrentSound()
    if currentSound and self:CanBePaused() then
        self:PlaySound(currentSound)
    end
    
    SoundQueueUI:UpdateSoundQueueDisplay()
end

function SoundQueue:TogglePauseQueue()
    if self.isPaused then
        self:ResumeQueue()
    else
        self:PauseQueue()
    end
end

function SoundQueue:RemoveSoundFromQueue(soundData, finishedPlaying)
    local removedIndex = nil
    for index, queuedSound in ipairs(self.sounds) do
        if queuedSound.id == soundData.id then
            if index == 1 and not self:CanBePaused() and not finishedPlaying then
                return
            end
            
            removedIndex = index
            table.remove(self.sounds, index)
            break
        end
    end
    
    if not removedIndex then
        return
    end
    
    if soundData.stopCallback then
        soundData.stopCallback(soundData)
    end
    
    if removedIndex == 1 and not self.isPaused then
        if soundData.handle then
            StopSound(soundData.handle)
        end
        
        local nextSoundData = self:GetCurrentSound()
        if nextSoundData then
            self:PlaySound(nextSoundData)
        else
            self.isPlaying = false
            if self.updateFrame then
                self.updateFrame:Hide()
            end
        end
    end
    
    SoundQueueUI:UpdateSoundQueueDisplay()
end

function SoundQueue:RemoveAllSoundsFromQueue()
    for i = self:GetQueueSize(), 1, -1 do
        local queuedSound = self.sounds[i]
        if queuedSound then
            if i == 1 and not self:CanBePaused() then
                return
            end
            
            self:RemoveSoundFromQueue(queuedSound)
        end
    end
end

function SoundQueue:Stop()
    if self.soundHandle then
        StopSound(self.soundHandle)
    end
    self.isPlaying = false
    self.soundHandle = nil
    if self.updateFrame then
        self.updateFrame:Hide()
    end
end

function SoundQueue:Clear()
    self:RemoveAllSoundsFromQueue()
    self:Stop()
end