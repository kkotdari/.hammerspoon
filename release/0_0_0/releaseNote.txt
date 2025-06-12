# Project: Hammerspoon Toolkit
# Version: 0.0.0
# Date: 2025/06/11

────────────────────────────────────────────
1. init.lua
────────────────────────────────────────────
- Initializes the Hammerspoon environment.
- Loads all modules in the correct order.

────────────────────────────────────────────
2. configs/stores.lua
────────────────────────────────────────────
- Declares shared global state:
  • pointingsOn — true if pointing-mode is active.
  • allWindowHotkeys — list of hotkeys from windows.lua.
  • allPointingHotkeys — list of hotkeys from pointings.lua.
- Provides:
  • toggleHotkeys(hotkeyList, enabled)
    → Enables or disables given hotkeys.

────────────────────────────────────────────
3. interceptors/keys.lua
────────────────────────────────────────────
- Logs key presses and modifier flags.

────────────────────────────────────────────
4. modules/capture.lua
────────────────────────────────────────────
HOTKEYS:
- F13  → Drag-area capture (crosshair cursor)
- F14  → Window picker capture
- F15  → Fullscreen capture
- Cmd+Ctrl+F15 → Capture all displays

PREVIEW PANE:
- Shows rounded preview with drop-shadow.
- ESC cancels any capture.
- 'r' recaptures last region.

PREVIEW KEYBINDINGS:
- c → Copy to clipboard
- s → Save to ~/Documents/screenshots/
- a → Copy + Save
- e → Open in external editor
- Esc → Dismiss

OTHER FEATURES:
- Timestamped PNGs: YYYYMMDDHHMMSS.png
- Creates screenshots folder if missing
- Full-resolution saved even if scaled preview

────────────────────────────────────────────
5. modules/pointings.lua
────────────────────────────────────────────
- NumLock toggles pointing-mode.

WHILE POINTING-MODE IS ACTIVE:
- Numpad 8/5/4/6 → move cursor
- Cmd+Ctrl + move → drag
- Numpad //*/-/+ → scroll
- Numpad 0 → teleport to coordinate
- Numpad 7/9 → left/right click

- Disables window-mode hotkeys during active mode.
- Offers enablePointingHotkeys / disablePointingHotkeys.

────────────────────────────────────────────
6. modules/windows.lua
────────────────────────────────────────────
HOTKEYS (Cmd+Ctrl + Numpad):
- 4 / 6 → left/right edge → width cycle:
  ¾ → ⅔ → ½ → ⅓ → ¼
- 8 / 2 → top/bottom half height → width:
  full → ⅓ → ¼
- 7/9/1/3 → corners, same width cycle
- 5 → center toggle
- Return → fullscreen toggle
- Backspace → reset window
- [ / ] → move window to another display

NOTES:
- Each hotkey has its own cycle index.
- Switching resets all others to index 1.

────────────────────────────────────────────
7. utils/indicators.lua
────────────────────────────────────────────
- showIndicator(name, text)
- clearIndicator(name)
- showTemporaryIndicator(name, text, duration)

────────────────────────────────────────────
8. utils/toasts.lua
────────────────────────────────────────────
- showToast(text, duration)

FEATURES:
- Immediate display (no waiting)
- New toast pushes existing ones downward
- Independent canvas per toast
- Glassmorphism style:
  • Rounded white background
  • Soft drop shadow
  • Subtle reflection
- Auto font-size:
  • Scales between 4–40pt to fit 50px height
- Each toast has its own timer (hold + fade)
- Duration customizable (e.g., 2.5 seconds)

────────────────────────────────────────────