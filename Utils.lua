-- utils.lua
-- Shared utility functions — no addon-specific state.
-- Load order: 1 of 4  (utils → soundqueue → ui → core)

Utils = {}
local playerName = UnitName("player")
local _, playerClass = UnitClass("player")


-------------------------------------------------
-- DEBUG / LOGGING
-------------------------------------------------

function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[BetterQuest]|r " .. tostring(msg))
end

-- ===== Slash command to reload UI =====
SLASH_BETTERQUEST_RELOAD1 = "/reload"
SLASH_BETTERQUEST_RELOAD2 = "/rl"

SlashCmdList["BETTERQUEST_RELOAD"] = function()
    ReloadUI()
end

-------------------------------------------------
-- HOOK / COMPATIBILITY HELPERS
-------------------------------------------------

if not hooksecurefunc then
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

-------------------------------------------------
-- STRING / PATH NORMALIZERS
-------------------------------------------------

-- Guarantee backslashes, strip whitespace
function Utils:NormalizePath(path)
    if not path then return nil end
    path = string.gsub(path, "^%s+", "")
    path = string.gsub(path, "%s+$", "")
    if path == "" then return nil end
    path = string.gsub(path, "/", "\\")
    return path
end

-- Secondary / duplicate normalizers (kept as-is)
local function Utils:NormalizeNPCName(name)
    if not name then return nil end
    name = string.gsub(name, "['']", "")
    return name
end

local function Utils:NormalizePath(path)
    if not path then return nil end
    return string.gsub(path, "/+", "\\")
end

-------------------------------------------------
-- DIALOG TEXT NORMALIZATION
-------------------------------------------------

function Utils:NormalizeDialogText(text)
    if not text then return "" end

    text = string.gsub(text, "%$[nNcCrR]", "adventurer")
    text = string.gsub(text, "%$g[^;]*;", "adventurer")

    if playerName ~= "" then
        text = string.gsub(text, playerName, "adventurer")
    end
    if playerClass ~= "" then
        text = string.gsub(text, playerClass, "adventurer")
    end

    text = string.gsub(text, "%$%w+", "")
    text = string.gsub(text, "%b[]", "")
    text = string.gsub(text, "%b()", "")
    text = string.gsub(text, "%b<>", "")
    text = string.gsub(text, "[^%w%s]", "")

    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.lower(text)

    return string.sub(text, 1, 50)
end

-------------------------------------------------
-- CONTEXT HELPERS
-------------------------------------------------

function Utils:IsBookInteraction()
    return ItemTextFrame and ItemTextFrame:IsShown()
end

-------------------------------------------------
-- MISSING NPC TRACKING (RUNTIME CACHE)
-------------------------------------------------

local MISSING_NPC_CACHE = {}

local function Utils:IsNPCMissing(npcName)
    if not npcName then return false end
    local lookupName = Utils:NormalizeNPCName(npcName)
    return MISSING_NPC_CACHE[lookupName] == true
end

local function Utils:MarkNPCMissing(npcName)
    if not npcName then return end
    local lookupName = Utils:NormalizeNPCName(npcName)
    MISSING_NPC_CACHE[lookupName] = true
    Debug("Marked NPC as missing: " .. tostring(npcName))
end

local function Utils:UnmarkNPCMissing(npcName)
    if not npcName then return end
    local lookupName = Utils:NormalizeNPCName(npcName)
    if MISSING_NPC_CACHE[lookupName] then
        MISSING_NPC_CACHE[lookupName] = nil
        Debug("Removed NPC from missing cache: " .. tostring(npcName))
    end
end

function Utils:ClearMissingNPCCache()
    MISSING_NPC_CACHE = {}
    Debug("Cleared missing NPC cache")
end

-------------------------------------------------
-- MISSING NPC TRACKING (PERSISTENT DB)
-------------------------------------------------

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

    Utils:MarkNPCMissing(npcName)

    if not BetterQuestDB.missingNPCs[normalizedName] then
        BetterQuestDB.missingNPCs[normalizedName] = {
            originalName = npcName,
            dialogs = {},
        }
    end

    local npcEntry = BetterQuestDB.missingNPCs[normalizedName]
    if not npcEntry.dialogs[normalizedText] then
        npcEntry.dialogs[normalizedText] = {
            dialog_text = dialogText,
            dialogType = dialogType or "gossip",
            count = 0,
        }
    end

    npcEntry.dialogs[normalizedText].count =
        npcEntry.dialogs[normalizedText].count + 1
end

function Utils:WasPreviouslyMissing(npcName)
    if not BetterQuestDB or not npcName then return false end
    local normalizedName = NormalizeNPCName(npcName)
    return BetterQuestDB.missingNPCs[normalizedName] ~= nil
end

function Utils:RemoveFromMissingDB(npcName)
    if not BetterQuestDB or not npcName then return end
    local normalizedName = NormalizeNPCName(npcName)
    if BetterQuestDB.missingNPCs[normalizedName] then
        BetterQuestDB.missingNPCs[normalizedName] = nil
        Debug("Removed from persistent missing DB: " .. tostring(npcName))
    end
end

