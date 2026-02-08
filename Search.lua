
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

                local distance = Utils:EditDistance(normalizedInput, dialogKey)
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
