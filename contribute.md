# SoundQueue - Voice-Over System for WoW 1.12.1

A lightweight, crash-free sound queue system for managing AI-generated NPC voice-overs in World of Warcraft 1.12.1 (Vanilla).

<img width="370" alt="SoundQueue UI" src="placeholder.png" />

---

## ✨ Features

### 🎵 Core Playback
- **Automatic Queue Management**: NPCs dialogue automatically queues and plays in order
- **Pause/Resume**: Pause at any point and resume from the exact position
- **Skip Controls**: Click to skip current dialogue or remove queued items
- **History System**: Replay the last 50 voice-overs with `/bq play <number>`

### 🎨 UI Features
- **NPC Portraits**: Dynamic portraits based on NPC race and gender
  - Format: `race.tga` or `race_female.tga`
  - Book icon for reading books/letters
  - Fallback question mark for unknown NPCs
- **Queue Display**: See up to 5 upcoming dialogues
- **Live Timer**: Shows remaining seconds for current dialogue
- **Draggable Frame**: Position anywhere on screen (clamped to edges)
- **Close Button**: Hide UI while audio continues playing

### 🎮 Controls
- **Now Playing Area**: Click to skip current dialogue
- **Queue Items**: Click any queued item to remove it
- **Back Button (<<)**: Replay last dialogue from history
- **Pause/Play Button**: Toggle pause/resume (shows proper icons: ⏸️ / ▶️)
- **Close (X)**: Hide frame without stopping playback

---

## 📋 Requirements

### Dependencies
1. **BetterQuest Core**: This SoundQueue requires the main BetterQuest addon
2. **FindDialogSound()**: Function that maps NPC dialogue to audio file paths
3. **Portrait Files**: TGA images in `Interface/AddOns/BetterQuest/Textures/`

### Optional
- **NPC_DATABASE**: Enhanced portrait selection based on NPC metadata
- **GetNPCMetadata()**: Function to look up NPC race/sex for portraits

---

## 🚀 Installation

### 1. Copy Files
```bash
# Place SoundQueue.lua in your addon folder
Interface/AddOns/BetterQuest/SoundQueue.lua
```

### 2. Add Portraits
```bash
# Portrait naming convention:
Interface/AddOns/BetterQuest/Textures/
├── human.tga
├── human_female.tga
├── orc.tga
├── orc_female.tga
├── dwarf.tga
├── dwarf_female.tga
├── nightelf.tga
├── nightelf_female.tga
├── undead.tga
├── undead_female.tga
├── tauren.tga
├── tauren_female.tga
├── gnome.tga
├── gnome_female.tga
├── troll.tga
├── troll_female.tga
├── Book.blp               # For book interactions
├── PortraitFrameAtlas.blp # UI border
├── QuestLogStopButton.blp # Pause icon
└── QuestLogPlayButton.blp # Play icon
```

### 3. Convert Portraits (if needed)
```bash
# Convert PNG to WoW-compatible TGA (256x256, 24-bit)
cd portraits/
for f in *.png; do
    ffmpeg -y -i "$f" -vf "scale=256:256" -pix_fmt rgb24 "${f%.*}.tga"
done
```

### 4. Load in TOC
```
## Interface: 11200
## Title: BetterQuest - SoundQueue
## Dependencies: BetterQuest

SoundQueue.lua
```

---

## 💻 Slash Commands

```
/bq show              - Show the SoundQueue frame
/bq history           - Display last 10 voice-overs
/bq play <number>     - Replay specific history entry (e.g., /bq play 1)
/bq clear             - Clear all history
/bq pause             - Toggle pause/resume
```

---

## 🎨 Portrait System

### How It Works
1. When dialogue plays, SoundQueue gets the NPC name
2. Looks up NPC in `NPC_DATABASE` (if available)
3. Gets `race` and `sex` fields
4. Builds path: `Interface/AddOns/BetterQuest/Textures/{race}_{sex}.tga`
5. Falls back to `{race}.tga` if female version missing
6. Shows question mark if no portrait found

### Example
```lua
-- NPC_DATABASE entry:
NPC_DATABASE["Thassarian"] = {
    race = "human",
    sex = "male",
    narrator = "male_voice_1",
}

-- Portrait path generated:
-- Interface/AddOns/BetterQuest/Textures/human.tga
```

### Book Detection
When reading books or letters (ItemTextFrame shown):
- Automatically shows Book.blp portrait
- No NPC lookup needed

---

## 🔧 Technical Details

### Architecture
- **No Central UpdateUI**: Each function updates only what it needs (prevents re-entrancy crashes)
- **Event-Driven**: Listens to QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, GOSSIP_SHOW
- **Safe Iteration**: Uses numeric loops instead of ipairs() to avoid modification-during-iteration crashes
- **Minimal Dependencies**: ~600 lines, single file, no external libraries

