
-------------------------------------------------
-- MISSING NPC TRACKING (PERSISTENT DB)
-------------------------------------------------

function Utils:InitializeBetterQuestDB()
    if not BetterQuestDB then
        BetterQuestDB = {}
        Debug("BetterQuestDB initialized")
    end
end

function Utils:LogMissingNPC(npcName, dialogText)
    if not BetterQuestDB or not npcName or not dialogText then return end

    local normalizedName = Utils:NormalizeName(npcName)
    local normalizedText = Utils:NormalizeDialogText(dialogText)
    if normalizedText == "" then 
        Debug("normalized text became empty:".. dialogText)
        return 
    end

    if not BetterQuestDB[normalizedName] then
        BetterQuestDB[normalizedName] = {
            originalName = npcName,
            dialogs = {}
        }
    end

    local npcEntry = BetterQuestDB[normalizedName]
    if not npcEntry.dialogs[normalizedText] then
        npcEntry.dialogs[normalizedText] = dialogText
    end
end

