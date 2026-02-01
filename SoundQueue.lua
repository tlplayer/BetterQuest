-- SoundQueue.lua
-- All-in-one voice-over system for WoW 1.12.1
-- NO CENTRAL UpdateUI - Each function handles its own UI

SoundQueue = {
    sounds = {},
    currentSound = nil,
    isPlaying = false,
    isPaused = false,
    updateFrame = nil,
    delayFrame = nil,
    history = {},
    maxHistorySize = 50,
    maxQueueDisplay = 5,
    
    portraitConfig = {
        WIDTH = 80,
        HEIGHT = 80,
        PATH = "Interface\\AddOns\\BetterQuest\\Textures\\",
        DEFAULT_NPC = "Interface\\Icons\\INV_Misc_QuestionMark",
        DEFAULT_BOOK = "Interface\\AddOns\\BetterQuest\\Textures\\Book",
        PORTRAIT_PATH = "Interface\\AddOns\\BetterQuest\\portraits\\"
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

-- Database hookup code
function NormalizeDialogText(text)
  if not text then return "" end

  text = string.gsub(text, "%$B+", " ")
  text = string.gsub(text, "%$[nNrRcC]", "adventurer")
  text = string.gsub(text, "%$g[^;]*;", "adventurer")
  text = string.gsub(text, "%$%w+", "")
  text = string.gsub(text, "%b[]", "")
  text = string.gsub(text, "%b()", "")
  text = string.gsub(text, "%b<>", "")
  text = string.gsub(text, "%*[^%*]+%*", "")
  text = string.gsub(text, "[^%w%s]", "")
  text = string.gsub(text, "%s+", " ")

  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")

  text = string.lower(text)

  return string.sub(text, 1, 50)
end

local function NormalizeNPCName(name)
  if not name then return nil end
  name = string.gsub(name, "['']", "")
  return name
end

function GetNPCMetadata(npcName)
  if not npcName then return nil end
  local lookupName = NormalizeNPCName(npcName)
  local npc = NPC_DATABASE[lookupName]

  
  if npc then
    return {
      race = npc.race,
      sex = npc.sex,
      portrait = npc.portrait,
      zone = npc.zone,
      model_id = npc.model_id,
      narrator = npc.narrator
    }
  end
  
  return nil
end

-------------------------------------------------
-- MISSING NPC TRACKING
-------------------------------------------------

function SoundQueue:InitializeBetterQuestDB()
    if not BetterQuestDB then
        BetterQuestDB = {
            missingNPCs = {}
        }
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
            dialogs = {}
        }
    end
    
    local npcEntry = BetterQuestDB.missingNPCs[normalizedName]
    
    if not npcEntry.dialogs[normalizedText] then
        npcEntry.dialogs[normalizedText] = {
            dialog_text = dialogText,
            dialogType = dialogType or "gossip",
            count = 0
        }
    end
    
    npcEntry.dialogs[normalizedText].count = npcEntry.dialogs[normalizedText].count + 1
end

function SoundQueue:ExportMissingNPCs()
    if not BetterQuestDB or not BetterQuestDB.missingNPCs then
        Debug("No missing NPC data to export")
        return
    end
    
    local npcCount = 0
    local totalDialogs = 0
    
    Debug("=== MISSING NPCs ===")
    for normalizedName, data in pairs(BetterQuestDB.missingNPCs) do
        npcCount = npcCount + 1
        local dialogCount = 0
        
        for _, dialogData in pairs(data.dialogs) do
            dialogCount = dialogCount + 1
            totalDialogs = totalDialogs + 1
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
-- FUZZY TEXT MATCHING (Levenshtein Distance)
-------------------------------------------------

-- Compute Jaro distance
local function JaroSimilarity(s1, s2)
    local len1 = strlen(s1)
    local len2 = strlen(s2)

    if len1 == 0 and len2 == 0 then
        return 1
    end

    local matchDist = math.floor(math.max(len1, len2) / 2) - 1
    if matchDist < 0 then matchDist = 0 end

    local s1Match = {}
    local s2Match = {}
    local matches = 0

    -- Find matches
    for i = 1, len1 do
        local c1 = strsub(s1, i, i)
        local start = i - matchDist
        if start < 1 then start = 1 end
        local finish = i + matchDist
        if finish > len2 then finish = len2 end

        for j = start, finish do
            if not s2Match[j] and c1 == strsub(s2, j, j) then
                s1Match[i] = true
                s2Match[j] = true
                matches = matches + 1
                break
            end
        end
    end

    if matches == 0 then
        return 0
    end

    -- Count transpositions
    local t = 0
    local k = 1
    for i = 1, len1 do
        if s1Match[i] then
            while not s2Match[k] do
                k = k + 1
            end
            if strsub(s1, i, i) ~= strsub(s2, k, k) then
                t = t + 1
            end
            k = k + 1
        end
    end

    t = t / 2

    return (matches / len1 + matches / len2 + (matches - t) / matches) / 3
end

local function JaroWinkler(s1, s2)
    local j = JaroSimilarity(s1, s2)

    local prefix = 0
    local maxPrefix = 4
    local len1 = strlen(s1)
    local len2 = strlen(s2)
    local max = maxPrefix
    if len1 < max then max = len1 end
    if len2 < max then max = len2 end

    for i = 1, max do
        if strsub(s1, i, i) == strsub(s2, i, i) then
            prefix = prefix + 1
        else
            break
        end
    end

    return j + prefix * 0.1 * (1 - j)
end


function FuzzyFindDialogSound(npcName, dialogText)
    if not npcName or not dialogText then return nil end

    local lookupName = NormalizeNPCName(npcName)
    local targetNpc  = NPC_DATABASE[lookupName]
    local targetSex  = targetNpc and targetNpc.sex
    local targetRace = targetNpc and targetNpc.race

    local normalizedInput = NormalizeDialogText(dialogText)
    if normalizedInput == "" then return nil end

    local JW_THRESHOLD = 0.88

    -- Early check: same NPC first
    if targetNpc and targetNpc.dialogs then
        for dialogKey, entry in pairs(targetNpc.dialogs) do
            local score = JaroWinkler(normalizedInput, dialogKey)
            if score >= JW_THRESHOLD then
                -- Immediately return first high-confidence match
                return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
            end
        end
    end

    -- Fallback: search other NPCs with same sex + race
    for _, data in pairs(NPC_DATABASE) do
        if data ~= targetNpc
           and (not targetRace or data.race == targetRace)
           and (not targetSex  or data.sex  == targetSex) 
           and data.dialogs then

            for dialogKey, entry in pairs(data.dialogs) do
                local score = JaroWinkler(normalizedInput, dialogKey)
                if score >= JW_THRESHOLD then
                    -- Early return on first match
                    return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
                end
            end
        end
    end

    -- Nothing found
    return nil
end




function FindDialogSound(npcName, dialogText)
  if not npcName or not dialogText then return nil end

  local lookupName = NormalizeNPCName(npcName)
  local key = NormalizeDialogText(dialogText)
  if key == "" then return nil end

  -- 1) Normal lookup (expected case)
  local npc = NPC_DATABASE[lookupName]
  if npc and npc.dialogs and npc.dialogs[key] then
    local entry = npc.dialogs[key]
    return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
  end

  -- 2) Fallback: search all NPCs by text hash
  for otherNpcName, data in pairs(NPC_DATABASE) do
    if data.dialogs then
      local entry = data.dialogs[key]
      if entry then
        return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
      end
    end
  end

  -- 3) Fuzzy text search with Levenshtein distance
  local fuzzyPath, fuzzyDialogType, fuzzyQuestID, fuzzySeconds = FuzzyFindDialogSound(npcName, dialogText)
  if fuzzyPath then
    return fuzzyPath, fuzzyDialogType, fuzzyQuestID, fuzzySeconds
  end

  return nil