### File Path Format
```
Sound/Dialogs/[race]/[narrator]/[npc_id]_[type].wav

Examples:
Sound/Dialogs/human/male_voice_1/334_quest_accept.wav
Sound/Dialogs/nightelf/female_voice_2/567_gossip.wav
Sound/Dialogs/narrator/default/book_ancient_tome.wav
```

### Queue Structure
```lua
soundData = {
    npcName = "Thassarian",
    text = "The Scourge must be stopped...",
    title = "Quest: The Art of Being a Water Terror",
    filePath = "Sound\\Dialogs\\human\\male_1\\334_quest_accept.wav",
    dialogType = "quest_accept",
    questID = 334,
    duration = 12.5,  -- seconds
    startTime = 0,
    pauseOffset = 0,
}
```

---

## 🐛 Troubleshooting

### NPCs Not Talking?
1. Check `FindDialogSound()` is loaded
2. Verify sound files exist at the path
3. Enable debug: Look for "[SoundQueue]" messages in chat
4. Test manually: `/script SoundQueue:AddSound("TestNPC", "Hello", "Test")`

### Frame Not Showing?
1. `/bq show` to force display
2. Check if dialogue is actually queued: `/bq history`
3. Verify UI initialized: Check for "UI Initialized" in chat

### Portraits Not Loading?
1. Verify TGA files are 256x256, 24-bit RGB
2. Check file paths match exactly (case-sensitive on some systems)
3. Ensure NPC_DATABASE has correct race/sex values
4. Test with a known NPC: Human NPCs should load `human.tga`

### Crashes When Clicking?
This version uses deferred execution and separate update functions - should not crash. If it does:
1. Note exactly what you clicked (queue item, pause, current playing)
2. Check for Lua errors (`/console scriptErrors 1`)
3. Report the issue with steps to reproduce

---

## 🤝 Contributing

### What Would Help

**Portrait Creation**
- More NPC race portraits (high-quality art)
- Unique portraits for named NPCs (optional feature)
- Better book/item icons

**NPC Metadata**
- Fixing incorrect race/sex assignments in NPC_DATABASE
- Adding missing NPCs
- Mapping gossip text to correct speakers

**UI Improvements**
- Classic WoW styling (currently basic)
- Animation effects (fade in/out)
- Resizable frame
- Customizable positioning presets

**Code**
- Support for addon memory (remember frame position)
- Integration with other quest addons
- Performance optimizations

---

## 📝 Implementation Notes

### Why No Central UpdateUI?
Previous versions had a single `UpdateUI()` function that updated everything. This caused:
- **Re-entrancy crashes**: Button clicks trying to update the button's own frame
- **Infinite loops**: UpdateUI calling functions that call UpdateUI
- **Race conditions**: State changes during UI updates

**Solution**: Each action updates only its specific UI elements:
```lua
PlaySound() → Updates: portrait, name, title, pause button, status, queue
TogglePause() → Updates: pause button, status text
RemoveSound() → Updates: queue list (or plays next)
```

### Safe Queue Iteration
```lua
-- WRONG (crashes when removing):
for i, sound in ipairs(self.sounds) do
    table.remove(self.sounds, i)
end

-- CORRECT:
for i = 1, table.getn(self.sounds) do
    if self.sounds[i] == target then
        removedIndex = i
        break
    end
end
table.remove(self.sounds, removedIndex)
```

---

## 📊 Performance

- **Memory**: ~50KB base + portrait textures
- **CPU**: Minimal (OnUpdate only runs while playing)
- **Frame Rate**: No noticeable impact
- **Load Time**: <100ms

---

## 🎯 Roadmap

- [ ] Settings panel (frame scale, position, auto-hide)
- [ ] Volume controls per NPC type
- [ ] Subtitle display below portrait
- [ ] Custom portrait overrides
- [ ] Integration with WeakAuras
- [ ] Export/import settings

---

## 📄 License

Part of the BetterQuest addon. See main project for license details.

---

## ❤️ Credits

**Created for BetterQuest**
- Main project: [BetterQuest](#)
- Voice generation: Chatterbox AI model
- Inspired by: Mr. Thingers' original voice-over work

**Special Thanks**
- pfUI team for UI framework inspiration
- WoW 1.12.1 modding community
- Everyone testing and reporting bugs

---

## 💬 Support

Found this helpful? Consider supporting the main BetterQuest project:
- ☕ [Ko-fi/tlplayer](https://ko-fi.com/tlplayer)

---

## 🔗 Links

- **Main Project**: BetterQuest
- **Voice Generation**: See BetterQuest README for AI setup
- **Portrait Creation**: See `portraits/` folder in main project
- **Database Extraction**: See `extraction/` folder for NPC metadata tools

---

*Last Updated: January 2026*
*Compatible with: WoW 1.12.1 (Vanilla)*
*Status: Stable - Production Ready*