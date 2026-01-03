-- Book.lua
-- Voiceover system for books, notes, and letters in WoW 1.12.1
-- Integrates with AI_VoiceOver SoundQueue system

-------------------------
-- CONFIGURATION
-------------------------

local BOOK_CONFIG = {
  SOUND_PATH = "Interface\\AddOns\\BetterQuestText\\sounds\\books\\",
  NARRATOR = "Narrator",
  ENABLED = true,
  DEBUG = true,
  USE_VOICEOVER_QUEUE = true, -- Use AI_VoiceOver's queue if available
}

-- Check if AI_VoiceOver is loaded
local HAS_VOICEOVER = false
local VoiceOverQueue = nil

-------------------------
-- BOOK DATABASE
-------------------------

-- This will be populated from db/bookdb.lua
BookDB = BookDB or {}

-------------------------
-- UTILITY FUNCTIONS
-------------------------

--- Debug logging
local function DebugLog(msg)
  if BOOK_CONFIG.DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[BookVO]|r " .. msg)
  end
end

--- Normalize text for fuzzy matching
local function NormalizeText(text)
  if not text then return "" end
  text = string.lower(text)
  text = string.gsub(text, "[%p%c]", "")
  text = string.gsub(text, "%s+", " ")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

--- Calculate Levenshtein distance
local function LevenshteinDistance(s1, s2)
  local len1 = string.len(s1)
  local len2 = string.len(s2)
  local matrix = {}
  
  for i = 0, len1 do
    matrix[i] = {[0] = i}
  end
  
  for j = 0, len2 do
    matrix[0][j] = j
  end
  
  for i = 1, len1 do
    for j = 1, len2 do
      local cost = (string.sub(s1, i, i) == string.sub(s2, j, j)) and 0 or 1
      matrix[i][j] = math.min(
        matrix[i-1][j] + 1,
        matrix[i][j-1] + 1,
        matrix[i-1][j-1] + cost
      )
    end
  end
  
  return matrix[len1][len2]
end

--- Calculate fuzzy match score (0-100)
local function FuzzyMatchScore(text1, text2)
  local norm1 = NormalizeText(text1)
  local norm2 = NormalizeText(text2)
  
  if norm1 == norm2 then return 100 end
  if norm1 == "" or norm2 == "" then return 0 end
  
  if string.find(norm1, norm2, 1, true) or string.find(norm2, norm1, 1, true) then
    return 85
  end
  
  local maxLen = math.max(string.len(norm1), string.len(norm2))
  local distance = LevenshteinDistance(norm1, norm2)
  local score = 100 * (1 - distance / maxLen)
  
  return math.max(0, score)
end

-------------------------
-- BOOK IDENTIFICATION
-------------------------

--- Get current book information from ItemTextFrame
local function GetCurrentBookInfo()
  if not ItemTextFrame or not ItemTextFrame:IsVisible() then
    return nil
  end
  
  local itemName = ItemTextGetItem()
  local pageText = ItemTextGetText() or ""
  
  return {
    itemName = itemName,
    pageText = pageText,
    page = ItemTextGetPage() or 1,
  }
end

--- Find audio file for current book
local function FindBookAudio(bookInfo)
  if not bookInfo or not BookDB then return nil end
  
  local itemName = bookInfo.itemName
  local pageText = bookInfo.pageText
  
  DebugLog("Searching for: " .. (itemName or "Unknown"))
  
  -- Priority 1: Exact item name match
  if BookDB.byName and itemName then
    local exactMatch = BookDB.byName[itemName]
    if exactMatch then
      DebugLog("Found exact name match: " .. itemName)
      return exactMatch
    end
  end
  
  -- Priority 2: Fuzzy name matching
  if BookDB.fuzzyList and itemName then
    local bestScore = 0
    local bestMatch = nil
    
    for dbName, audioFile in pairs(BookDB.fuzzyList) do
      local score = FuzzyMatchScore(itemName, dbName)
      if score > bestScore and score > 70 then
        bestScore = score
        bestMatch = audioFile
      end
    end
    
    if bestMatch then
      DebugLog(string.format("Found fuzzy match (%.1f%%): %s", bestScore, bestMatch))
      return bestMatch
    end
  end
  
  -- Priority 3: Text content matching
  if BookDB.byFirstLine and pageText then
    local firstLine = string.match(pageText, "^([^\n]+)")
    if firstLine then
      local normalized = NormalizeText(firstLine)
      if BookDB.byFirstLine[normalized] then
        DebugLog("Found match by first line")
        return BookDB.byFirstLine[normalized]
      end
    end
  end
  
  DebugLog("No audio found")
  return nil
end

-------------------------
-- AI_VOICEOVER INTEGRATION
-------------------------

--- Check if AI_VoiceOver is available and get queue reference
local function InitVoiceOverIntegration()
  if VoiceOver and VoiceOver.SoundQueue then
    HAS_VOICEOVER = true
    VoiceOverQueue = VoiceOver.SoundQueue
    DebugLog("AI_VoiceOver integration enabled")
    return true
  end
  return false
