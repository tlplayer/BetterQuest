
-------------------------------------------------
-- MISSING NPC TRACKING (PERSISTENT DB)
-------------------------------------------------

function Utils:InitializeBetterQuestDB()
    if not BetterQuestDB then
        BetterQuestDB = {}
        Debug("BetterQuestDB initialized")
    end

    local detectedClientVersion = CONFIG.GAME.CLIENT_VERSION
    if GetBuildInfo then
        detectedClientVersion = GetBuildInfo() or detectedClientVersion
    end

    BetterQuestDB.metadata = {
        schemaVersion = 2,
        clientVersion = detectedClientVersion,
        expansion = CONFIG.GAME.EXPANSION
    }
end

function Utils:LogMissingNPC(npcName, dialogText)
    if not BetterQuestDB or not npcName or not dialogText then return end

    local normalizedName = Utils:NormalizeName(npcName)
    local normalizedText = Utils:NormalizeDialogText(dialogText)
    if normalizedText == "" then 
        Debug("normalized text became empty:".. dialogText)
        return 
    end

    local zone = Utils:GetZone()

    if not BetterQuestDB[normalizedName] then
        BetterQuestDB[normalizedName] = {
            originalName = npcName,
            dialogs = {},
            zones = {}
        }
    end

    local npcEntry = BetterQuestDB[normalizedName]
    npcEntry.dialogs = npcEntry.dialogs or {}
    npcEntry.zones = npcEntry.zones or {}
    local existingDialog = npcEntry.dialogs[normalizedText]
    if not existingDialog or type(existingDialog) == "string" then
        npcEntry.dialogs[normalizedText] = {
            text = existingDialog or dialogText,
            zone = zone,
            expansion = CONFIG.GAME.EXPANSION,
            clientVersion = BetterQuestDB.metadata.clientVersion
        }
    end

    if zone and zone ~= "" then
        npcEntry.zones[zone] = zone
    end
end
