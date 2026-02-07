-------------------------------------------------
-- PORTRAIT HELPERS
-------------------------------------------------


local function PortraitManager:PortraitManagerGetPortraitTexture(soundData)
    if not soundData then
        return SoundQueue.portraitConfig.DEFAULT_NPC
    end
    
    if Utils:IsBookInteraction() then
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

-------------------------------------------------------------------------
-- BOOK PORTRAITS
-------------------------------------------------------------------------
function PortraitManager:FindBookPortrait(itemName)
    if BookDB and BookDB.portraits and itemName then
        if BookDB.portraits[itemName] then
            return BookDB.portraits[itemName]
        end
    end
    return CONFIG.PORTRAIT.DEFAULT_BOOK
end

-------------------------------------------------------------------------
-- DISPLAY
-------------------------------------------------------------------------
function PortraitManager:SetPortrait(parentFrame, portraitType, customTexture)
    local portrait = GetOrCreatePortraitFrame(parentFrame)
    if not portrait then return false end

    local texturePath
    if customTexture then
        texturePath = customTexture
    elseif portraitType == self.Type.NPC then
        texturePath = self:FindNPCPortrait()
    elseif portraitType == self.Type.BOOK then
        texturePath = CONFIG.PORTRAIT.DEFAULT_BOOK
    elseif portraitType == self.Type.ITEM then
        texturePath = CONFIG.PORTRAIT.DEFAULT_ITEM
    elseif portraitType == self.Type.OBJECT then
        texturePath = CONFIG.PORTRAIT.DEFAULT_OBJECT
    else
        texturePath = CONFIG.PORTRAIT.DEFAULT_NPC
    end

    -- Validate before calling SetTexture
    if type(texturePath) == "string" and texturePath ~= "" then
        portrait.texture:SetTexture(texturePath)
    else
        PMDebug("BLOCKED bad texture path: " .. tostring(texturePath))
        portrait.texture:SetTexture(CONFIG.PORTRAIT.DEFAULT_NPC)
    end

    local success, err = pcall(function() portrait:Show() end)
    if not success then
        PMDebug("ERROR showing portrait: " .. tostring(err))
        return false
    end

    currentPortrait.type    = portraitType
    currentPortrait.texture = texturePath
    currentPortrait.frame   = parentFrame

    PMDebug("Portrait set: " .. texturePath)
    return true
end

function PortraitManager:UpdateNPCPortrait(parentFrame)
    return self:SetPortrait(parentFrame or QuestFrame, self.Type.NPC)
end

function PortraitManager:UpdateBookPortrait(parentFrame, itemName)
    local tex = self:FindBookPortrait(itemName)
    return self:SetPortrait(parentFrame or ItemTextFrame, self.Type.BOOK, tex)
end

function PortraitManager:HidePortrait(parentFrame)
    local f = parentFrame or currentPortrait.frame
    if f and f.widePortrait then
        f.widePortrait:Hide()
    end
    currentPortrait.type    = nil
    currentPortrait.texture = nil
    currentPortrait.frame   = nil
end

function PortraitManager:GetCurrentPortrait()
    return currentPortrait
end

function PortraitManager:Initialize()
    PMDebug("PortraitManager initialized")
    if not NPC_DATABASE then
        print("|cffff0000[PortraitManager]|r WARNING: NPC_DATABASE not loaded!")
    else
        PMDebug("NPC_DATABASE loaded successfully")
    end
end



-------------------------------------------------------------------------
-- Portrait-texture resolver for the mini-player
-------------------------------------------------------------------------
local function PortraitManager:GetPortraitTexture(soundData)
    if not soundData or not soundData.npcName then
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end
    if IsBookInteraction() then
        return CONFIG.PORTRAIT.DEFAULT_BOOK
    end

    local metadata = GetNPCMetadata(soundData.npcName)
    Debug(metadata.race)
    if metadata and metadata.race and metadata.sex then
        local filename = metadata.race
        if metadata.sex == "female" then filename = filename .. "_female" end
        return CONFIG.PORTRAIT.PORTRAIT_PATH .. filename .. ".tga"
    end
    return CONFIG.PORTRAIT.DEFAULT_NPC
end


-- Boot immediately so it is ready before any frame hooks fire
PortraitManager:Initialize()
