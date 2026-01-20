-- SoundQueue.lua
-- All-in-one voice-over system for WoW 1.12.1
-- DEBUG ALWAYS ON

SoundQueue = {
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    updateFrame = nil,
}

-------------------------------------------------
-- DEBUG (ALWAYS ON)
-------------------------------------------------

local function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[SoundQueue]|r " .. tostring(msg))
end

-------------------------------------------------
-- PATH NORMALIZATION
-------------------------------------------------

local function NormalizePath(path)
    if not path then return nil end

    -- Convert any forward slashes to backslashes

    -- Collapse double backslashes just in case
    path = string.gsub(path, "\\+", "\\")

    return path
end


-------------------------------------------------
-- QUEUE MANAGEMENT
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

-------------------------------------------------
-- SOUND LOOKUP
-------------------------------------------------

function SoundQueue:FindSound(npcName, dialogText)
    Debug("FindSound - NPC: " .. tostring(npcName))
    
    if not npcName or not dialogText then
        Debug("ERROR: Missing npcName or dialogText")
        return nil
    end
    
    if not FindDialogSound then
        Debug("ERROR: FindDialogSound not available")
        return nil
    end
    
    Debug("Calling FindDialogSound...")
    local soundPath, dialogType, questID, seconds = FindDialogSound(npcName, dialogText)    

    Debug("Result: path=" .. tostring(soundPath) .. ", type=" .. tostring(dialogType) .. ", qid=" .. tostring(questID))
    
    if not soundPath then
        Debug("No sound found")
        return nil
    end
    
    return soundPath, dialogType, questID, seconds
end

-------------------------------------------------
-- ADD SOUND
-------------------------------------------------

function SoundQueue:AddSound(npcName, dialogText, title)
    Debug("========================================")
    Debug("AddSound called")
    Debug("NPC: " .. tostring(npcName))
    Debug("Title: " .. tostring(title))
    
    local soundPath, dialogType, questID,seconds = self:FindSound(npcName, dialogText)
    
    if not soundPath then
        Debug("FindSound returned nil, aborting")
        return
    end
    
    Debug("Creating soundData...")
    local soundData = {
        npcName = npcName,
        text = dialogText,
        title = title or (questID and ("Quest " .. questID) or npcName),
        filePath = soundPath,
        dialogType = dialogType,
        questID = questID,
        duration  = seconds or 15,  -- fallback safety
    }
    
    Debug("soundData.filePath = " .. soundData.filePath)
    
    -- Don't add duplicates
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.filePath == soundData.filePath then
            Debug("Already queued")
            return
        end
    end
    
    -- Don't add gossip if quest exists
    if not questID then
        for _, queuedSound in ipairs(self.sounds) do
            if queuedSound.questID then
                Debug("Skipping gossip (quest in queue)")
                return
            end
        end
    end
    
    table.insert(self.sounds, soundData)
    Debug("Added to queue, size now: " .. self:GetQueueSize())
    
    if self:GetQueueSize() == 1 then
        Debug("First in queue, playing immediately")
        self:PlaySound(soundData)
    end
    
    Debug("Calling UpdateUI...")
    self:UpdateUI()
    Debug("========================================")
end

-------------------------------------------------
-- PLAYBACK
-------------------------------------------------



function SoundQueue:PlaySound(soundData)
    Debug("========================================")
    Debug("PlaySound called")
    
    if not soundData or not soundData.filePath then
        Debug("ERROR: Invalid sound data")
        return
    end
    
    Debug("Original path: " .. soundData.filePath)
    local path = NormalizePath(soundData.filePath) 
    Debug("Normalized path: " .. path)
    
    -- In WoW 1.12.1, PlaySoundFile doesn't return reliable values
    -- Just call it and hope for the best
    Debug("Calling PlaySoundFile(path, 'Master')...")
    PlaySoundFile(path)
    Debug("PlaySoundFile called (no return value checked)")
    
    soundData.startTime = GetTime()
    
    self.currentSound = soundData
    self.isPlaying = true
    
    Debug("Set as current sound")
    Debug("Duration seconds:" .. tostring(soundData.duration))
    Debug("NPC: " .. soundData.npcName)
    
    -- Start timer to auto-advance queue
    if not self.updateFrame then
        Debug("Creating update frame...")
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function()
            SoundQueue:CheckSoundFinished()
        end)
    end
    self.updateFrame:Show()
    Debug("Update frame started")
    
    Debug("Calling UpdateUI...")
    self:UpdateUI()
    Debug("========================================")
end

function SoundQueue:CheckSoundFinished()
    if not self.currentSound then
        if self.updateFrame then
            self.updateFrame:Hide()
        end
        return
    end
    
    local elapsed = GetTime() - self.currentSound.startTime
    
    if elapsed >= self.currentSound.duration then
        Debug("Timer expired, removing sound")
        self:RemoveSound(self.currentSound)
    end
end

function SoundQueue:RemoveSound(soundData)
    Debug("RemoveSound called for: " .. (soundData.npcName or "unknown"))
    
    local removedIndex = nil
    for i, queuedSound in ipairs(self.sounds) do
        if queuedSound == soundData then
            removedIndex = i
            table.remove(self.sounds, i)
            break
        end
    end
    
    if not removedIndex then
        Debug("Sound not in queue")
        return
    end
    
    Debug("Removed from index " .. removedIndex)
    
    if removedIndex == 1 then
        self.currentSound = nil
        self.isPlaying = false
        
        local nextSound = self:GetCurrentSound()
        if nextSound then
            Debug("Playing next sound")
            self:PlaySound(nextSound)
        else
            Debug("Queue empty")
            if self.updateFrame then
                self.updateFrame:Hide()
            end
        end
    end
    
    self:UpdateUI()
