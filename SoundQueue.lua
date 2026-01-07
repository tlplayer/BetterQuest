-- SoundQueue.lua
-- Responsible for sequential voice-over playback and speaker metadata

local ADDON_NAME = ...
SoundQueue = {}

-------------------------------------------------
-- Internal State
-------------------------------------------------

SoundQueue.queue = {}
SoundQueue.current = nil
SoundQueue.isPlaying = false

-- SoundHandle is required to stop sounds
SoundQueue.soundHandle = nil

-------------------------------------------------
-- Frame for update polling
-------------------------------------------------

SoundQueue.frame = CreateFrame("Frame")
SoundQueue.frame:Hide()

-------------------------------------------------
-- Utility
-------------------------------------------------

local function Debug(msg)
    if Config and Config.DEBUG then
        print("|cff88ccff[SoundQueue]|r " .. msg)
    end
end

-------------------------------------------------
-- Core Logic
-------------------------------------------------

function SoundQueue:Enqueue(soundData)
    if not soundData or not soundData.soundFile then
        Debug("Invalid soundData enqueued")
        return
    end

    table.insert(self.queue, soundData)
    Debug("Enqueued: " .. (soundData.speaker or "unknown"))

    if not self.isPlaying then
        self:PlayNext()
    end
end

function SoundQueue:PlayNext()
    if self.isPlaying then return end
    if #self.queue == 0 then
        self:ClearCurrent()
        return
    end

    self.current = table.remove(self.queue, 1)
    self.isPlaying = true

    Debug("Playing: " .. (self.current.speaker or "unknown"))

    -- PlaySoundFile returns success, handle
    local success, handle = PlaySoundFile(
        self.current.soundFile,
        Config.SOUND_CHANNEL or "Dialog"
    )

    if not success then
        Debug("Failed to play sound")
        self.isPlaying = false
        self:PlayNext()
        return
    end

    self.soundHandle = handle
    self.startTime = GetTime()
    self.frame:Show()

    -- Notify UI
    if self.OnVoiceStart then
        self:OnVoiceStart(self.current)
    end
end

function SoundQueue:Stop()
    if self.soundHandle then
        StopSound(self.soundHandle)
    end

    self.isPlaying = false
    self.frame:Hide()

    if self.OnVoiceStop then
        self:OnVoiceStop(self.current)
    end

    self:ClearCurrent()
end

function SoundQueue:Skip()
    Debug("Skipping voice")
    self:Stop()
    self:PlayNext()
end

function SoundQueue:Clear()
    self.queue = {}
    self:Stop()
end

function SoundQueue:IsPlaying()
    return self.isPlaying
end

function SoundQueue:GetCurrent()
    return self.current
end

function SoundQueue:ClearCurrent()
    self.current = nil
    self.soundHandle = nil
end

-------------------------------------------------
-- Frame Update (detect end of sound)
-------------------------------------------------

SoundQueue.frame:SetScript("OnUpdate", function(self, elapsed)
    -- WoW does not provide sound duration, so we rely on handle validity
    if not SoundQueue.soundHandle then
        SoundQueue.isPlaying = false
        SoundQueue.frame:Hide()
        SoundQueue:PlayNext()
        return
    end

    local playing = IsSoundPlaying(SoundQueue.soundHandle)
    if not playing then
        Debug("Sound finished")
        SoundQueue.isPlaying = false
        SoundQueue.frame:Hide()

        if SoundQueue.OnVoiceStop then
            SoundQueue:OnVoiceStop(SoundQueue.current)
        end

        SoundQueue:ClearCurrent()
        SoundQueue:PlayNext()
    end
end)
