-- utils.lua
-- Shared utility functions — no addon-specific state.
-- Load order: 1 of 4  (utils → soundqueue → ui → core)

Utils = {}
local playerName = UnitName("player")
local _, playerClass = UnitClass("player")
local DEBUG_ENABLED = false


-------------------------------------------------
-- DEBUG / LOGGING
-------------------------------------------------

function Debug(msg)
    if DEBUG_ENABLED then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[BetterQuest]|r " .. tostring(msg))
    end
end

-- ===== Slash command to reload UI =====
SLASH_BETTERQUEST_RELOAD1 = "/reload"
SLASH_BETTERQUEST_RELOAD2 = "/rl"

SlashCmdList["BETTERQUEST_RELOAD"] = function()
    ReloadUI()
end


-------------------------------------------------
-- STRING / PATH NORMALIZERS
-------------------------------------------------

-- Guarantee backslashes, strip whitespace
function Utils:NormalizePath(path)
    if not path then return nil end
    path = string.gsub(path, "^%s+", "")
    path = string.gsub(path, "%s+$", "")
    if path == "" then return nil end
    path = string.gsub(path, "/", "\\")
    return path
end

-- Secondary / duplicate normalizers (kept as-is)
function Utils:NormalizeNPCName(name)
    if not name then return nil end
    name = string.gsub(name, "['']", "")
    return name
end

function Utils:NormalizePath(path)
    if not path then return nil end
    return string.gsub(path, "/+", "\\")
end

-------------------------------------------------
-- DIALOG TEXT NORMALIZATION
-------------------------------------------------

function Utils:NormalizeDialogText(text)
    if not text then return "" end

    text = string.gsub(text, "%$[nNcCrR]", "adventurer")
    text = string.gsub(text, "%$g[^;]*;", "adventurer")

    if playerName ~= "" then
        text = string.gsub(text, playerName, "adventurer")
    end
    if playerClass ~= "" then
        text = string.gsub(text, playerClass, "adventurer")
    end

    text = string.gsub(text, "%$%w+", "")
    text = string.gsub(text, "%b[]", "")
    text = string.gsub(text, "%b()", "")
    text = string.gsub(text, "%b<>", "")
    text = string.gsub(text, "[^%w%s]", "")

    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.lower(text)

    return string.sub(text, 1, 50)
end

-------------------------------------------------
-- CONTEXT HELPERS
-------------------------------------------------

function Utils:IsBookInteraction()
    return ItemTextFrame and ItemTextFrame:IsShown()
end

-------------------------------------------------
-- SAFE SOUND HELPERS
-------------------------------------------------

function Utils:PlaySound(soundData)
    if not soundData then return nil end

    filePath = Utils:NormalizePath(soundData.filePath)
    Debug("Loading" .. tostring(filePath))

    if not filePath or filePath == "" then return nil end
    if soundData.duration == 0.0 then return nil end

    local handle
    local ok = pcall(function()
        handle = PlaySoundFile(filePath)
    end)

    return ok and handle or nil
end

function Utils:StopSound(soundData)
    if soundData.handle then
        SetCVar("MasterSoundEffects", 0)
        SetCVar("MasterSoundEffects", 1)
    end
end
