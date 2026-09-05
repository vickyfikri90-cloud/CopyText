# CopyText

**macOS menu bar app — screenshot to clipboard via native OCR, optional Gemini JSON extraction.**

100% Swift. CopyText mode is fully on-device. Extract JSON sends screenshots to Google Gemini cloud.

## Download (no Xcode needed)

Get the latest **CopyText.app** from [GitHub Releases](https://github.com/vickyfikri90-cloud/CopyText/releases/latest).

1. Download **`CopyText-macOS.zip`**
2. Double-click to unzip → you get **`CopyText.app`**
3. Drag **`CopyText.app`** to **Applications** (optional)
4. Open **`CopyText.app`**
   - First launch: if macOS blocks it, **right-click → Open → Open** (app is not notarized)
5. Look for the hexagon icon in the menu bar (top-right)

No build tools required.

## How to use

### CopyText (local, default)

1. **Single-click** the menu bar icon
2. Take a screenshot with **⌘⇧4** (must copy to clipboard)
3. Paste with **⌘V**

Uses native Vision OCR — no cloud, no API keys.

### Extract JSON (cloud)

1. Right-click icon → **Extract JSON Settings…**
2. Paste your **Gemini API key**, pick a model, edit prompt if needed
3. Optional: add **fallback API keys** (one per line) for when primary hits rate limit
4. **Double-click** the menu bar icon → icon shows **sparkles** while waiting
5. Take a screenshot with **⌘⇧4**
6. Paste JSON with **⌘V**

Screenshot is uploaded to Google Gemini for vision + JSON extraction. No local OCR in this mode.

### Third call (optional, cloud)

1. In settings, enable **Enable third call mode**
2. Set a separate **Third call prompt**
3. **Double-click** icon → Extract JSON waiting (**sparkles**)
4. **Click once more** while waiting → switches to third call (**square.grid.2x2** icon)
5. Screenshot → paste JSON (uses third-call prompt)

Click again while waiting = cancel.

## Menu bar clicks

| Click | Mode |
|-------|------|
| Single-click (from idle) | CopyText — local OCR |
| Double-click (from idle) | Extract JSON — Gemini cloud |
| +1 click (while Extract JSON waiting) | Third call — Gemini cloud, custom prompt |

Right-click icon for settings, burst mode, dev log, quit.

## Features

- **CopyText** — local Vision OCR + line-break normalization
- **Extract JSON** — Gemini vision API, configurable model & prompt
- **Third call** — alternate Gemini prompt, toggled while waiting
- **Fallback API keys** — auto-retry when primary key is rate-limited
- **Burst mode** — right-click → Start for 1 Min (CopyText only, local)
- **Dev Mode** — chronological processing log window
- **Launch at Login** — optional

## Build from source (developers)

```bash
open "CopyText.xcodeproj"
```

Or from terminal:

```bash
xcodebuild -project CopyText.xcodeproj -scheme CopyText -configuration Release \
  -derivedDataPath /tmp/CopyText-build CODE_SIGN_IDENTITY="-" build
ditto /tmp/CopyText-build/Build/Products/Release/CopyText.app dist/CopyText.app
open dist/CopyText.app
```

Requires **macOS 13+** and **Xcode 16+**.

## Project structure

```
CopyText/
├── AppController.swift         # State machine + pipeline orchestration
├── StatusBarController.swift   # Menu bar icon + click handling
├── OCRService.swift            # Vision text recognition (CopyText mode)
├── GeminiClient.swift          # Gemini vision API (Extract JSON mode)
├── GeminiSettings.swift        # API key, model, prompt settings
├── ExtractJSONSettingsView.swift
├── TextNormalizer.swift        # Line-break merging
└── ...
```

→ [About](about_CopyText_MacApp.md) · [MVP plan](plan_CopyText_MVP.md)
