-------------------------------------------------------------------------
-- NPC CONTROL
-------------------------------------------------------------------------
function PortraitManager:SetActiveNPC(name)
    activeNPCName = name
    PMDebug("Active NPC set: " .. tostring(name))
end

function PortraitManager:ClearActiveNPC()
    activeNPCName = nil
end

function PortraitManager:GetNPCInfo()
    local name = activeNPCName or UnitName("npc") or UnitName("target") 
    local normalizedName = NormalizeNPCName(name)

    local metadata = GetNPCMetadata and GetNPCMetadata(normalizedName)
    if not metadata then
        PMDebug("No metadata found for: " .. tostring(name))
        return nil
    end

    return {
        name     = normalizedName,
        race     = metadata.race     or "unknown",
        sex      = metadata.sex      or "male",
        portrait = metadata.portrait or metadata.race or "default",
        zone     = metadata.zone     or GetZoneText() or "Unknown",
        model_id = metadata.model_id,
        narrator = metadata.narrator or "default",
    }
end

function PortraitManager:FindNPCPortrait()
    local npc = self:GetNPCInfo()
    if not npc then
        PMDebug("No NPC info available, using default")
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end
    if npc.race and npc.race ~= "" then
        local path = BuildPortraitPath(npc.race, npc.sex)
        PMDebug("Using portrait: " .. path)
        return path
    end
    PMDebug("No race found, using default")
    return CONFIG.PORTRAIT.DEFAULT_NPC
end

function PortraitManager:FindNPCPortraitByKey(key)
    if not key or key == "" then return CONFIG.PORTRAIT.DEFAULT_NPC end
    return CONFIG.PORTRAIT.PORTRAIT_PATH .. key .. ".tga"
end

-- =====================================================================
--   SECTION 1 — PortraitManager
-- =====================================================================

-------------------------------------------------------------------------
-- PORTRAIT MANAGER  (replaces the two identical copies in the old code)
-------------------------------------------------------------------------
PortraitManager = {}
PortraitManager.Type = {
    NPC    = "npc",
    BOOK   = "book",
    ITEM   = "item",
    OBJECT = "object",
    CUSTOM = "custom",
}
PortraitManager.DEBUG = CONFIG.PORTRAIT.DEBUG

-- Module-private state
local currentPortrait = {
    type    = nil,
    texture = nil,
    frame   = nil,
}
local activeNPCName = nil

-- Debug helper scoped to PortraitManager
local function PMDebug(msg)
    if PortraitManager.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. msg)
    end
end

-- Build "portraits/race.tga" or "portraits/race_female.tga"
local function BuildPortraitPath(race, sex)
    if not race or race == "" then return CONFIG.PORTRAIT.DEFAULT_NPC end
    local filename = race
    if sex == "female" then filename = filename .. "_female" end
    return CONFIG.PORTRAIT.PORTRAIT_PATH .. filename .. ".tga"
end

-- Get-or-create the wide portrait sub-frame on any parent.
-- Reuses an existing one; only creates if absent.
local function GetOrCreatePortraitFrame(parentFrame)
    if not parentFrame then return nil end
    if parentFrame.widePortrait then return parentFrame.widePortrait end

    local portrait = CreateFrame("Frame", nil, parentFrame)
    portrait:SetWidth(CONFIG.DIALOG.PORTRAIT_WIDTH)
    portrait:SetHeight(CONFIG.DIALOG.PORTRAIT_HEIGHT)
    portrait:SetPoint("TOPLEFT", parentFrame, "TOPLEFT",
        CONFIG.DIALOG.PORTRAIT_OFFSET_X, -CONFIG.DIALOG.PORTRAIT_OFFSET_Y)

    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints()
    portrait.bg:SetTexture(0, 0, 0, 0)  -- Transparent - let PFUI handle backgrounds
    
    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints()
    portrait.texture:SetTexCoord(0, 1, 0, 1)

    parentFrame.widePortrait = portrait
    currentPortrait.frame = parentFrame
    return portrait
end


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
