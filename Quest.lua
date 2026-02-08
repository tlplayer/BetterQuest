-- =====================================================================
--   SECTION 3 — QuestFrame Layout (PFUI-Compatible, UI-driven)
-- =====================================================================

do

local function ApplyQuestLayout()
    if not QuestFrame then return end

    UI:ApplyDialogFrame(QuestFrame)
    UI:UpdateNPCPortrait(QuestFrame)

    UI:ApplyScrollFrame(QuestDetailScrollFrame,   C().DIALOG.SCROLL_HEIGHT_DETAIL)
    UI:ApplyScrollFrame(QuestProgressScrollFrame, C().DIALOG.SCROLL_HEIGHT_PROGRESS)
    UI:ApplyScrollFrame(QuestRewardScrollFrame,   C().DIALOG.SCROLL_HEIGHT_REWARD)
    UI:ApplyScrollFrame(QuestGreetingScrollFrame, C().DIALOG.SCROLL_HEIGHT_GREETING)

    UI:ApplyScrollChild(QuestDetailScrollChildFrame)
    UI:ApplyScrollChild(QuestProgressScrollChildFrame)
    UI:ApplyScrollChild(QuestRewardScrollChildFrame)
    UI:ApplyScrollChild(QuestGreetingScrollChildFrame)

    UI:ApplyQuestButtons(QuestFrame)
end

local function FixTextWidths()
    local width = UI:GetDialogTextWidth()

    local fields = {
        QuestTitleText,
        QuestDescription,
        QuestObjectiveText,
        QuestProgressText,
        QuestRewardText,
        GreetingText,
    }

    for _, f in ipairs(fields) do
        if f then
            f:SetWidth(width)
            f:SetJustifyH(C().DIALOG.TEXT_JUSTIFY)
        end
    end

    for i = 1, 32 do
        local button = getglobal("QuestTitleButton"..i)
        if button and button:IsShown() then
            button:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH)
            local text = getglobal("QuestTitleButton"..i.."QuestTitle")
            if text then
                text:SetWidth(COMPUTED.DIALOG_CONTENT_WIDTH - 20)
                text:SetJustifyH("LEFT")
            end
        end
    end
end

-- SoundQueue → portrait
local function HookQuestSoundQueue()
    if not SoundQueue then return end

    SoundQueue.OnVoiceStart = function(_, data)
        if not data then return end
        if data.dialog_type == "quest" or data.dialog_type == "gossip" then
            if PortraitManager and data.npc_name then
                PortraitManager:SetActiveNPC(data.npc_name)
            end
            UI:UpdateNPCPortrait(QuestFrame)
        end
    end

    SoundQueue.OnVoiceStop = function()
        UI:HidePortrait(QuestFrame)
    end
end

local questEventFrame = CreateFrame("Frame")
questEventFrame:RegisterEvent("QUEST_DETAIL")
questEventFrame:RegisterEvent("QUEST_PROGRESS")
questEventFrame:RegisterEvent("QUEST_COMPLETE")
questEventFrame:RegisterEvent("QUEST_GREETING")

questEventFrame:SetScript("OnEvent", function()
    this:SetScript("OnUpdate", function()
        ApplyQuestLayout()
        FixTextWidths()
        this:SetScript("OnUpdate", nil)
    end)
end)

local originalQuestOnShow = QuestFrame:GetScript("OnShow")
QuestFrame:SetScript("OnShow", function()
    if originalQuestOnShow then originalQuestOnShow() end
    ApplyQuestLayout()
    FixTextWidths()
end)

local initFrame = CreateFrame("Frame")
local timer = 0
initFrame:SetScript("OnUpdate", function()
    timer = timer + arg1
    if timer > 0.5 then
        ApplyQuestLayout()
        FixTextWidths()
        HookQuestSoundQueue()
        this:SetScript("OnUpdate", nil)
    end
end)

end