function Utils:ClearMissingNPCs()
    if BetterQuestDB then
        BetterQuestDB.missingNPCs = {}
        Debug("Missing NPC database cleared")
    end
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
            dialogCount = dialogCount + 1
            totalDialogs = totalDialogs + 1
        end
        Debug(string.format(
            "%d. %s (%d dialog(s))",
            npcCount, data.originalName, dialogCount
        ))
    end

    Debug(string.format(
        "Total: %d missing NPCs, %d missing dialogs",
        npcCount, totalDialogs
    ))
end

-------------------------------------------------
-- SAFE SOUND HELPERS
-------------------------------------------------

function Utils:PlaySound(soundData)
    if not soundData then return nil end

    filePath = Utils:NormalizePath(soundData.filePath)
    Debug("Loading" .. tostring(filePath))

    if not filePath or filePath == "" then return nil end
    if soundData.duration == 0.0 then return nil end

    local handle
    local ok = pcall(function()
        handle = PlaySoundFile(filePath)
    end)

    return ok and handle or nil
end

function Utils:StopSound(handle)
    if not handle then return end
       if self.isPlaying and soundData.handle then
        SetCVar("MasterSoundEffects", 0)
        SetCVar("MasterSoundEffects", 1)
    end
    soundData.handle = nil 
end

-------------------------------------------------
-- EDIT DISTANCE
-------------------------------------------------

function Utils:EditDistance(s1, s2)
    if not s1 or not s2 then return 9999 end
    local len1, len2 = string.len(s1), string.len(s2)
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    local matrix = {}
    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        local c1 = string.sub(s1, i, i)
        for j = 1, len2 do
            local cost = (c1 ~= string.sub(s2, j, j)) and 1 or 0
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
        end
    end

    return matrix[len1][len2]
end

-------------------------------------------------
-- NPC METADATA + DIALOG SOUND LOOKUP
-------------------------------------------------

local FALLBACK_TIMEOUT = 0.1

function Utils:GetNPCMetadata(npcName)
    if not npcName then return nil end
    if Utils:IsNPCMissing(npcName) then return nil end

    local lookupName = Utils:NormalizeNPCName(npcName)
    local npc = NPC_DATABASE[lookupName]

    if npc then
        Utils:UnmarkNPCMissing(npcName)
        Utils:RemoveFromMissingDB(npcName)
        return {
            race = npc.race,
            sex = npc.sex,
            portrait = npc.portrait,
            zone = npc.zone,
            model_id = npc.model_id,
            narrator = npc.narrator
        }
    end

    Utils:MarkNPCMissing(npcName)
    return nil
end

function Utils:FuzzyFindDialogSound(npcName, dialogText)
    if not npcName or not dialogText then return nil end
    
    -- Early exit if NPC is marked as missing in runtime cache
    if Utils:IsNPCMissing(npcName) then
        return nil
    end
    
    print(dialogText)

    local lookupName = Utils:NormalizeNPCName(npcName)
    local targetNpc  = NPC_DATABASE[lookupName]
    local targetSex  = targetNpc and targetNpc.sex
    local targetRace = targetNpc and targetNpc.race

    local normalizedInput = Utils:NormalizeDialogText(dialogText)
    print(normalizedInput)
    if normalizedInput == "" then return nil end

    -- dynamic distance threshold: allow ~10% of pattern length, capped
    local strlen = strlen or string.len
    local m = strlen(normalizedInput)
    local MAX_DISTANCE = math.min(8, math.max(2, math.ceil(m * 0.10)))

    local bestMatch = nil
    local bestDistance = 999

    local startTime = GetTime()
    local TIMEOUT = 0.1

    -------------------------------------------------
    -- FAST PATH: SAME NPC
    -------------------------------------------------
    if targetNpc and targetNpc.dialogs then
        Utils:UnmarkNPCMissing(npcName)
        Utils:RemoveFromMissingDB(npcName)
        
        for dialogKey, entry in pairs(targetNpc.dialogs) do
            if GetTime() - startTime > TIMEOUT then
                Debug("Fuzzy search timeout (same NPC) - aborting fuzzy lookup")
                return nil
            end

            local distance = Utils:EditDistance(normalizedInput, dialogKey)
            if distance <= MAX_DISTANCE and distance < bestDistance then
                bestDistance = distance
                bestMatch = entry
            end
        end

        if bestMatch then
            return bestMatch.path,
                   bestMatch.dialog_type,
                   bestMatch.quest_id,
                   bestMatch.seconds
        end

    elseif not targetNpc then
        -- NPC not in database, mark as missing in runtime cache only
        Utils:MarkNPCMissing(npcName)
    end
    
    -------------------------------------------------
    -- FALLBACK: OTHER NPCs (race + sex filtered)
    -------------------------------------------------
    for otherName, data in pairs(NPC_DATABASE) do
        if GetTime() - startTime > TIMEOUT then
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

                local distance = EditDistance(normalizedInput, dialogKey)
                if distance <= MAX_DISTANCE then
                    if distance < bestDistance then
                        bestDistance = distance
                        bestMatch = entry
                    end

                    -- Near-perfect match → early return
                    if distance == 0
                       or distance <= math.max(3, math.floor(m * 0.05)) then
                        return entry.path,
                               entry.dialog_type,
                               entry.quest_id,
                               entry.seconds
                    end
                end
            end
        end
    end

    -------------------------------------------------
    -- BEST MATCH (IF ANY)
    -------------------------------------------------
    if bestMatch then
        return bestMatch.path,
               bestMatch.dialog_type,
               bestMatch.quest_id,
               bestMatch.seconds
    end

    return nil
end
