-- Book.lua
-- Book / Note / Letter layout ONLY
-- WoW 1.12.1 safe

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local BOOK_TEXT_CONFIG = {
    FRAME_WIDTH  = 620,
    FRAME_HEIGHT = 400,

    ANCHOR_POINT    = "BOTTOM",
    ANCHOR_RELATIVE = "BOTTOM",
    OFFSET_X = 0,
    OFFSET_Y = -60,

    MARGIN_LEFT   = 30,
    MARGIN_RIGHT  = 30,
    MARGIN_TOP    = 40,
    MARGIN_BOTTOM = 40,

    TEXT_RIGHT_PADDING = 20,
}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function GetVisualBackdrop(frame, inset)
    if inset and inset:IsShown() then
        return inset
    end
    return frame
end

--------------------------------------------------
-- APPLY LAYOUT
--------------------------------------------------

local function ApplyItemTextLayout()
    if not ItemTextFrame then return end

    local backdrop = GetVisualBackdrop(ItemTextFrame, ItemTextFrameInset)
    if not backdrop then return end

    -- Resize main frame
    ItemTextFrame:SetWidth(BOOK_TEXT_CONFIG.FRAME_WIDTH)
    ItemTextFrame:SetHeight(BOOK_TEXT_CONFIG.FRAME_HEIGHT)
    ItemTextFrame:ClearAllPoints()
    ItemTextFrame:SetPoint(
        BOOK_TEXT_CONFIG.ANCHOR_POINT,
        UIParent,
        BOOK_TEXT_CONFIG.ANCHOR_RELATIVE,
        BOOK_TEXT_CONFIG.OFFSET_X,
        BOOK_TEXT_CONFIG.OFFSET_Y
    )

    local contentWidth =
        backdrop:GetWidth()
        - BOOK_TEXT_CONFIG.MARGIN_LEFT
        - BOOK_TEXT_CONFIG.MARGIN_RIGHT

    local contentHeight =
        backdrop:GetHeight()
        - BOOK_TEXT_CONFIG.MARGIN_TOP
        - BOOK_TEXT_CONFIG.MARGIN_BOTTOM

    -- Scroll frame
    if ItemTextScrollFrame then
        ItemTextScrollFrame:ClearAllPoints()
        ItemTextScrollFrame:SetPoint(
            "TOPLEFT",
            backdrop,
            "TOPLEFT",
            BOOK_TEXT_CONFIG.MARGIN_LEFT,
            -BOOK_TEXT_CONFIG.MARGIN_TOP
        )
        ItemTextScrollFrame:SetWidth(contentWidth)
        ItemTextScrollFrame:SetHeight(contentHeight)
    end

    -- Text
    if ItemTextPageText then
        ItemTextPageText:SetWidth(
            contentWidth + BOOK_TEXT_CONFIG.TEXT_RIGHT_PADDING
        )
        ItemTextPageText:SetJustifyH("LEFT")
    end
end

--------------------------------------------------
-- EVENTS
--------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ITEM_TEXT_BEGIN")
eventFrame:RegisterEvent("ITEM_TEXT_READY")

eventFrame:SetScript("OnEvent", function()
    this:SetScript("OnUpdate", function()
        ApplyItemTextLayout()
        this:SetScript("OnUpdate", nil)
    end)
end)

--------------------------------------------------
-- ONSHOW HOOK
--------------------------------------------------

if ItemTextFrame then
    local originalOnShow = ItemTextFrame:GetScript("OnShow")
    ItemTextFrame:SetScript("OnShow", function()
        if originalOnShow then originalOnShow() end
        ApplyItemTextLayout()
    end)
end
