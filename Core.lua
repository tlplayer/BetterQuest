-- core.lua
-- Entry point.  Event registration, Broadcast state, and the QueueTrigger
-- delay that sits between a game event and SoundQueue:AddSound().
-- Load order: 4 of 4  (utils → soundqueue → ui → core)
--
-- Globals exported:
--   Broadcast   — NPC-chat monitoring state + slash commands
--
-- Dependencies (must already be loaded):
--   Debug                   ← utils.lua
--   SoundQueue              ← soundqueue.lua
--   PortraitManager         ← ui.lua

-- =====================================================================
--   BROADCAST  —  world NPC speech capture
-- =====================================================================

Broadcast = {
    enabled     = true,
    lastNPCName = nil,
    lastNPCText = nil,
}


-- Duplicate-guard: same NPC saying the exact same thing back-to-back is skipped
local function ShouldPlayNPCSound(npcName, text)
    if not Broadcast.enabled         then return false end
    if not npcName or not text       then return false end
    if text == ""                    then return false end
    if Broadcast.lastNPCName == npcName
       and Broadcast.lastNPCText == text then return false end
    return true
end

local function OnNPCSay(msg, sender)
    if not ShouldPlayNPCSound(sender, msg) then return end

    Debug("Broadcast: " .. sender .. " — " .. string.sub(msg, 1, 50) .. "...")

    Broadcast.lastNPCName = sender
    Broadcast.lastNPCText = msg

    if SoundQueue then
        SoundQueue:AddSound(sender, msg, sender)
    else
        Debug("ERROR: SoundQueue not available for Broadcast")
    end
end


-- =====================================================================
--   QUEUE TRIGGER  —  delay wrapper between game events and AddSound
-- =====================================================================
-- WoW 1.12.1 fires quest/gossip events before the text accessors are
-- actually populated.  A single-frame delay (0.1 s) lets the client
-- catch up before we read the text.

local delayFrameActive = false

local function QueueTrigger(npcName, eventType)
    if delayFrameActive then return end   -- coalesce rapid-fire events
    delayFrameActive = true

    local delayFrame = CreateFrame("Frame")
    local startTime  = GetTime()
    local WAIT       = 0.1

    delayFrame:SetScript("OnUpdate", function()
        if GetTime() - startTime < WAIT then return end

        -- Frame is done waiting — tear down the script first
        this:SetScript("OnUpdate", nil)

        local text, title
        if    eventType == "QUEST_DETAIL"   then
            text, title = GetQuestText(),    GetTitleText()
        elseif eventType == "QUEST_PROGRESS" then
            text, title = GetProgressText(), GetTitleText()
        elseif eventType == "QUEST_COMPLETE" then
            text, title = GetRewardText(),   GetTitleText()
        elseif eventType == "GOSSIP_SHOW"    then
            text, title = GetGossipText(),   "Gossip"
        end

        if text and text ~= "" then
            Debug("Adding sound to queue from core:".. text)
            SoundQueue:AddSound(npcName, text, title)
        end

        delayFrameActive = false
    end)
end

-- =====================================================================
--   ADDON_LOADED  —  boot sequence
-- =====================================================================

local addonFrame = CreateFrame("Frame")
addonFrame:RegisterEvent("ADDON_LOADED")

addonFrame:SetScript("OnEvent", function()
    if event ~= "ADDON_LOADED" or arg1 ~= "BetterQuest" then return end
     Utils:InitializeBetterQuestDB()
    
     -- 3) Quest / Gossip event dispatcher
    local questGossipFrame = CreateFrame("Frame")
    questGossipFrame:RegisterEvent("QUEST_DETAIL")
    questGossipFrame:RegisterEvent("QUEST_PROGRESS")
    questGossipFrame:RegisterEvent("QUEST_COMPLETE")
    questGossipFrame:RegisterEvent("GOSSIP_SHOW")

    questGossipFrame:SetScript("OnEvent", function()
        QueueTrigger(UnitName("npc"), event)
    end)

    -- 4) World NPC speech dispatcher
    local broadcastFrame = CreateFrame("Frame")
    broadcastFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    broadcastFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")

    broadcastFrame:SetScript("OnEvent", function()
        if event == "CHAT_MSG_MONSTER_SAY" or event == "CHAT_MSG_MONSTER_YELL" then
            OnNPCSay(arg1, arg2)
        end
    end)

    Debug("BetterQuest initialized")
end)


-------------------------------------------------
-- SLASH COMMANDS
-------------------------------------------------

SLASH_SOUNDQUEUE1 = "/bq"
SLASH_SOUNDQUEUE2 = "/soundqueue"

SlashCmdList["SOUNDQUEUE"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "show" then
        if SoundQueue.frame and SoundQueue:GetCurrentSound() then
            SoundQueue:ShowFrame()
        end

    elseif msg == "history" then
        if table.getn(SoundQueue.history) == 0 then
            Debug("No history")
        else
            Debug("=== History (" .. table.getn(SoundQueue.history) .. ") ===")
            for i = 1, math.min(10, table.getn(SoundQueue.history)) do
                local entry = SoundQueue.history[i]
                Debug(i .. ". " .. (entry.npcName or "Unknown") .. " - " .. (entry.title or ""))
            end
        end

    elseif msg == "clear" then
        SoundQueue:ClearHistory()

    elseif string.find(msg, "play ") == 1 then
        local index = tonumber(string.sub(msg, 6))
        if index then SoundQueue:PlayFromHistory(index) end

    elseif msg == "pause" then
        SoundQueue:TogglePause()

    elseif msg == "missing" then
        SoundQueue:ExportMissingNPCs()

    elseif msg == "clearmissing" then
        SoundQueue:ClearMissingNPCs()

    else
        Debug("Commands: show, history, play <n>, clear, pause, missing, clearmissing")
    end
end