end


-------------------------------------------------
-- PORTRAIT HELPERS
-------------------------------------------------


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
    print(npcName)
    if npcName then
        local metadata = GetNPCMetadata(npcName)
        if metadata and metadata.race then
            local filename = metadata.race
            if metadata.sex == "female" then
                filename = filename .. "_female"
            end
            return SoundQueue.portraitConfig.PORTRAIT_PATH .. filename .. ".tga"
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
        Debug("No sound found - logging to BetterQuestDB")
        self:LogMissingNPC(npcName, dialogText, dialogType or "unknown")
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
    self.frame.portrait.border:SetTexCoord(0, 1.1, 0, 1.1)
    
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
    elseif msg == "missing" then
        SoundQueue:ExportMissingNPCs()
    elseif msg == "clearmissing" then
        SoundQueue:ClearMissingNPCs()
    else
        Debug("Commands: show, history, play <n>, clear, pause, missing, clearmissing")
    end
end


-------------------------------------------------
-- DELAYED TRIGGER LOGIC
-------------------------------------------------

-- This function waits 0.1s to ensure Quest/Gossip text is fully loaded
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
            this:SetScript("OnUpdate", nil) -- Stop the loop
            
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
            SoundQueue:InitializeBetterQuestDB()
            SoundQueue:InitializeUI()
            
            local gameEventFrame = CreateFrame("Frame")
            gameEventFrame:RegisterEvent("QUEST_DETAIL")
            gameEventFrame:RegisterEvent("QUEST_PROGRESS")
            gameEventFrame:RegisterEvent("QUEST_COMPLETE")
            gameEventFrame:RegisterEvent("GOSSIP_SHOW")
            
            gameEventFrame:SetScript("OnEvent", function()
                SoundQueue:QueueTrigger(UnitName("npc"), event)
            end)
            
            Debug("SoundQueue Initialized with Missing NPC Tracking and Fuzzy Text Matching")
        end
    end)
end


SoundQueue:Initialize()