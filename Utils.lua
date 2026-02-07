-- utils.lua
-- Shared utility functions — no addon-specific state.
-- Load order: 1 of 4  (utils → soundqueue → ui → core)
--
-- Globals exported:
--   Debug(msg)
--   NormalizeNPCName(name)
--   NormalizeDialogText(text)
--   NormalizePath(path)
--   IsBookInteraction()
--   FindDialogSound(npcName, dialogText)
--   Utils:ClearMissingNPCCache()           -- Clear runtime cache (current session)
--   Utils:InitializeBetterQuestDB()        -- Initialize persistent missing NPC database
--   Utils:LogMissingNPC(npcName, dialogText, dialogType)  -- Log to persistent DB
--   Utils:ExportMissingNPCs()              -- Display all missing NPCs from persistent DB
--   Utils:ClearMissingNPCs()               -- Clear persistent missing NPC database
--   Utils:WasPreviouslyMissing(npcName)    -- Check if NPC is in persistent DB (informational)
--   Utils:RemoveFromMissingDB(npcName)     -- Remove NPC from persistent DB when found
--
-- External dependencies (provided by the data layer, NOT this addon):
--   NPC_DATABASE            — the full NPC/dialog lookup table
--   FuzzyFindDialogSound()  — Myers bit-parallel fuzzy matcher
--   GetNPCMetadata()        — metadata accessor for NPC_DATABASE
--   BetterQuestDB           — SavedVariables for persistent missing NPC tracking

Utils = {}
local playerName = UnitName("player")
local _, playerClass = UnitClass("player")

-------------------------------------------------
-- MISSING NPC TRACKING
-------------------------------------------------
-- Track NPCs that aren't in the database to avoid repeated lookups
--
-- TWO-TIER SYSTEM:
--
-- 1. RUNTIME CACHE (MISSING_NPC_CACHE):
--    - Temporary, cleared on /reload
--    - Purpose: Performance optimization for current session
--    - When an NPC lookup fails, we mark it here
--    - Subsequent lookups in same session immediately return nil (no search)
--    - Cleared when: UI reload, or Utils:ClearMissingNPCCache()
--
-- 2. PERSISTENT DATABASE (BetterQuestDB.missingNPCs):
--    - Saved between sessions via SavedVariables
--    - Purpose: Data collection for development/debugging
--    - Tracks which NPCs/dialogs are missing from NPC_DATABASE
--    - Does NOT prevent searches (NPCs might have been added since last reload)
--    - Only cleared manually via Utils:ClearMissingNPCs()
--
-- WORKFLOW:
--   - Search fails → Mark in runtime cache (skip for rest of session)
--   - Search fails → Log to persistent DB (survives reloads for analysis)
--   - Search succeeds → Remove from runtime cache
--   - Search succeeds → Remove from persistent DB (was added to database)
--   - Reload → Runtime cache cleared, persistent DB kept for analysis

local MISSING_NPC_CACHE = {}

-- Check if an NPC is marked as missing
local function IsNPCMissing(npcName)
    if not npcName then return false end
    local lookupName = NormalizeNPCName(npcName)
    return MISSING_NPC_CACHE[lookupName] == true
end

-- Mark an NPC as missing
local function MarkNPCMissing(npcName)
    if not npcName then return end
    local lookupName = NormalizeNPCName(npcName)
    MISSING_NPC_CACHE[lookupName] = true
    Debug("Marked NPC as missing: " .. tostring(npcName))
end

-- Remove an NPC from the missing list (found in database)
local function UnmarkNPCMissing(npcName)
    if not npcName then return end
    local lookupName = NormalizeNPCName(npcName)
    if MISSING_NPC_CACHE[lookupName] then
        MISSING_NPC_CACHE[lookupName] = nil
        Debug("Removed NPC from missing cache: " .. tostring(npcName))
    end
end

-- Clear the missing NPC cache (call on reload/database update)
function Utils:ClearMissingNPCCache()
    MISSING_NPC_CACHE = {}
    Debug("Cleared missing NPC cache")
