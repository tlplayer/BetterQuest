-- bookdb.lua
-- Database mapping books/notes/letters to their audio files
-- Audio files are stored in: sounds/books/Narrator/

BookDB = {
  -- Exact item name matches (fastest lookup)
  byName = {
    ["Berard's Journal"] = "3255.wav",
    
    -- Add more books here as you create audio files
    -- Format: ["Item Name"] = "itemID.wav",
  },
  
  -- Fuzzy matching fallback (checks all entries with fuzzy matching)
  fuzzyList = {
    ["Berard's Journal"] = "3255.wav",
    ["Berards Journal"] = "3255.wav",
    
    -- Add variations and common misspellings here
  },
  
  -- Match by first line of text (for books with dynamic names)
  byFirstLine = {
    -- Format: ["normalized first line"] = "itemID.wav",
    -- Normalized = lowercase, no punctuation, no extra spaces
    
    -- Example: If a book's first line is "My dearest brother,"
    -- ["my dearest brother"] = "1234.wav",
  },
  
  -- Custom portraits for specific books (optional)
  portraits = {
    -- Format: ["Item Name"] = "Interface\\AddOns\\BetterQuestText\\portraits\\books\\custom.tga",
    -- If not specified, uses default narrator portrait or book icon
  },
}

-- Helper function to add a book with all its variations
-- @param itemID number The WoW item ID
-- @param names table List of name variations
-- @param firstLine string Optional first line of text
function BookDB.AddBook(itemID, names, firstLine)
  local audioFile = itemID .. ".wav"
  
  -- Add all name variations
  for _, name in ipairs(names) do
    BookDB.byName[name] = audioFile
    BookDB.fuzzyList[name] = audioFile
  end
  
  -- Add first line if provided
  if firstLine then
    local normalized = string.lower(firstLine)
    normalized = string.gsub(normalized, "[%p%c]", "")
    normalized = string.gsub(normalized, "%s+", " ")
    normalized = string.gsub(normalized, "^%s+", "")
    normalized = string.gsub(normalized, "%s+$", "")
    BookDB.byFirstLine[normalized] = audioFile
  end
end

-------------------------
-- BOOK ENTRIES
-------------------------

-- Berard's Journal (item 3255)
BookDB.AddBook(3255, {
  "Berard's Journal",
  "Berards Journal",
  "Berard Journal",
})

-- Add more books below using the same format:
-- BookDB.AddBook(ITEM_ID, {"Name1", "Name2", "Variation"}, "Optional first line")

-- Example entries (uncomment and fill in as you add audio files):

-- BookDB.AddBook(2794, {
--   "An Exotic Cookbook",
--   "Exotic Cookbook",
-- })

-- BookDB.AddBook(3898, {
--   "Library Scrip",
--   "A Library Scrip",
-- })

-- BookDB.AddBook(5791, {
--   "A Crumpled Up Note",
--   "Crumpled Up Note",
--   "Crumpled Note",
-- })

-- BookDB.AddBook(6256, {
--   "Fishing for Oily Blackmouth",
-- }, "The Oily Blackmouth is found in the coastal")

-- BookDB.AddBook(2154, {
--   "The Story of Morgan Ladimore",
--   "Morgan Ladimore",
-- })


-------------------------
-- UTILITY FUNCTIONS
-------------------------

-- Get list of all registered books
function BookDB.GetBookList()
  local books = {}
  for name, _ in pairs(BookDB.byName) do
    table.insert(books, name)
  end
  table.sort(books)
  return books
end

-- Check if a book has audio
function BookDB.HasAudio(itemName)
  if BookDB.byName[itemName] then
    return true
  end
  return false
end

-- Print debug info about the database
function BookDB.PrintInfo()
  local count = 0
  for _ in pairs(BookDB.byName) do
    count = count + 1
  end
  
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccBookDB:|r Loaded " .. count .. " books")
  
  if count > 0 and count <= 10 then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccRegistered books:|r")
    for name, file in pairs(BookDB.byName) do
      DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. " -> " .. file)
    end
  end
end