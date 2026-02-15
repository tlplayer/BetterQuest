

-- =====================================================================
--   SECTION 5 — Book / Note / Letter Layout
-- =====================================================================

do  -- block-scope

local function GetVisualBackdrop(frame, inset)
    if inset and inset:IsShown() then return inset end
    return frame
end

local function ApplyItemTextLayout()
    if not ItemTextFrame then return end

    local backdrop = GetVisualBackdrop(ItemTextFrame, ItemTextFrameInset)
    if not backdrop then return end

    ItemTextFrame:SetWidth(CONFIG.BOOK.FRAME_WIDTH)
    ItemTextFrame:SetHeight(CONFIG.BOOK.FRAME_HEIGHT)
    ItemTextFrame:ClearAllPoints()
    ItemTextFrame:SetPoint(
        CONFIG.BOOK.ANCHOR_POINT, UIParent, CONFIG.BOOK.ANCHOR_RELATIVE,
        CONFIG.BOOK.OFFSET_X, CONFIG.BOOK.OFFSET_Y)

    local contentWidth  = CONFIG.BOOK.TEXT_WIDTH_OVERRIDE
    local contentHeight = backdrop:GetHeight() - CONFIG.BOOK.MARGIN_TOP  - CONFIG.BOOK.MARGIN_BOTTOM

    if ItemTextScrollFrame then
        ItemTextScrollFrame:ClearAllPoints()
        ItemTextScrollFrame:SetPoint("TOPLEFT", backdrop, "TOPLEFT",
            CONFIG.BOOK.MARGIN_LEFT, -CONFIG.BOOK.MARGIN_TOP)
        ItemTextScrollFrame:SetWidth(contentWidth)
        ItemTextScrollFrame:SetHeight(contentHeight)
    end

    if ItemTextPageText then
        ItemTextPageText:SetWidth( CONFIG.BOOK.TEXT_WIDTH_OVERRIDE)
        ItemTextPageText:SetJustifyH("LEFT")
    end
end

-- Play the book's voice-over via SoundQueue
local function PlayBookVoice()
    if not ItemTextFrame or not ItemTextFrame:IsShown() then return end

    local title = ItemTextTitleText and ItemTextTitleText:GetText()
    if not title or title == "" then
        Debug("BookVoice: no title found")
        return
    end

    local text = ItemTextGetText()
    if not text or text == "" then
        Debug("BookVoice: no text found")
        return
    end

    if SoundQueue then
        SoundQueue:AddSound(title, text, title)
    end
end

-- Layout events
local bookLayoutFrame = CreateFrame("Frame")
bookLayoutFrame:RegisterEvent("ITEM_TEXT_BEGIN")
bookLayoutFrame:RegisterEvent("ITEM_TEXT_READY")
bookLayoutFrame:SetScript("OnEvent", function()
    this:SetScript("OnUpdate", function()
        ApplyItemTextLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

-- Voice-over trigger (fires when page text is actually available)
local bookVoiceFrame = CreateFrame("Frame")
bookVoiceFrame:RegisterEvent("ITEM_TEXT_READY")
bookVoiceFrame:SetScript("OnEvent", function()
    PlayBookVoice()
end)

-- OnShow hook
if ItemTextFrame then
    local originalBookOnShow = ItemTextFrame:GetScript("OnShow")
    ItemTextFrame:SetScript("OnShow", function()
        if originalBookOnShow then originalBookOnShow() end
        ApplyItemTextLayout()
    end)
end

end  -- end Book do-block