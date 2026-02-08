
-------------------------------------------------
-- MISSING NPC TRACKING (RUNTIME CACHE)
-------------------------------------------------

local MISSING_NPC_CACHE = {}

function Utils:IsNPCMissing(npcName)
    if not npcName then return false end
    local lookupName = Utils:NormalizeNPCName(npcName)
    return MISSING_NPC_CACHE[lookupName] == true
end

function Utils:MarkNPCMissing(npcName)
    if not npcName then return end
    local lookupName = Utils:NormalizeNPCName(npcName)
    MISSING_NPC_CACHE[lookupName] = true
    Debug("Marked NPC as missing: " .. tostring(npcName))
end

function Utils:UnmarkNPCMissing(npcName)
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

    local normalizedName = Utils:NormalizeNPCName(npcName)
    local normalizedText = Utils:NormalizeDialogText(dialogText)
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
        }
    end
end

function Utils:WasPreviouslyMissing(npcName)
    if not BetterQuestDB or not npcName then return false end
    local normalizedName = Utils:NormalizeNPCName(npcName)
    return BetterQuestDB.missingNPCs[normalizedName] ~= nil
end

function Utils:RemoveFromMissingDB(npcName)
    if not BetterQuestDB or not npcName then return end
    local normalizedName = Utils:NormalizeNPCName(npcName)
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
end
