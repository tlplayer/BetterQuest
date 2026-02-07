-- ui.lua
-- Every frame, layout hook, portrait, and UI-update callback lives here.
-- Load order: 3 of 4  (utils → soundqueue → ui → core)
--

-- Helper to get text width (allows override)
local function UI:GetDialogTextWidth()
    if not COMPUTED.DIALOG_TEXT_WIDTH then
        local base = COMPUTED.DIALOG_CONTENT_WIDTH
        if CONFIG.DIALOG.TEXT_WIDTH_OVERRIDE then
            base = CONFIG.DIALOG.TEXT_WIDTH_OVERRIDE
        end
        COMPUTED.DIALOG_TEXT_WIDTH = base + CONFIG.DIALOG.TEXT_EXTRA_PADDING_RIGHT
    end
    return COMPUTED.DIALOG_TEXT_WIDTH
end

