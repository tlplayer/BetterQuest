-- Config.lua
-- Centralized configuration for BetterQuestText addon
-- All frame dimensions, positioning, and feature flags

BQT_Config = {}

-------------------------
-- QUEST FRAME CONFIGURATION
-------------------------

BQT_Config.Quest = {
  -- Frame dimensions
  WIDTH = 620,
  HEIGHT = 400,
  
  -- Positioning
  POS_X = 0,
  POS_Y = -60,
  ANCHOR_POINT = "BOTTOM",
  ANCHOR_RELATIVE = "BOTTOM",
  
  -- Content margins
  MARGIN_LEFT = 140,
  MARGIN_RIGHT = 50,
  MARGIN_TOP = 50,
  
  -- Scroll frame heights
  SCROLL_HEIGHT_DETAIL = 220,
  SCROLL_HEIGHT_PROGRESS = 220,
  SCROLL_HEIGHT_REWARD = 200,
  
  -- Button positioning
  BUTTON_OFFSET_X = 20,
  BUTTON_OFFSET_Y = 20,
  
  -- Close button
  CLOSE_OFFSET_X = 8,
  CLOSE_OFFSET_Y = 8,
  
  -- Scrollbar positioning
  SCROLLBAR_OFFSET_X = 16,
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
}

-------------------------
-- PORTRAIT CONFIGURATION
-------------------------

BQT_Config.Portrait = {
  -- Portrait frame dimensions
  WIDTH = 125,
  HEIGHT = 220,
  
  -- Positioning offset from parent
  OFFSET_X = 15,
  OFFSET_Y = 50,
  
  -- Default textures
  DEFAULT_NPC = "Interface\\CharacterFrame\\TempPortrait",
  DEFAULT_BOOK = "Interface\\Icons\\INV_Misc_Book_09",
  DEFAULT_ITEM = "Interface\\Icons\\INV_Misc_QuestionMark",
  DEFAULT_OBJECT = "Interface\\Icons\\INV_Misc_Gear_01",
  
  -- Feature flags
  ENABLE_NPC_PORTRAITS = true,
  ENABLE_BOOK_PORTRAITS = true,
  
  -- Debug
  DEBUG = false,
}

-------------------------
-- TEXT FRAME CONFIGURATION (Gossip, Books, Notes)
-------------------------

BQT_Config.TextFrame = {
  -- Frame dimensions
  WIDTH = 620,
  HEIGHT = 350,
  
  -- Positioning
  ANCHOR_POINT = "CENTER",
  ANCHOR_RELATIVE = "CENTER",
  OFFSET_X = 0,
  OFFSET_Y = -250,
  
  -- Content margins
  MARGIN_LEFT = 15,
  MARGIN_RIGHT = 30,
  MARGIN_TOP = 30,
  MARGIN_BOTTOM = 30,
  
  -- Text padding
  TEXT_RIGHT_PADDING = -100,
  
  -- Scrollbar positioning
  SCROLLBAR_OFFSET_X = 16,
  SCROLLBAR_OFFSET_TOP = 16,
  SCROLLBAR_OFFSET_BOTTOM = 16,
}

-------------------------
-- GOSSIP FRAME CONFIGURATION
-------------------------

BQT_Config.Gossip = {
  -- Additional width reduction for gossip buttons
  BUTTON_WIDTH_REDUCTION = 40,
  
  -- Additional height reduction for gossip content
  CONTENT_HEIGHT_REDUCTION = 90,
}

-------------------------
-- BOOK VOICEOVER CONFIGURATION
-------------------------

BQT_Config.BookVoiceover = {
  -- Audio settings
  SOUND_PATH = "Interface\\AddOns\\BetterQuestText\\sounds\\books\\",
  NARRATOR = "Narrator",
  VOLUME = 1.0,
  
  -- Feature flags
  ENABLED = true,
  USE_VOICEOVER_QUEUE = true, -- Use AI_VoiceOver queue if available
  
  -- Matching settings
  FUZZY_MATCH_THRESHOLD = 70, -- Percentage similarity required
  
  -- Debug
  DEBUG = true,
}

-------------------------
-- ADDON GENERAL SETTINGS
-------------------------

BQT_Config.General = {
  -- Addon metadata
  NAME = "BetterQuestText",
  VERSION = "1.0",
  AUTHOR = "Timothy Player",
  
  -- Feature flags
  ENABLE_QUEST_FRAMES = true,
  ENABLE_GOSSIP_FRAMES = true,
  ENABLE_ITEM_TEXT_FRAMES = true,
  ENABLE_BOOK_VOICEOVER = true,
  
  -- Compatibility
  PFUI_COMPATIBLE = true, -- Support pfUI addon
  
  -- Performance
  INIT_DELAY = 0.5, -- Delay before applying layouts (seconds)
  UPDATE_DELAY = 0.1, -- Delay for OnUpdate frame updates
  
  -- Debug
  DEBUG_MODE = false,
}

-------------------------
-- COLOR CONFIGURATION
-------------------------

