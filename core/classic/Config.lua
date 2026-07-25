do
CONFIG = {
    GAME = {
        CLIENT_VERSION = "classic",
        EXPANSION = "vanilla",
    },

    -- ================================================================
    -- SHARED DIALOG CONFIGURATION (Quest & Gossip)
    -- ================================================================
    DIALOG = {
        -- Frame dimensions
        FRAME_WIDTH  = 700,
        FRAME_HEIGHT = 400,
        
        -- Frame positioning
        ANCHOR_POINT    = "BOTTOM",
        ANCHOR_RELATIVE = "BOTTOM",
        OFFSET_X = 30,
        OFFSET_Y = -60,
        
        -- Portrait configuration
        PORTRAIT_WIDTH  = 160,
        PORTRAIT_HEIGHT = 240,
        PORTRAIT_OFFSET_X = 30,
        PORTRAIT_OFFSET_Y = 60,
        
        -- Content area (margins from frame edges)
        CONTENT_MARGIN_LEFT  = 200,  -- Space for portrait on left
        CONTENT_MARGIN_RIGHT = 60,
        CONTENT_MARGIN_TOP   = 60,
        CONTENT_MARGIN_BOTTOM = 100,
        
        -- Text area (can differ from content area)
        TEXT_WIDTH_OVERRIDE = 600,  -- Set to number to override, nil uses content width
        TEXT_EXTRA_PADDING_RIGHT = 35,
        TEXT_JUSTIFY = "LEFT",
        
        -- Scroll frame heights by dialog type
        SCROLL_HEIGHT_DETAIL   = 240,
        SCROLL_HEIGHT_PROGRESS = 240,
        SCROLL_HEIGHT_REWARD   = 240,
        SCROLL_HEIGHT_GREETING = 240,
        SCROLL_HEIGHT_GOSSIP   = 240,
        
        -- Button positioning
        BUTTON_OFFSET_X = 80,   -- Distance from center
        BUTTON_OFFSET_Y = 30,   -- Distance from bottom
        CLOSE_OFFSET_X  = 15,   -- Distance from right edge
        CLOSE_OFFSET_Y  = 15,   -- Distance from top edge
        
        -- Gossip-specific button config
        GOSSIP_BUTTON_HEIGHT_PADDING = 4,
        GOSSIP_BUTTON_TEXT_LEFT      = 25,
        GOSSIP_BUTTON_TEXT_RIGHT     = 5,
        GOSSIP_BUTTON_ICON_LEFT      = 3,
        
        -- Scrollbar positioning
        SCROLLBAR_OFFSET_X      = -20,
        SCROLLBAR_OFFSET_TOP    = 16,
        SCROLLBAR_OFFSET_BOTTOM = 16,
    },
    
    -- ================================================================
    -- PORTRAIT MANAGER CONFIGURATION
    -- ================================================================
    PORTRAIT = {
        DEBUG = false,
        
        -- Default textures by type
        DEFAULT_NPC    = "Interface\\AddOns\\BetterQuest\\portraits\\default.tga",
        DEFAULT_BOOK   = "Interface\\Icons\\INV_Misc_Book_09",
        DEFAULT_ITEM   = "Interface\\Icons\\INV_Misc_QuestionMark",
        DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",
        
        -- Portrait path
        PORTRAIT_PATH = "Interface\\AddOns\\BetterQuest\\portraits\\",
    },
    
    -- ================================================================
    -- BOOK/NOTE/LETTER CONFIGURATION
    -- ================================================================
    BOOK = {
        FRAME_WIDTH  = 620,
        FRAME_HEIGHT = 400,
        TEXT_WIDTH_OVERRIDE = 550,  -- Set to number to override, nil uses content width

        
        ANCHOR_POINT    = "BOTTOM",
        ANCHOR_RELATIVE = "BOTTOM",
        OFFSET_X = 0,
        OFFSET_Y = -60,
        
        MARGIN_LEFT   = 30,
        MARGIN_RIGHT  = 50,
        MARGIN_TOP    = 40,
        MARGIN_BOTTOM = 120,
        
        TEXT_RIGHT_PADDING = 40,
    },
    
    -- ================================================================
    -- SOUND QUEUE MINI-PLAYER CONFIGURATION
    -- ================================================================
    SOUNDQUEUE = {
        FRAME_WIDTH  = 300,
        FRAME_HEIGHT = 80,
        
        ANCHOR_POINT = "BOTTOMRIGHT",
        OFFSET_X = -20,
        OFFSET_Y = 100,
        
        PORTRAIT_SIZE = 60,
        PORTRAIT_LEFT = 10,
        
        INFO_LEFT = 80,
        INFO_TOP_NPC = -15,
        INFO_TOP_TITLE = -35,
        INFO_WIDTH = 180,
        
        STATUS_LEFT = 80,
        STATUS_BOTTOM = 15,
        
        QUEUE_LEFT = 80,
        QUEUE_TOP = -55,
        QUEUE_WIDTH = 200,
        QUEUE_HEIGHT = 80,
        QUEUE_MAX_DISPLAY = 5,
        QUEUE_BUTTON_HEIGHT = 15,
        QUEUE_BUTTON_SPACING = 16,
        
        CLOSE_BUTTON_SIZE = 20,
        CONTROL_BUTTON_SIZE = 24,
        BACK_BUTTON_SIZE = 20,
        
        BACK_BUTTON_RIGHT = -50,
        BACK_BUTTON_BOTTOM = 10,
        
        PAUSE_BUTTON_RIGHT = -25,
        PAUSE_BUTTON_BOTTOM = 8,
        
    },
}


-- Computed values (derived from config)
COMPUTED = {
    DIALOG_CONTENT_WIDTH = CONFIG.DIALOG.FRAME_WIDTH 
        - CONFIG.DIALOG.CONTENT_MARGIN_LEFT 
        - CONFIG.DIALOG.CONTENT_MARGIN_RIGHT,
        
    DIALOG_CONTENT_HEIGHT = CONFIG.DIALOG.FRAME_HEIGHT 
        - CONFIG.DIALOG.CONTENT_MARGIN_TOP 
        - CONFIG.DIALOG.CONTENT_MARGIN_BOTTOM,
        
    DIALOG_TEXT_WIDTH = 400,  -- Computed in GetDialogTextWidth()
}
end
