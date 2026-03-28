
-------------------------------------------------
-- EDIT DISTANCE
-------------------------------------------------

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

-------------------------------------------------
-- NPC METADATA + DIALOG SOUND LOOKUP
-------------------------------------------------

local FALLBACK_TIMEOUT = 0.4

function Utils:GetNPCMetadata(npcName)
    if not npcName then return nil end

    local lookupName = Utils:NormalizeNPCName(npcName)
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
local function GetThreshold(m)
    if m <= 10  then return 3 end
    if m <= 25  then return 4 end
    if m <= 50  then return 6 end
    return math.min(5, math.floor(m * 0.05))
end

function Utils:FuzzyFindDialogSound(npcName, dialogText)
    if not npcName or not dialogText then return nil end

    local lookupName = Utils:NormalizeNPCName(npcName)
    local targetNpc  = NPC_DATABASE[lookupName]
    local targetSex  = targetNpc and targetNpc.sex
    local targetRace = targetNpc and targetNpc.race

    local normalizedInput = Utils:NormalizeDialogText(dialogText)
    if normalizedInput == "" then return nil end

    local strlen = strlen or string.len
    local m = strlen(normalizedInput)
    local MAX_DISTANCE = GetThreshold(m)

    local bestMatch    = nil
    local bestDistance = 999

    local startTime = GetTime()
    local TIMEOUT   = 0.01

    -------------------------------------------------
    -- FAST PATH: SAME NPC
    -------------------------------------------------
    if targetNpc and targetNpc.dialogs then
        for dialogKey, entry in pairs(targetNpc.dialogs) do
            if GetTime() - startTime > TIMEOUT then
                Debug("Fuzzy search timeout (same NPC) - aborting fuzzy lookup")
                return nil
            end

            -- O(1) length pre-reject before expensive Levenshtein
            if math.abs(strlen(dialogKey) - m) <= MAX_DISTANCE then
                local distance = Utils:EditDistance(normalizedInput, dialogKey)
                if distance <= MAX_DISTANCE and distance < bestDistance then
                    bestDistance = distance
                    bestMatch    = entry
                end
            end
        end

        if bestMatch then
            return bestMatch.path,
                   bestMatch.dialog_type,
                   bestMatch.quest_id,
                   bestMatch.seconds
        end
    end

    -------------------------------------------------
    -- FALLBACK: OTHER NPCs (race + sex filtered)
    -------------------------------------------------
    -- Tighter threshold for cross-NPC matches to reduce false positives
    local FALLBACK_MAX_DISTANCE = math.max(0, MAX_DISTANCE - 1)
    local earlyReturnThreshold  = math.max(1, math.floor(m * 0.05))

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

                -- O(1) length pre-reject
                if math.abs(strlen(dialogKey) - m) <= FALLBACK_MAX_DISTANCE then
                    local distance = Utils:EditDistance(normalizedInput, dialogKey)

                    if distance <= FALLBACK_MAX_DISTANCE then
                        if distance < bestDistance then
                            bestDistance = distance
                            bestMatch    = entry
                        end

                        -- Near-perfect match → early return
                        if distance == 0 or distance <= earlyReturnThreshold then
                            return entry.path,
                                   entry.dialog_type,
                                   entry.quest_id,
                                   entry.seconds
                        end
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


-- FindDialogSound with timeout on the full hash fallback loop
function Utils:FindDialogSound(npcName, dialogText)
    Debug("Finding dialog for:".. npcName)
  if not npcName or not dialogText then
    Debug("NPCName or dialogText is nil".. npcName,dialogText) 
    return nil 
  end

  local lookupName = Utils:NormalizeNPCName(npcName)
  local key = Utils:NormalizeDialogText(dialogText)
  if key == "" then return nil end

  -- 1) Normal lookup
  local npc = NPC_DATABASE[lookupName]
  Debug("Found npc with metadata from the database:" .. npcName)
  if npc and npc.dialogs and npc.dialogs[key] then
    local entry = npc.dialogs[key]
    if entry then 
        Debug("Found entry with this key from the database:" ..  key)
        return entry.path, entry.dialog_type, entry.quest_id, entry.seconds
    end
  end

  -- If npc + dialog missing, we log to a config file and read that from the python
  Debug("Did not find key in the database adding to missing db:" .. key)
  Utils:LogMissingNPC(npc,dialogText,"gossip")


  -- 3) Fuzzy text search (Myers' algorithm + timeout)
  local fuzzyPath, fuzzyDialogType, fuzzyQuestID, fuzzySeconds =Utils:FuzzyFindDialogSound(npcName, dialogText)
  if fuzzyPath then
    return fuzzyPath, fuzzyDialogType, fuzzyQuestID, fuzzySeconds
  end

  return nil
end