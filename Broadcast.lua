-- Broadcast.lua
-- NPC chat monitoring system for WoW 1.12.1
-- Captures NPC dialogue from chat and triggers SoundQueue playback

Broadcast = {
    enabled = true,
    lastNPCName = nil,
    lastNPCText = nil,
}

-------------------------------------------------
-- DEBUG
-------------------------------------------------

local function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[Broadcast]|r " .. tostring(msg))
end

-------------------------------------------------
-- NPC CHAT DETECTION
-------------------------------------------------

-- Extract NPC name and text from chat messages
local function ParseNPCMessage(msg, sender)
    -- In WoW 1.12.1, NPC speech appears in CHAT_MSG_MONSTER_SAY
    -- sender is the NPC name, msg is what they said
    return sender, msg
end

-- Check if this is valid NPC dialogue we should play
local function ShouldPlayNPCSound(npcName, text)
    if not Broadcast.enabled then return false end
    if not npcName or not text then return false end
    if text == "" then return false end
    
    -- Avoid duplicate triggers (same NPC saying same thing rapidly)
    if Broadcast.lastNPCName == npcName and Broadcast.lastNPCText == text then
        return false
    end
    
    return true
end

-------------------------------------------------
-- EVENT HANDLERS
-------------------------------------------------

local function OnNPCSay(msg, sender)
    local npcName, text = ParseNPCMessage(msg, sender)
    
    if not ShouldPlayNPCSound(npcName, text) then return end
    
    Debug("NPC Speech: " .. npcName .. " - " .. string.sub(text, 1, 50) .. "...")
    
    -- Store to prevent immediate duplicates
    Broadcast.lastNPCName = npcName
    Broadcast.lastNPCText = text
    
    -- Queue the sound if SoundQueue is available
    if SoundQueue and SoundQueue.AddSound then
        SoundQueue:AddSound(npcName, text, npcName)
    else
        Debug("ERROR: SoundQueue not found!")
    end
end

local function OnNPCYell(msg, sender)
    -- Same handler as SAY, just different event
    OnNPCSay(msg, sender)
end

-------------------------------------------------
-- SLASH COMMANDS
-------------------------------------------------

local function HandleSlashCommand(msg)
    msg = string.lower(msg or "")
    
    if msg == "on" then
        Broadcast.enabled = true
        Debug("NPC broadcast monitoring ENABLED")
    elseif msg == "off" then
        Broadcast.enabled = false
        Debug("NPC broadcast monitoring DISABLED")
    elseif msg == "status" then
        local status = Broadcast.enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        Debug("Broadcast status: " .. status)
    elseif msg == "test" then
        -- Test with fake NPC data
        Debug("Testing with fake NPC...")
        if SoundQueue and SoundQueue.AddSound then
            SoundQueue:AddSound("Test NPC", "This is a test message", "Test")
        end
    else
        Debug("Commands: /broadcast on|off|status|test")
    end
end

-------------------------------------------------
-- INITIALIZATION
-------------------------------------------------

function Broadcast:Initialize()
    -- Create event listener frame
    local eventFrame = CreateFrame("Frame")
    
    -- Register NPC chat events
    -- CHAT_MSG_MONSTER_SAY: NPCs talking normally
    -- CHAT_MSG_MONSTER_YELL: NPCs yelling
    -- CHAT_MSG_MONSTER_EMOTE: NPC emotes (optional)
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "CHAT_MSG_MONSTER_SAY" then
            OnNPCSay(arg1, arg2)
        elseif event == "CHAT_MSG_MONSTER_YELL" then
            OnNPCYell(arg1, arg2)
        end
    end)
    
    -- Register slash command
    SLASH_BROADCAST1 = "/broadcast"
    SLASH_BROADCAST2 = "/bc"
    SlashCmdList["BROADCAST"] = HandleSlashCommand
    
    Debug("Initialized - Use /broadcast for commands")
end

-- Auto-initialize when loaded
Broadcast:Initialize()