end

-------------------------------------------------
-- PERSISTENT MISSING-NPC TRACKING (SavedVariables)
-------------------------------------------------
-- These functions work with BetterQuestDB (saved variables) to track
-- missing NPCs across sessions for debugging/data collection purposes.
-- IMPORTANT: This is ONLY for logging/reporting, NOT for skipping searches.
-- Use the runtime MISSING_NPC_CACHE for that.

function Utils:InitializeBetterQuestDB()
    if not BetterQuestDB then
        BetterQuestDB = { missingNPCs = {} }
        Debug("BetterQuestDB initialized")
    end
end

function Utils:LogMissingNPC(npcName, dialogText, dialogType)
    if not BetterQuestDB or not npcName or not dialogText then return end

    local normalizedName = NormalizeNPCName(npcName)
    local normalizedText = NormalizeDialogText(dialogText)
    if normalizedText == "" then return end

    -- Mark in runtime cache to prevent repeated searches THIS SESSION
    MarkNPCMissing(npcName)

    -- Log to persistent database for data collection across sessions
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

function Utils:ExportMissingNPCs()
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

function Utils:ClearMissingNPCs()
    if BetterQuestDB then
        BetterQuestDB.missingNPCs = {}
        Debug("Missing NPC database cleared")
    end
end

-- Check if an NPC was previously missing (from persistent DB)
-- This is informational only - we still search in case they've been added
function Utils:WasPreviouslyMissing(npcName)
    if not BetterQuestDB or not npcName then return false end
    local normalizedName = NormalizeNPCName(npcName)
    return BetterQuestDB.missingNPCs[normalizedName] ~= nil
end

-- Remove an NPC from the persistent missing database (found in current database)
function Utils:RemoveFromMissingDB(npcName)
    if not BetterQuestDB or not npcName then return end
    local normalizedName = NormalizeNPCName(npcName)
    if BetterQuestDB.missingNPCs[normalizedName] then
        BetterQuestDB.missingNPCs[normalizedName] = nil
        Debug("Removed from persistent missing DB: " .. tostring(npcName))
    end
end

-------------------------------------------------
-- DEBUG
-------------------------------------------------

function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[BetterQuest]|r " .. tostring(msg))
end
-- ===== Slash command to reload UI =====
SLASH_BETTERQUEST_RELOAD1 = "/reload"
SLASH_BETTERQUEST_RELOAD2 = "/rl"  -- optional shorthand

SlashCmdList["BETTERQUEST_RELOAD"] = function()
    ReloadUI()  -- built-in WoW function
end
-------------------------------------------------
-- NORMALIZERS
-------------------------------------------------
if not hooksecurefunc then
    ---@overload fun(name, hook)
    function hooksecurefunc(table, name, hook)
        if not hook then
            name, hook = table, name
            table = _G
        end

        if not table or not name or not hook then return end

        local old = table[name]
        assert(type(old) == "function")
        table[name] = function(...)
            local result = { old(unpack(arg)) }
            hook(unpack(arg))
            return unpack(result)
        end
    end
end

-- Strip punctuation, collapse whitespace, lowercase.
-- Used as the canonical key for every dialog lookup.

-- Database hookup code
function NormalizeDialogText(text)
    if not text then return "" end

    -- Replace Blizzard placeholders
    text = string.gsub(text, "%$[nNcCrR]", "adventurer")
    text = string.gsub(text, "%$g[^;]*;", "adventurer")

    -- Replace actual player name and class
    if playerName ~= "" then
        text = string.gsub(text, playerName, "adventurer")
    end
    if playerClass ~= "" then
        text = string.gsub(text, playerClass, "adventurer")
    end

    -- Remove other $ tokens
    text = string.gsub(text, "%$%w+", "")

    -- Remove text in brackets/parentheses/<> (emotes, tags)
    text = string.gsub(text, "%b[]", "")
    text = string.gsub(text, "%b()", "")
    text = string.gsub(text, "%b<>", "")

    -- Remove punctuation
    text = string.gsub(text, "[^%w%s]", "")

    -- Trim and collapse spaces
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    -- Lowercase
    text = string.lower(text)

    return string.sub(text, 1, 50)
