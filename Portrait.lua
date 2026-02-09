--=====================================================================
-- PortraitManager.lua
-- Responsible for:
--   • Resolving NPC / Book portrait textures
--   • Managing portrait frames
--   • Displaying portraits in UI
-- Dependencies:
--   Utils, NPC_DATABASE, CONFIG
--=====================================================================

-------------------------------------------------------------------------
-- MODULE TABLE
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

-------------------------------------------------------------------------
-- MODULE-PRIVATE STATE
-------------------------------------------------------------------------
local currentPortrait = {
    type    = nil,
    texture = nil,
    frame   = nil,
}

local activeNPCName = nil

-------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------
local function PMDebug(msg)
    if PortraitManager.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[Portrait]|r " .. tostring(msg))
    end
end

-------------------------------------------------------------------------
-- PORTRAIT PATH HELPERS
-------------------------------------------------------------------------
local function BuildPortraitPath(race, sex)
    if not race or race == "" then
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end

    local filename = race
    if sex == "female" then
        filename = filename .. "_female"
    end

    return CONFIG.PORTRAIT.PORTRAIT_PATH .. filename .. ".tga"
end

-------------------------------------------------------------------------
-- FRAME MANAGEMENT
-------------------------------------------------------------------------
local function GetOrCreatePortraitFrame(parentFrame)
    if not parentFrame then return nil end
    if parentFrame.widePortrait then
        return parentFrame.widePortrait
    end

    local portrait = CreateFrame("Frame", nil, parentFrame)
    portrait:SetWidth(CONFIG.DIALOG.PORTRAIT_WIDTH)
    portrait:SetHeight(CONFIG.DIALOG.PORTRAIT_HEIGHT)
    portrait:SetPoint(
        "TOPLEFT",
        parentFrame,
        "TOPLEFT",
        CONFIG.DIALOG.PORTRAIT_OFFSET_X,
        -CONFIG.DIALOG.PORTRAIT_OFFSET_Y
    )

    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.bg:SetAllPoints()
    portrait.bg:SetTexture(0, 0, 0, 0)

    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetAllPoints()
    portrait.texture:SetTexCoord(0, 1, 0, 1)

    parentFrame.widePortrait = portrait
    return portrait
end

-------------------------------------------------------------------------
-- ACTIVE NPC CONTROL
-------------------------------------------------------------------------
function PortraitManager:SetActiveNPC(name)
    activeNPCName = name
    PMDebug("Active NPC set: " .. tostring(name))
end

function PortraitManager:ClearActiveNPC()
    activeNPCName = nil
end


-------------------------------------------------------------------------
-- PORTRAIT TEXTURE RESOLUTION (SINGLE SOURCE OF TRUTH)
-------------------------------------------------------------------------
local function ResolveNPCPortraitTexture(metadata)

    Debug("Resolving portrait for" .. metadata.name)
    if Utils:IsBookInteraction() then
        return CONFIG.PORTRAIT.DEFAULT_BOOK
    end

    if not metadata.name then
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end

    if metadata and metadata.race  then
    Debug("Found NPC Metadata for" .. npcName)
        return BuildPortraitPath(metadata.race, metadata.sex)
    end
    Debug("Did not find metadata for" .. npcName)

    return CONFIG.PORTRAIT.DEFAULT_NPC
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
-- PUBLIC PORTRAIT RESOLVERS
-------------------------------------------------------------------------
function PortraitManager:FindNPCPortrait(soundData)
    if not soundData or not soundData.name then
        PMDebug("No NPC info available, using default")
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end

    local path = ResolveNPCPortraitTexture(soundData.name)
    PMDebug("Using portrait: " .. tostring(path))
    return path
end

function PortraitManager:FindNPCPortraitByKey(key)
    if not key or key == "" then
        return CONFIG.PORTRAIT.DEFAULT_NPC
    end
    return CONFIG.PORTRAIT.PORTRAIT_PATH .. key .. ".tga"
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

    if type(texturePath) ~= "string" or texturePath == "" then
        PMDebug("Blocked invalid texture path: " .. tostring(texturePath))
        texturePath = CONFIG.PORTRAIT.DEFAULT_NPC
    end

    portrait.texture:SetTexture(texturePath)
    portrait:Show()

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

-------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------
function PortraitManager:Initialize()
    PMDebug("PortraitManager initialized")
    if not NPC_DATABASE then
        PMDebug("WARNING: NPC_DATABASE not loaded yet")
    end
end

-- Boot immediately so hooks can rely on it
PortraitManager:Initialize()
