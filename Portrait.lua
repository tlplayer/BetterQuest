-------------------------------------------------
-- PORTRAIT HELPERS
-------------------------------------------------

local function IsBookInteraction()
    return ItemTextFrame and ItemTextFrame:IsShown()
end

local function GetPortraitTexture(soundData)
    if not soundData then
        return SoundQueue.portraitConfig.DEFAULT_NPC
    end
    
    if IsBookInteraction() then
        return SoundQueue.portraitConfig.DEFAULT_BOOK
    end
    
    local npcName = soundData.npcName
    if npcName then
        local metadata = GetNPCMetadata(npcName)
        if metadata and metadata.race then
            local filename = metadata.race
            if metadata.sex == "female" then
                filename = filename .. "_female"
            end
            
            local path = SoundQueue.portraitConfig.PORTRAIT_PATH .. filename
            return path
        end
    end
    
    return SoundQueue.portraitConfig.DEFAULT_NPC
end
