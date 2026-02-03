-- soundqueue.lua
-- Sound queue state, playback, history, missing-NPC logging, slash commands.
-- Load order: 2 of 4  (utils → soundqueue → ui → core)
--
-- Globals exported:
--   SoundQueue   — the central queue table
--
-- Dependencies (must already be loaded):
--   Debug, NormalizeNPCName, NormalizeDialogText, NormalizePath, FindDialogSound   ← utils.lua
--
-- UI stubs (attached by ui.lua after it loads):
--   SoundQueue:InitializeUI()
--   SoundQueue:UpdatePortrait(soundData)
--   SoundQueue:UpdateCurrentInfo(soundData)
--   SoundQueue:UpdatePauseButton()
--   SoundQueue:UpdateStatusText()
--   SoundQueue:UpdateQueueList()
--   SoundQueue:ShowFrame()
--   SoundQueue:HideFrame()

-------------------------------------------------
-- TABLE DEFINITION
-------------------------------------------------

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

-------------------------------------------------
-- SAFE UI STUBS
-- ui.lua will overwrite these once it loads.
-- Having no-op defaults means soundqueue never errors if ui hasn't attached yet.
-------------------------------------------------
function SoundQueue:InitializeUI()        end
function SoundQueue:UpdatePortrait()      end
function SoundQueue:UpdateCurrentInfo()   end
function SoundQueue:UpdatePauseButton()   end
function SoundQueue:UpdateStatusText()    end
function SoundQueue:UpdateQueueList()     end
function SoundQueue:ShowFrame()           end
function SoundQueue:HideFrame()           end

-------------------------------------------------
-- MISSING-NPC TRACKING
-------------------------------------------------

function SoundQueue:InitializeBetterQuestDB()
    if not BetterQuestDB then
        BetterQuestDB = { missingNPCs = {} }
        Debug("BetterQuestDB initialized")
    end
end

function SoundQueue:LogMissingNPC(npcName, dialogText, dialogType)
    if not BetterQuestDB or not npcName or not dialogText then return end

    local normalizedName = NormalizeNPCName(npcName)
    local normalizedText = NormalizeDialogText(dialogText)
    if normalizedText == "" then return end

    if not BetterQuestDB.missingNPCs[normalizedName] then
        BetterQuestDB.missingNPCs[normalizedName] = {
            originalName = npcName,
            dialogs      = {},
        }
    end

    local npcEntry = BetterQuestDB.missingNPCs[normalizedName]
    if not npcEntry.dialogs[normalizedText] then
        npcEntry.dialogs[normalizedText] = {
            dialog_text = dialogText,
            dialogType  = dialogType or "gossip",
            count       = 0,
        }
    end
    npcEntry.dialogs[normalizedText].count = npcEntry.dialogs[normalizedText].count + 1
end

function SoundQueue:ExportMissingNPCs()
    if not BetterQuestDB or not BetterQuestDB.missingNPCs then
        Debug("No missing NPC data to export")
        return
    end

    local npcCount, totalDialogs = 0, 0
    Debug("=== MISSING NPCs ===")

    for _, data in pairs(BetterQuestDB.missingNPCs) do
        npcCount = npcCount + 1
        local dialogCount = 0
        for _ in pairs(data.dialogs) do
            dialogCount   = dialogCount + 1
            totalDialogs  = totalDialogs + 1
        end
        Debug(string.format("%d. %s (%d dialog(s))", npcCount, data.originalName, dialogCount))
    end

    Debug(string.format("Total: %d missing NPCs, %d missing dialogs", npcCount, totalDialogs))
end

function SoundQueue:ClearMissingNPCs()
    if BetterQuestDB then
        BetterQuestDB.missingNPCs = {}
        Debug("Missing NPC database cleared")
    end
end

-------------------------------------------------
-- HISTORY
-------------------------------------------------

function SoundQueue:AddToHistory(soundData)
    if not soundData then return end

    table.insert(self.history, 1, {
        npcName    = soundData.npcName,
        text       = soundData.text,
        title      = soundData.title,
        filePath   = soundData.filePath,
        dialogType = soundData.dialogType,
        questID    = soundData.questID,
        duration   = soundData.duration,
    })

    while table.getn(self.history) > self.maxHistorySize do
        table.remove(self.history)
    end
end