end

-- Strip curly/straight apostrophes so "Sylvanas's" == "Sylvanass" style keys match.
function NormalizeNPCName(name)
    if not name then return nil end
    name = string.gsub(name, "['']", "")                          -- ASCII apostrophe
    return name
end

-- Guarantee forward-slashes, strip leading/trailing whitespace.
function NormalizePath(path)
    if not path then return nil end
    path = string.gsub(path, "^%s+", "")
    path = string.gsub(path, "%s+$", "")
    if path == "" then return nil end
    path = string.gsub(path, "/", "\\")
    return path
end
-------------------------------------------------
-- DEBUG & UTILS
-------------------------------------------------

local function Utils:Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[SoundQueue]|r " .. tostring(msg))
end

local function Utils:NormalizePath(path)
    if not path then return nil end
    return string.gsub(path, "/+", "\\")
end

-- Database hookup code
function Utils:NormalizeDialogText(text)
    if not text then return "" end

    -- Replace Blizzard placeholders
    text = string.gsub(text, "%$[nNcCrR]", "adventurer")
    text = string.gsub(text, "%$g[^;]*;", "adventurer")

    -- Replace actual player name and class
    if playerName ~= "" then
        text = string.gsub(text, playerName, "adventurer")
    end
    if playerClass ~= "" then
        text = string.gsub(text, playerClass, "adventurer")
    end

    -- Remove other $ tokens
    text = string.gsub(text, "%$%w+", "")

    -- Remove text in brackets/parentheses/<> (emotes, tags)
    text = string.gsub(text, "%b[]", "")
    text = string.gsub(text, "%b()", "")
    text = string.gsub(text, "%b<>", "")

    -- Remove punctuation
    text = string.gsub(text, "[^%w%s]", "")

    -- Trim and collapse spaces
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    -- Lowercase
    text = string.lower(text)

    return string.sub(text, 1, 50)
end


local function Utils:NormalizeNPCName(name)
  if not name then return nil end
  name = string.gsub(name, "['']", "")
  return name
end

function Utils:GetNPCMetadata(npcName)
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
-- CONTEXT HELPERS
-------------------------------------------------

-- True when the player is reading a book/note/letter.
function IsBookInteraction()
    return ItemTextFrame and ItemTextFrame:IsShown()
end

-------------------------------------------------
-- SAFE SOUND HELPERS
-------------------------------------------------

-- Safely play a sound file; returns the handle or nil if failed.
function Utils:PlaySound(soundData)
    if not soundData then return nil end

    filePath = NormalizePath(soundData.filePath)

    Debug("Loading" .. tostring(filePath))
    if not filePath or filePath == "" then
        Debug("PlaySoundSafe called with empty path")
        return nil
    end
    if soundData.duration == 0.0 then 
        Debug("File is empty, if you play this file it will crash wow" .. filePath)
        return nil
    end

    local handle
    local ok, err = pcall(function()
        handle = PlaySoundFile(filePath)
    end)

    if not ok then
        Debug("PlaySoundSafe ERROR playing sound: " .. tostring(err) .. " | Path: " .. tostring(filePath))
        return nil
    end

    Debug("PlaySoundSafe succeeded: " .. tostring(filePath))
    return handle
end

-- Safely stop a sound by handle
function Utils:StopSound(handle)
    if not handle then
        Debug("StopSoundSafe called with nil handle")
        return
    end

    local ok, err = pcall(function()
        StopSoundFile(handle)
    end)

    if not ok then
        Debug("StopSoundSafe ERROR stopping sound: " .. tostring(err) .. " | Handle: " .. tostring(handle))
    end
end

