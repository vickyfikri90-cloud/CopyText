# CopyText

**macOS menu bar app — screenshot to clipboard via native OCR, optional Gemini JSON extraction.**

100% Swift. CopyText mode is fully on-device. Extract JSON sends screenshots to Google Gemini cloud.

## Open in Xcode

```bash
open "CopyText.xcodeproj"
```

## Build & Run

1. Open the project in Xcode
2. Select the **CopyText** scheme
3. Press **⌘R**

Or from terminal (outputs `dist/CopyText.app`):

```bash
cd "VibeCodeProjects/2026 CopyText"
xcodebuild -project CopyText.xcodeproj -scheme CopyText -configuration Release \
  -derivedDataPath /tmp/CopyText-build CODE_SIGN_IDENTITY="-" build
ditto /tmp/CopyText-build/Build/Products/Release/CopyText.app dist/CopyText.app
open dist/CopyText.app
```

## How to use

### CopyText (local, default)

1. **Single-click** the menu bar icon
2. Take a screenshot with **⌘⇧4** (must copy to clipboard)
3. Paste with **⌘V**

Uses native Vision OCR — no cloud, no API keys.

### Extract JSON (cloud)

1. Right-click icon → **Extract JSON Settings…**
2. Paste your Gemini API key, pick a model, edit prompt if needed
3. **Double-click** the menu bar icon
4. Take a screenshot with **⌘⇧4**
5. Paste JSON with **⌘V**

Screenshot is uploaded to Google Gemini for vision + JSON extraction. No local OCR in this mode.

## Features

- **CopyText** — local Vision OCR + line-break normalization
- **Extract JSON** — Gemini vision API, configurable model & prompt
- **Burst mode** — right-click → Start for 1 Min (CopyText only, local)
- **Dev Mode** — chronological processing log window
- **Launch at Login** — optional

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