end

--- Create sound data compatible with AI_VoiceOver queue
local function CreateSoundData(audioFile, itemName)
  local fullPath = BOOK_CONFIG.SOUND_PATH .. BOOK_CONFIG.NARRATOR .. "\\" .. audioFile
  
  -- Get sound length if available (from SoundLengthHelper.lua)
  local duration = 0
  if GetBookSoundLength then
    duration = GetBookSoundLength(audioFile)
  end
  
  return {
    filePath = fullPath,
    fileName = audioFile,
    text = itemName or "Book",
    unitName = "Narrator",
    unitGUID = "book",
    questID = nil,
    event = "ITEM_TEXT",
    source = "BetterQuestText",
    delay = duration, -- Duration for AI_VoiceOver queue timing
  }
end

--- Add book audio to AI_VoiceOver queue
local function QueueBookAudio(audioFile, itemName)
  if not HAS_VOICEOVER or not VoiceOverQueue then
    return false
  end
  
  local soundData = CreateSoundData(audioFile, itemName)
  
  -- Add to queue
  VoiceOverQueue:AddSoundToQueue(soundData)
  DebugLog("Added to AI_VoiceOver queue: " .. audioFile)
  
  return true
end

--- Remove book audio from AI_VoiceOver queue
local function ClearBookQueue()
  if not HAS_VOICEOVER or not VoiceOverQueue then
    return false
  end
  
  -- Remove sounds from our source
  VoiceOverQueue:RemoveSoundFromQueue("BetterQuestText")
  DebugLog("Cleared book queue")
  
  return true
end

-------------------------
-- FALLBACK AUDIO PLAYBACK
-------------------------

local currentSound = nil
local currentSoundFile = nil

--- Stop currently playing book audio (fallback)
local function StopBookAudio()
  if currentSound then
    StopSound(currentSound)
    currentSound = nil
    currentSoundFile = nil
    DebugLog("Stopped audio (fallback)")
  end
end

--- Play book audio directly (fallback when AI_VoiceOver unavailable)
local function PlayBookAudioDirect(audioFile)
  StopBookAudio()
  
  local fullPath = BOOK_CONFIG.SOUND_PATH .. BOOK_CONFIG.NARRATOR .. "\\" .. audioFile
  
  DebugLog("Playing (fallback): " .. fullPath)
  
  local willPlay, soundHandle = PlaySoundFile(fullPath)
  
  if willPlay then
    currentSound = soundHandle
    currentSoundFile = audioFile
    DebugLog("Audio started successfully (fallback)")
    return true
  else
    DebugLog("Failed to play audio: " .. fullPath)
    return false
  end
end

-------------------------
-- PORTRAIT SYSTEM
-------------------------

--- Update portrait for book reading
local function UpdateBookPortrait()
  if not QuestFrame or not QuestFrame.widePortrait then
    return
  end
  
  local portrait = QuestFrame.widePortrait
  
  -- Set to book/narrator portrait
  local portraitTexture = "Interface\\AddOns\\BetterQuestText\\portraits\\books\\narrator.tga"
  
  -- Fallback to generic book icon if custom texture doesn't exist
  if not portrait.texture:SetTexture(portraitTexture) then
    -- Try default book texture
    portraitTexture = "Interface\\Icons\\INV_Misc_Book_09"
    portrait.texture:SetTexture(portraitTexture)
  end
  
  portrait:Show()
  DebugLog("Updated portrait to narrator/book")
end

--- Hide portrait when book closes
local function HideBookPortrait()
  if QuestFrame and QuestFrame.widePortrait then
    QuestFrame.widePortrait:Hide()
  end
end

-------------------------
-- EVENT HANDLERS
-------------------------

--- Handle book opening/page turning
local function OnBookEvent()
  local bookInfo = GetCurrentBookInfo()
  
  if not bookInfo then
    if HAS_VOICEOVER then
      ClearBookQueue()
    else
      StopBookAudio()
    end
    return
  end
  
  -- Update portrait
  UpdateBookPortrait()
  
  -- Find audio
  local audioFile = FindBookAudio(bookInfo)
  
  if audioFile and BOOK_CONFIG.ENABLED then
    -- Try AI_VoiceOver queue first
    if BOOK_CONFIG.USE_VOICEOVER_QUEUE and HAS_VOICEOVER then
      if not QueueBookAudio(audioFile, bookInfo.itemName) then
        -- Fallback to direct playback
        PlayBookAudioDirect(audioFile)
      end
    else
      -- Use direct playback
      PlayBookAudioDirect(audioFile)
    end
  else
    -- No audio, stop any playing
    if HAS_VOICEOVER then
      ClearBookQueue()
    else
      StopBookAudio()
    end
  end
end