-------------------------------------------------
-- DIALOG SOUND LOOKUP
-------------------------------------------------
-- Three-stage resolution:
--   1. Exact match on the current NPC.
--   2. Full-hash scan across all NPCs (time-boxed to TIMEOUT seconds).
--   3. Fuzzy text search via Myers' bit-parallel algorithm.
-- Returns: path, dialog_type, quest_id, seconds   (or nil)
-- Computes the Levenshtein (edit) distance between two strings
-- Edit distance (Levenshtein) for Lua 5.0
function Utils:EditDistance(s1, s2)
    if not s1 or not s2 then return 9999 end

    -- lengths using string.len (Lua 5.0 safe)
    local len1 = string.len(s1)
    local len2 = string.len(s2)

    -- early exit for empty strings
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    -- create 2D matrix
    local matrix = {}
    local i, j
    for i = 0, len1 do
        matrix[i] = {}
        matrix[i][0] = i
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    -- fill matrix
    for i = 1, len1 do
        local c1 = string.sub(s1, i, i)
        for j = 1, len2 do
            local c2 = string.sub(s2, j, j)
            local cost = 0
            if c1 ~= c2 then cost = 1 end

            local deletion     = matrix[i-1][j] + 1
            local insertion    = matrix[i][j-1] + 1
            local substitution = matrix[i-1][j-1] + cost

            local min = deletion
            if insertion < min then min = insertion end
            if substitution < min then min = substitution end

            matrix[i][j] = min
        end
    end

    return matrix[len1][len2]
end


local FALLBACK_TIMEOUT = 0.1   -- seconds — abort the full-hash scan if exceeded

function Utils:GetNPCMetadata(npcName)
  if not npcName then return nil end
  
  -- Early exit if NPC is marked as missing in runtime cache
  if IsNPCMissing(npcName) then
    return nil
  end
  
  local lookupName = NormalizeNPCName(npcName)
  local npc = NPC_DATABASE[lookupName]

  -- If NPC exists, remove from both caches
  if npc then
    UnmarkNPCMissing(npcName)
    Utils:RemoveFromMissingDB(npcName)  -- Also remove from persistent DB
    return {
      race = npc.race,
      sex = npc.sex,
      portrait = npc.portrait,
      zone = npc.zone,
      model_id = npc.model_id,
      narrator = npc.narrator
    }
  end
  
  -- NPC not found, mark as missing in runtime cache only
  Utils:MarkNPCMissing(npcName)
  return nil
end

