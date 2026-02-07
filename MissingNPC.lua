
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