--- Handle book closing
local function OnBookClosed()
  HideBookPortrait()
  
  if HAS_VOICEOVER then
    ClearBookQueue()
  else
    StopBookAudio()
  end
end

-------------------------
-- INITIALIZATION
-------------------------

local bookEventFrame = CreateFrame("Frame")

function InitBookVoiceover()
  -- Try to integrate with AI_VoiceOver
  InitVoiceOverIntegration()
  
  -- Register events
  bookEventFrame:RegisterEvent("ITEM_TEXT_BEGIN")
  bookEventFrame:RegisterEvent("ITEM_TEXT_READY")
  bookEventFrame:RegisterEvent("ITEM_TEXT_CLOSED")
  bookEventFrame:RegisterEvent("ITEM_TEXT_TRANSLATION")
  bookEventFrame:RegisterEvent("ADDON_LOADED")
  
  bookEventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "AI_VoiceOver" then
      -- Retry integration if AI_VoiceOver loaded after us
      InitVoiceOverIntegration()
    elseif event == "ITEM_TEXT_CLOSED" then
      OnBookClosed()
    else
      -- Delay slightly to ensure text is loaded
      this:SetScript("OnUpdate", function()
        OnBookEvent()
        this:SetScript("OnUpdate", nil)
      end)
    end
  end)
  
  -- Hook ItemTextFrame close
  if ItemTextFrame then
    local originalOnHide = ItemTextFrame:GetScript("OnHide")
    ItemTextFrame:SetScript("OnHide", function()
      if originalOnHide then originalOnHide() end
      OnBookClosed()
    end)
  end
  
  DebugLog("Book voiceover system initialized")
  if HAS_VOICEOVER then
    DebugLog("Using AI_VoiceOver queue integration")
  else
    DebugLog("Using fallback direct playback")
  end
end

-- Auto-initialize after slight delay to ensure other addons load
local initTimer = 0
local initFrame = CreateFrame("Frame")
initFrame:SetScript("OnUpdate", function()
  initTimer = initTimer + arg1
  if initTimer > 1.0 then
    InitBookVoiceover()
    this:SetScript("OnUpdate", nil)
  end
end)

-------------------------
-- SLASH COMMANDS
-------------------------

SLASH_BOOKVO1 = "/bookvo"
SlashCmdList["BOOKVO"] = function(msg)
  msg = string.lower(msg or "")
  
  if msg == "on" then
    BOOK_CONFIG.ENABLED = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r Enabled")
  elseif msg == "off" then
    BOOK_CONFIG.ENABLED = false
    if HAS_VOICEOVER then
      ClearBookQueue()
    else
      StopBookAudio()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r Disabled")
  elseif msg == "stop" then
    if HAS_VOICEOVER then
      ClearBookQueue()
    else
      StopBookAudio()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r Stopped")
  elseif msg == "debug" then
    BOOK_CONFIG.DEBUG = not BOOK_CONFIG.DEBUG
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r Debug " .. (BOOK_CONFIG.DEBUG and "enabled" or "disabled"))
  elseif msg == "queue" then
    BOOK_CONFIG.USE_VOICEOVER_QUEUE = not BOOK_CONFIG.USE_VOICEOVER_QUEUE
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r Queue integration " .. (BOOK_CONFIG.USE_VOICEOVER_QUEUE and "enabled" or "disabled"))
  elseif msg == "status" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover Status:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. (BOOK_CONFIG.ENABLED and "Yes" or "No"))
    DEFAULT_CHAT_FRAME:AddMessage("  AI_VoiceOver: " .. (HAS_VOICEOVER and "Available" or "Not found"))
    DEFAULT_CHAT_FRAME:AddMessage("  Queue integration: " .. (BOOK_CONFIG.USE_VOICEOVER_QUEUE and "Enabled" or "Disabled"))
    DEFAULT_CHAT_FRAME:AddMessage("  Debug: " .. (BOOK_CONFIG.DEBUG and "On" or "Off"))
  elseif msg == "test" then
    local bookInfo = GetCurrentBookInfo()
    if bookInfo then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r Testing...")
      DEFAULT_CHAT_FRAME:AddMessage("  Item: " .. (bookInfo.itemName or "Unknown"))
      DEFAULT_CHAT_FRAME:AddMessage("  Page: " .. bookInfo.page)
      local audioFile = FindBookAudio(bookInfo)
      if audioFile then
        DEFAULT_CHAT_FRAME:AddMessage("  Audio: " .. audioFile)
      else
        DEFAULT_CHAT_FRAME:AddMessage("  Audio: Not found")
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover:|r No book is currently open")
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBook Voiceover Commands:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo on - Enable voiceovers")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo off - Disable voiceovers")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo stop - Stop current audio")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo debug - Toggle debug messages")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo queue - Toggle AI_VoiceOver queue")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo status - Show current status")
    DEFAULT_CHAT_FRAME:AddMessage("  /bookvo test - Test current book")
  end
end