-- Fuzzy find (uses EditDistance consistently and enforces a 0.1s loop timeout)
function Utils:FuzzyFindDialogSound(npcName, dialogText)
    if not npcName or not dialogText then return nil end
    
    -- Early exit if NPC is marked as missing in runtime cache
    if IsNPCMissing(npcName) then
        return nil
    end
    
    print(dialogText)

    local lookupName = NormalizeNPCName(npcName)
    local targetNpc  = NPC_DATABASE[lookupName]
    local targetSex  = targetNpc and targetNpc.sex
    local targetRace = targetNpc and targetNpc.race

    local normalizedInput = NormalizeDialogText(dialogText)
    print(normalizedInput)
    if normalizedInput == "" then return nil end

    -- dynamic distance threshold: allow ~20% of pattern length, capped at 10
    local strlen = strlen or string.len
    local m = strlen(normalizedInput)
    local MAX_DISTANCE = math.min(8, math.max(2, math.ceil(m * 0.10)))

    local bestMatch = nil
    local bestDistance = 999

    local startTime = GetTime()
    local TIMEOUT = 0.1

    -- Early check: same NPC first (fast path)
    if targetNpc and targetNpc.dialogs then
        UnmarkNPCMissing(npcName)  -- Found in database (runtime cache)
        Utils:RemoveFromMissingDB(npcName)  -- Also remove from persistent DB
        
        for dialogKey, entry in pairs(targetNpc.dialogs) do
            if GetTime() - startTime > TIMEOUT then
                Debug("Fuzzy search timeout (same NPC) - aborting fuzzy lookup")
                return nil
            end

            local distance =  EditDistance(normalizedInput, dialogKey)
            if distance <= MAX_DISTANCE and distance < bestDistance then
                bestDistance = distance
                bestMatch = entry
            end
        end

        if bestMatch then
            return bestMatch.path, bestMatch.dialog_type, bestMatch.quest_id, bestMatch.seconds
        end
    elseif not targetNpc then
        -- NPC not in database, mark as missing in runtime cache only
        MarkNPCMissing(npcName)
    end
    
    -- Fallback: search other NPCs filtered by race + sex (to avoid unrelated matches)
    for otherName, data in pairs(NPC_DATABASE) do
        if GetTime() - startTime > TIMEOUT  then
            Debug("Fuzzy search timeout (other NPCs) - aborting fuzzy lookup")
            return nil
        end

        if data ~= targetNpc
           and targetRace and data.race == targetRace
           and targetSex  and data.sex  == targetSex
           and data.dialogs then

            for dialogKey, entry in pairs(data.dialogs) do
                if GetTime() - startTime > TIMEOUT then
                    Debug("Fuzzy search timeout (inside NPC dialogs) - aborting fuzzy lookup")
                    return nil
                end

                local distance =  EditDistance(normalizedInput, dialogKey)
                if distance <= MAX_DISTANCE then
                    -- prefer the smallest distance (best fuzzy match)
                    if distance < bestDistance then
                        bestDistance = distance
                        bestMatch = entry
                    end

                    -- If we get a perfect or very close match, return immediately
                    if distance == 0 or distance <= math.max(3, math.floor(m * 0.05)) then
                        return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
                    end
                end
            end
        end
    end

    if bestMatch then
        return bestMatch.path, bestMatch.dialog_type, bestMatch.quest_id, bestMatch.seconds
    end

    return nil
end

-- FindDialogSound with timeout on the full hash fallback loop
function Utils:FindDialogSound(npcName, dialogText)
  if not npcName or not dialogText then return nil end

  -- Early exit if NPC is marked as missing in runtime cache (THIS SESSION)
  if IsNPCMissing(npcName) then
    return nil
  end

  local lookupName = NormalizeNPCName(npcName)
  local key = NormalizeDialogText(dialogText)
  if key == "" then return nil end

  -- 1) Normal lookup
  local npc = NPC_DATABASE[lookupName]
  if npc and npc.dialogs and npc.dialogs[key] then
    UnmarkNPCMissing(npcName)  -- Found in database (runtime cache)
    Utils:RemoveFromMissingDB(npcName)  -- Also remove from persistent DB
    local entry = npc.dialogs[key]
    return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
  end

  -- If NPC doesn't exist at all, mark as missing in runtime cache only
  if not npc then
    MarkNPCMissing(npcName)
    return nil
  end

  -- 2) Fallback: search all NPCs by text hash (with timeout guard)
  local startTime = GetTime()
  local TIMEOUT = 0.1
  for otherNpcName, data in pairs(NPC_DATABASE) do
    if GetTime() - startTime > TIMEOUT then
        Debug("FindDialogSound fallback timeout - aborting full-hash scan")
        break
    end

    if data.dialogs then
      local entry = data.dialogs[key]
      if entry then
        return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
      end
    end
  end

  -- 3) Fuzzy text search (Myers' algorithm + timeout)
  local fuzzyPath, fuzzyDialogType, fuzzyQuestID, fuzzySeconds = FuzzyFindDialogSound(npcName, dialogText)
  if fuzzyPath then
    return fuzzyPath, fuzzyDialogType, fuzzyQuestID, fuzzySeconds
  end

  return nil
end


-------------------------------------------------
-- MISSING NPC TRACKING
-------------------------------------------------

function  Utils:InitializeBetterQuestDB()
    if not BetterQuestDB then
        BetterQuestDB = {
            missingNPCs = {}
        }
        Debug("BetterQuestDB initialized")
    end
end

function  Utils:LogMissingNPC(npcName, dialogText, dialogType)
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

function Utils:ExportMissingNPCs()
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