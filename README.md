# Claude Context Window Widget

A lightweight always-on-top widget for Windows that displays your Claude context window usage in real time.

![Widget preview — dark floating panel showing 73% usage with a progress bar]

---

## Features

- **Live token counter** — updates every 0.8 seconds from your local Claude session files
- **Color-coded progress bar** — green → orange → red as the context fills up
- **Follows Claude** — anchors to the bottom-right corner of Claude Desktop, Antigravity IDE, or VS Code / Cursor with Claude Code
- **Minimizable** — collapse to a tiny pill showing only the percentage
- **Draggable** — move it anywhere on screen
- **Zero cloud, zero telemetry** — reads only local files in `~/.claude/projects/`

---

## Requirements

| Tool | Version | Link |
|------|---------|------|
| Windows | 10 / 11 | — |
| AutoHotkey | v2 | https://www.autohotkey.com/ |
| Node.js | 18+ | https://nodejs.org/ |

---

## Quick Start

1. Install **AutoHotkey v2** and **Node.js** if you haven't already
2. Double-click **`הפעלה.bat`** (or `launcher.vbs` for a silent start with no console window)
3. The widget appears in the bottom-right corner of your Claude window

> **Auto-start with Windows:** double-click `התקן_אוטוסטרט.bat` — it creates a Startup shortcut automatically.

---

## Widget Controls

| Button | Action |
|--------|--------|
| `R` | Refresh — re-read the active session file immediately |
| `-` | Minimize — collapse to compact pill mode |
| `x` | Close — hide the widget (still runs in background) |

**System tray** (right-click the AHK icon near the clock):
`Show / Hide` · `Refresh` · `Reset` · `Exit`

**To restore after closing:** right-click tray icon → **Show / Hide**

---

## Progress Bar Colors

| Color | Range | Meaning |
|-------|-------|---------|
| 🟢 Green | 0 – 59% | Plenty of context remaining |
| 🟠 Orange | 60 – 81% | Context half-used |
| 🔴 Red | 82 – 100% | Approaching limit — consider starting a new conversation |

---

## How It Works

`watcher.js` (Node.js) scans `~/.claude/projects/` for the most recently modified `.jsonl` session file, reads the last few KB, and extracts the latest token usage from the `usage` field in the conversation log. It writes the result to a small temp file (`%TEMP%\claude_tokens.json`).

`claude_token_widget.ahk` (AutoHotkey v2) polls that temp file every 0.9 seconds and renders the UI.

Token count = `input_tokens` + `cache_creation_input_tokens` + `cache_read_input_tokens`  
Maximum = 200,000 (Claude 3.x / 4.x)

---

## Security

- `watcher.js` resolves symlinks with `fs.realpathSync` and verifies all paths stay inside `~/.claude/projects/` (no path-traversal escapes)
- Symlinked files and directories are skipped during scanning
- Files larger than 50 MB are skipped
- No network requests, no external dependencies

---

## File Structure

```
claude_token_widget/
├── claude_token_widget.ahk   # Widget UI (AutoHotkey v2)
├── watcher.js                # Token reader (Node.js)
├── launcher.vbs              # Silent launcher (no console window)
├── הפעלה.bat                 # One-click start
├── התקן_אוטוסטרט.bat         # Install Windows Startup shortcut
└── הוראות.txt                # Instructions (Hebrew)
```

---

## License

MIT — free to use, modify, and distribute.
