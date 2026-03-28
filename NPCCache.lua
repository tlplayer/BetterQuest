
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

    local normalizedName = npcName
    local normalizedText = Utils:NormalizeDialogText(dialogText)
    if normalizedText == "" then return end


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
            dialogType =  "gossip",
        }
    end
end