BQT_Config.Colors = {
  -- Chat message colors (RGB hex)
  ADDON_PREFIX = "|cff33ffcc", -- Cyan for addon name
  SUCCESS = "|cff00ff00", -- Green
  ERROR = "|cffff0000", -- Red
  WARNING = "|cffffaa00", -- Orange
  INFO = "|cff99ccff", -- Light blue
  RESET = "|r",
}

-------------------------
-- PATH CONFIGURATION
-------------------------

BQT_Config.Paths = {
  -- Base addon path
  ADDON_PATH = "Interface\\AddOns\\BetterQuestText\\",
  
  -- Database paths
  DB_PATH = "Interface\\AddOns\\BetterQuestText\\db\\",
  
  -- Portrait paths
  PORTRAITS_PATH = "Interface\\AddOns\\BetterQuestText\\portraits\\",
  PORTRAITS_NPCS = "Interface\\AddOns\\BetterQuestText\\portraits\\npcs\\",
  PORTRAITS_BOOKS = "Interface\\AddOns\\BetterQuestText\\portraits\\books\\",
  PORTRAITS_NOTES = "Interface\\AddOns\\BetterQuestText\\portraits\\notes\\",
  
  -- Sound paths
  SOUNDS_PATH = "Interface\\AddOns\\BetterQuestText\\sounds\\",
  SOUNDS_BOOKS = "Interface\\AddOns\\BetterQuestText\\sounds\\books\\",
  SOUNDS_NPCS = "Interface\\AddOns\\BetterQuestText\\sounds\\npcs\\",
}

-------------------------
-- HELPER FUNCTIONS
-------------------------

--- Get quest frame configuration
function BQT_Config.GetQuestConfig()
  return BQT_Config.Quest
end

--- Get portrait configuration
function BQT_Config.GetPortraitConfig()
  return BQT_Config.Portrait
end

--- Get text frame configuration
function BQT_Config.GetTextFrameConfig()
  return BQT_Config.TextFrame
end

--- Get book voiceover configuration
function BQT_Config.GetBookVoiceoverConfig()
  return BQT_Config.BookVoiceover
end

--- Check if feature is enabled
-- @param feature string Feature name (e.g., "ENABLE_BOOK_VOICEOVER")
-- @return boolean
function BQT_Config.IsFeatureEnabled(feature)
  return BQT_Config.General[feature] == true
end

--- Set feature enabled state
-- @param feature string Feature name
-- @param enabled boolean
function BQT_Config.SetFeature(feature, enabled)
  if BQT_Config.General[feature] ~= nil then
    BQT_Config.General[feature] = enabled
  end
end

--- Get colorized addon prefix for chat messages
-- @return string Colored addon name
function BQT_Config.GetAddonPrefix()
  return BQT_Config.Colors.ADDON_PREFIX .. BQT_Config.General.NAME .. BQT_Config.Colors.RESET
end

--- Get full path for portrait
-- @param category string "npcs", "books", or "notes"
-- @param filename string Portrait filename
-- @return string Full path
function BQT_Config.GetPortraitPath(category, filename)
  local basePath = BQT_Config.Paths["PORTRAITS_" .. string.upper(category)]
  if basePath then
    return basePath .. filename
  end
  return BQT_Config.Paths.PORTRAITS_PATH .. filename
end

--- Get full path for sound
-- @param category string "books" or "npcs"
-- @param narrator string Narrator name (e.g., "Narrator")
-- @param filename string Sound filename
-- @return string Full path
function BQT_Config.GetSoundPath(category, narrator, filename)
  local basePath = BQT_Config.Paths["SOUNDS_" .. string.upper(category)]
  if basePath and narrator and filename then
    return basePath .. narrator .. "\\" .. filename
  end
  return ""
end

--- Debug log (if debug enabled)
-- @param module string Module name
-- @param message string Log message
function BQT_Config.DebugLog(module, message)
  if BQT_Config.General.DEBUG_MODE then
    local prefix = BQT_Config.Colors.INFO .. "[" .. module .. "]" .. BQT_Config.Colors.RESET
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. message)
  end
end

--- Print addon info
function BQT_Config.PrintInfo()
  local prefix = BQT_Config.GetAddonPrefix()
  DEFAULT_CHAT_FRAME:AddMessage(prefix .. " v" .. BQT_Config.General.VERSION .. " loaded")
  
  if BQT_Config.General.DEBUG_MODE then
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " Debug mode enabled")
  end
end

-------------------------
-- VALIDATION
-------------------------

--- Validate configuration on load
function BQT_Config.Validate()
  local warnings = {}
  
  -- Check frame dimensions
  if BQT_Config.Quest.WIDTH < 400 then
    table.insert(warnings, "Quest frame width may be too small")
  end
  
  if BQT_Config.Portrait.WIDTH + BQT_Config.Quest.MARGIN_LEFT > BQT_Config.Quest.WIDTH then
    table.insert(warnings, "Portrait may overlap with content")
  end
  
  -- Print warnings
  if table.getn(warnings) > 0 then
    local prefix = BQT_Config.Colors.WARNING .. "[Config]" .. BQT_Config.Colors.RESET
    for _, warning in ipairs(warnings) do
      DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. warning)
    end
  end
  
  return table.getn(warnings) == 0
end

-- Auto-validate on load
BQT_Config.Validate()