function SoundQueue:PlayFromHistory(index)
    local entry = self.history[index]
    if not entry then return end

    local soundData = {
        npcName      = entry.npcName,
        text         = entry.text,
        title        = entry.title,
        filePath     = entry.filePath,
        dialogType   = entry.dialogType,
        questID      = entry.questID,
        duration     = entry.duration,
        startTime    = 0,
        pauseOffset  = 0,
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
        soundData.startTime  = GetTime() - soundData.pauseOffset
        soundData.isResuming = nil
        Debug("Resuming from: " .. soundData.pauseOffset)
    else
        soundData.startTime  = GetTime()
        soundData.pauseOffset = 0
    end

    self.currentSound = soundData
    self.isPlaying    = true
    self.isPaused     = false

    -- Ensure the per-frame finished-check is running
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function()
            SoundQueue:CheckSoundFinished()
        end)
    end
    self.updateFrame:Show()

    -- Refresh every piece of the UI
    self:UpdatePortrait(soundData)
    self:UpdateCurrentInfo(soundData)
    self:UpdatePauseButton()
    self:UpdateStatusText()
    self:UpdateQueueList()
    self:ShowFrame()

    Debug("PlaySound complete")
end

function SoundQueue:StopSound(soundData)
    if not soundData then return end
    -- Classic-era trick: toggling MasterSoundEffects kills all active sounds
    SetCVar("MasterSoundEffects", 0)
    SetCVar("MasterSoundEffects", 1)
    soundData.handle = nil
end

function SoundQueue:TogglePause()
    local current = self.currentSound
    if not current then return end

    if not self.isPaused then
        -- PAUSE — snapshot how far we are, then kill audio
        Debug("Pausing")
        current.pauseOffset = GetTime() - current.startTime
        self:StopSound(current)
        self.isPaused  = true
        self.isPlaying = false

        self:UpdatePauseButton()
        self:UpdateStatusText()
    else
        -- RESUME — re-enter PlaySound with the offset baked in
        Debug("Resuming")
        current.isResuming = true
        self:PlaySound(current)
    end
end

function SoundQueue:CheckSoundFinished()
    if not self.currentSound or self.isPaused then return end

    self:UpdateStatusText()

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
    Debug("AddSound: " .. tostring(npcName))

    local soundPath, dialogType, questID, seconds = FindDialogSound(npcName, dialogText)

    if not soundPath then
        Debug("No sound found — logging to BetterQuestDB")
        self:LogMissingNPC(npcName, dialogText, dialogType or "unknown")
        return
    end

    local soundData = {
        npcName      = npcName,
        text         = dialogText,
        title        = title or (questID and ("Quest " .. questID) or npcName),
        filePath     = soundPath,
        dialogType   = dialogType,
        questID      = questID,
        duration     = seconds or 15,
        startTime    = 0,
        pauseOffset  = 0,
    }

    -- Deduplicate by file path
    for _, queued in ipairs(self.sounds) do
        if queued.filePath == soundData.filePath then
            Debug("Duplicate, skipping")
            return
        end
    end

    table.insert(self.sounds, soundData)
    Debug("Added to queue (size: " .. table.getn(self.sounds) .. ")")

    if table.getn(self.sounds) == 1 then
        self:PlaySound(soundData)     -- first in queue → play immediately
    else
        self:UpdateQueueList()        -- already playing → just refresh the list
    end
end

function SoundQueue:RemoveSound(soundData)
    if not soundData then return end
    Debug("RemoveSound: " .. tostring(soundData.npcName))

    -- Find the index of this exact entry
    local removedIndex = nil
    for i = 1, table.getn(self.sounds) do
        if self.sounds[i] == soundData then
            removedIndex = i
            break
        end
    end
    if not removedIndex then
        Debug("Sound not found in queue")
        return
    end

    table.remove(self.sounds, removedIndex)
    Debug("Removed from queue")

    if removedIndex == 1 then
        -- The item that was playing just left → advance
        self:AddToHistory(soundData)

        self.currentSound = nil
        self.isPlaying    = false
        self.isPaused     = false

        local nextSound = self:GetCurrentSound()
        if nextSound then
            Debug("Playing next")
            self:PlaySound(nextSound)
        else
            Debug("Queue empty")
            if self.updateFrame then self.updateFrame:Hide() end
            self:HideFrame()
        end
    else
        -- A queued (non-playing) item was removed
        self:UpdateQueueList()
    end
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
            SoundQueue:ShowFrame()
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
        if index then SoundQueue:PlayFromHistory(index) end

    elseif msg == "pause" then
        SoundQueue:TogglePause()

    elseif msg == "missing" then
        SoundQueue:ExportMissingNPCs()

    elseif msg == "clearmissing" then
        SoundQueue:ClearMissingNPCs()

    else
        Debug("Commands: show, history, play <n>, clear, pause, missing, clearmissing")
    end
end