-- Book.lua
-- Voiceover system for books, notes, and letters
-- Integrates with BetterQuest SoundQueue

-------------------------
-- CONFIGURATION
-------------------------

local BOOK_CONFIG = {
    ENABLED = true,
    DEBUG = true,

    SOUND_PATH = "Interface\\AddOns\\BetterQuest\\Sounds\\books\\",
    NARRATOR = "Narrator",

    MIN_FUZZY_SCORE = 70,
}

-------------------------
-- DATABASE
-------------------------

BookDB = BookDB or {}

-------------------------
-- UTILS
-------------------------

local function Debug(msg)
    if BOOK_CONFIG.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[BookVO]|r " .. msg)
    end
end

local function Normalize(text)
    if not text then return "" end
    text = string.lower(text)
    text = string.gsub(text, "[%p%c]", "")
    text = string.gsub(text, "%s+", " ")
    return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local function Levenshtein(a, b)
    local lenA, lenB = string.len(a), string.len(b)
    if lenA == 0 then return lenB end
    if lenB == 0 then return lenA end

    local matrix = {}
    for i = 0, lenA do
        matrix[i] = {[0] = i}
    end
    for j = 0, lenB do
        matrix[0][j] = j
    end

    for i = 1, lenA do
        for j = 1, lenB do
            local cost = (a:sub(i,i) == b:sub(j,j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
        end
    end

    return matrix[lenA][lenB]
end

local function FuzzyScore(a, b)
    a, b = Normalize(a), Normalize(b)
    if a == b then return 100 end
    if a == "" or b == "" then return 0 end

    if string.find(a, b, 1, true) or string.find(b, a, 1, true) then
        return 85
    end

    local maxLen = math.max(string.len(a), string.len(b))
    return math.floor(100 * (1 - Levenshtein(a, b) / maxLen))
end

-------------------------
-- BOOK IDENTIFICATION
-------------------------

local function GetBookInfo()
    if not ItemTextFrame or not ItemTextFrame:IsVisible() then
        return nil
    end

    return {
        name = ItemTextGetItem(),
        text = ItemTextGetText() or "",
        page = ItemTextGetPage() or 1,
    }
end

-------------------------
-- AUDIO LOOKUP
-------------------------

local function FindBookAudio(book)
    if not book then return nil end

    Debug("Searching audio for: " .. (book.name or "Unknown"))

    -- Exact name
    if BookDB.byName and book.name and BookDB.byName[book.name] then
        return BookDB.byName[book.name]
    end

    -- Fuzzy name
    if BookDB.fuzzyList and book.name then
        local bestScore, bestFile = 0, nil
        for name, file in pairs(BookDB.fuzzyList) do
            local score = FuzzyScore(book.name, name)
            if score > bestScore and score >= BOOK_CONFIG.MIN_FUZZY_SCORE then
                bestScore = score
                bestFile = file
            end
        end
        if bestFile then
            Debug("Fuzzy match (" .. bestScore .. "%)")
            return bestFile
        end
    end

    -- First line
    if BookDB.byFirstLine and book.text then
        local firstLine = book.text:match("^([^\n]+)")
        if firstLine then
            return BookDB.byFirstLine[Normalize(firstLine)]
        end
    end

    return nil
end

-------------------------
-- PORTRAIT
-------------------------

local function ShowBookPortrait()
    if not QuestFrame or not QuestFrame.widePortrait then return end

    local portrait = QuestFrame.widePortrait
    portrait.texture:SetTexture(
        "Interface\\AddOns\\BetterQuest\\Portraits\\books\\narrator.tga"
    )
    portrait:Show()
end

local function HideBookPortrait()
    if QuestFrame and QuestFrame.widePortrait then
        QuestFrame.widePortrait:Hide()
    end
end

-------------------------
-- SOUNDQUEUE INTEGRATION
-------------------------

local function PlayBookAudio(audioFile, book)
    if not SoundQueue or not BOOK_CONFIG.ENABLED then return end

    local soundPath = BOOK_CONFIG.SOUND_PATH .. audioFile

    SoundQueue:Enqueue({
        soundFile  = soundPath,
        speaker    = BOOK_CONFIG.NARRATOR,
        npc_name   = BOOK_CONFIG.NARRATOR,
        portrait   = nil,
        dialog_type = "book",
        text       = book.name or "Book",
    })

    Debug("Queued book audio: " .. audioFile)
end

local function StopBookAudio()
    if SoundQueue then
        SoundQueue:Clear()
    end
end

-------------------------
-- EVENT HANDLERS
-------------------------

local function OnBookOpenOrPage()
    local book = GetBookInfo()

    if not book then
        StopBookAudio()
        HideBookPortrait()
        return
    end

    ShowBookPortrait()

    local audioFile = FindBookAudio(book)
    if audioFile then
        StopBookAudio()
        PlayBookAudio(audioFile, book)
    else
        Debug("No audio found for book")
    end
end

local function OnBookClose()
    StopBookAudio()
    HideBookPortrait()
end

-------------------------
-- INIT
-------------------------

local frame = CreateFrame("Frame")

frame:RegisterEvent("ITEM_TEXT_BEGIN")
frame:RegisterEvent("ITEM_TEXT_READY")
frame:RegisterEvent("ITEM_TEXT_TRANSLATION")
frame:RegisterEvent("ITEM_TEXT_CLOSED")

frame:SetScript("OnEvent", function()
    if event == "ITEM_TEXT_CLOSED" then
        OnBookClose()
    else
        -- Delay one frame so ItemText APIs are populated
        this:SetScript("OnUpdate", function()
            OnBookOpenOrPage()
            this:SetScript("OnUpdate", nil)
        end)
    end
end)

-------------------------
-- SLASH COMMAND
-------------------------

SLASH_BOOKVO1 = "/bookvo"
SlashCmdList["BOOKVO"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "on" then
        BOOK_CONFIG.ENABLED = true
        print("Book VO enabled")
    elseif msg == "off" then
        BOOK_CONFIG.ENABLED = false
        StopBookAudio()
        print("Book VO disabled")
    elseif msg == "stop" then
        StopBookAudio()
    elseif msg == "debug" then
        BOOK_CONFIG.DEBUG = not BOOK_CONFIG.DEBUG
        print("Book VO debug: " .. (BOOK_CONFIG.DEBUG and "ON" or "OFF"))
    else
        print("/bookvo on | off | stop | debug")
    end
end