end

function SoundQueue:Stop()
    Debug("Stop called")
    self.currentSound = nil
    self.isPlaying = false
    if self.updateFrame then
        self.updateFrame:Hide()
    end
end

function SoundQueue:Clear()
    Debug("Clear called")
    while self:GetQueueSize() > 0 do
        self:RemoveSound(self.sounds[1])
    end
    self:Stop()
end

-------------------------------------------------
-- UI
-------------------------------------------------

function SoundQueue:InitializeUI()
    if self.frame then
        Debug("UI already initialized")
        return
    end
    
    Debug("Initializing UI...")
    
    self.frame = CreateFrame("Frame", "BetterQuestVoiceOverFrame", UIParent)
    self.frame:SetWidth(350)
    self.frame:SetHeight(100)
    self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
    self.frame:Hide()
    
    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints()
    self.frame.bg:SetTexture(0, 0, 0, 0.8)
    
    self.frame.npcName = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.frame.npcName:SetPoint("TOP", 0, -10)
    self.frame.npcName:SetTextColor(1, 0.82, 0)
    
    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.title:SetPoint("TOP", 0, -30)
    self.frame.title:SetTextColor(0.8, 0.8, 0.8)
    
    self.frame.status = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.status:SetPoint("BOTTOM", 0, 10)
    self.frame.status:SetTextColor(0.5, 1, 0.5)
    
    Debug("UI initialized successfully")
end

function SoundQueue:UpdateUI()
    Debug("UpdateUI called")
    
    if not self.frame then
        self:InitializeUI()
    end
    
    local currentSound = self:GetCurrentSound()
    
    if not currentSound then
        Debug("No current sound, hiding frame")
        self.frame:Hide()
        return
    end
    
    Debug("Current sound exists: " .. currentSound.npcName)
    
    self.frame.npcName:SetText(currentSound.npcName or "Unknown NPC")
    
    local titleText = currentSound.title or ""
    if currentSound.questID then
        titleText = titleText .. " (Quest)"
    else
        titleText = titleText .. " (Gossip)"
    end
    self.frame.title:SetText(titleText)
    
    if self.isPlaying then
        self.frame.status:SetText("Playing...")
        self.frame.status:SetTextColor(0.5, 1, 0.5)
    else
        self.frame.status:SetText("Ready")
        self.frame.status:SetTextColor(0.8, 0.8, 0.8)
    end
    
    self.frame:Show()
    Debug("Frame shown")
end

-------------------------------------------------
-- EVENT HANDLERS
-------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnQuestDetail()
    Debug("*** QUEST_DETAIL event ***")
    
    local npcName = UnitName("npc") or UnitName("target")
    if not npcName then
        Debug("ERROR: Could not get NPC name")
        return
    end
    
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    
    if not questText or questText == "" then
        Debug("ERROR: No quest text")
        return
    end
    
    Debug("NPC: " .. npcName .. ", Title: " .. questTitle)
    SoundQueue:AddSound(npcName, questText, questTitle)
end

local function OnQuestProgress()
    Debug("*** QUEST_PROGRESS event ***")
    
    local npcName = UnitName("npc") or UnitName("target")
    if not npcName then
        return
    end
    
    local questTitle = GetTitleText()
    local progressText = GetProgressText()
    
    if not progressText or progressText == "" then
        return
    end
    
    SoundQueue:AddSound(npcName, progressText, questTitle)
end

local function OnQuestComplete()
    Debug("*** QUEST_COMPLETE event ***")
    
    local npcName = UnitName("npc") or UnitName("target")
    if not npcName then
        return
    end
    
    local questTitle = GetTitleText()
    local rewardText = GetRewardText()
    
    if not rewardText or rewardText == "" then
        return
    end
    
    SoundQueue:AddSound(npcName, rewardText, questTitle)
end

local function OnGossipShow()
    Debug("*** GOSSIP_SHOW event ***")
    
    local npcName = UnitName("npc") or UnitName("target")
    if not npcName then
        return
    end
    
    local gossipText = GetGossipText()
    
    if not gossipText or gossipText == "" then
        return
    end
    
    SoundQueue:AddSound(npcName, gossipText, npcName)
end

-------------------------------------------------
-- INITIALIZE
-------------------------------------------------

function SoundQueue:Initialize()
    Debug("========================================")
    Debug("INITIALIZING SOUNDQUEUE")
    Debug("========================================")
    
    if not FindDialogSound then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR: npc_dialog_map.lua required|r")
        return
    end
    
    Debug("FindDialogSound found")
    
    self:InitializeUI()
    
    Debug("Registering events...")
    eventFrame:RegisterEvent("QUEST_DETAIL")
    eventFrame:RegisterEvent("QUEST_PROGRESS")
    eventFrame:RegisterEvent("QUEST_COMPLETE")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("QUEST_FINISHED")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")
    
    eventFrame:SetScript("OnEvent", function()
        Debug("Event received: " .. tostring(event))
        
        if event == "QUEST_DETAIL" then
            OnQuestDetail()
        elseif event == "QUEST_PROGRESS" then
            OnQuestProgress()
        elseif event == "QUEST_COMPLETE" then
            OnQuestComplete()
        elseif event == "GOSSIP_SHOW" then
            OnGossipShow()
        end
    end)
    
    Debug("SoundQueue ready")
    Debug("========================================")
end

SoundQueue:Initialize()