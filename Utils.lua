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
--
-- External dependencies (provided by the data layer, NOT this addon):
--   NPC_DATABASE            — the full NPC/dialog lookup table
--   FuzzyFindDialogSound()  — Myers bit-parallel fuzzy matcher
--   GetNPCMetadata()        — metadata accessor for NPC_DATABASE


local playerName = UnitName("player")
local _, playerClass = UnitClass("player")

-------------------------------------------------
-- DEBUG
-------------------------------------------------

function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[BetterQuest]|r " .. tostring(msg))
end

-------------------------------------------------
-- NORMALIZERS
-------------------------------------------------

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
    name = string.gsub(name, "[\xe2\x80\x98\xe2\x80\x99]", "")  -- UTF-8 curly quotes
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
function PlaySound(soundData)
    if not soundData then return nil end
        soundData.filePath = NormalizePath(soundData.filePath)
    if not soundData.filePath then
        Debug("ERROR: No valid file path")
        return
    end

    Debug("Loading" .. tostring(soundData.filePath))
    if not filePath or filePath == "" then
        Debug("PlaySoundSafe called with empty path")
        return nil
    end
    if soundData.duration == 0.0 then 
        Debug("File is empty, if you play this file it will crash wow" .. filePath)
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
function StopSound(handle)
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

local FALLBACK_TIMEOUT = 0.1   -- seconds — abort the full-hash scan if exceeded

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

-- Fuzzy find (uses EditDistance consistently and enforces a 0.1s loop timeout)
function FuzzyFindDialogSound(npcName, dialogText)
    if not npcName or not dialogText then return nil end
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
    local MAX_DISTANCE = math.min(8, math.max(1, math.ceil(m * 0.10)))

    local bestMatch = nil
    local bestDistance = 999

    local startTime = GetTime()
    local TIMEOUT = 0.1

    -- Early check: same NPC first (fast path)
    if targetNpc and targetNpc.dialogs then
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
function FindDialogSound(npcName, dialogText)
  if not npcName or not dialogText then return nil end

  local lookupName = NormalizeNPCName(npcName)
  local key = NormalizeDialogText(dialogText)
  if key == "" then return nil end

  -- 1) Normal lookup
  local npc = NPC_DATABASE[lookupName]
  if npc and npc.dialogs and npc.dialogs[key] then
    local entry = npc.dialogs[key]
    return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
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