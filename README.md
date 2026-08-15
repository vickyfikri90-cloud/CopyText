# CopyText

100% Swift macOS menu bar app — screenshot → native OCR → clipboard.

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

1. Click the CopyText icon in the menu bar
2. Click **Start**
3. Take a screenshot with **⌘⇧4** (must copy to clipboard)
4. Paste with **⌘V**

## Features

- Native Vision OCR — no cloud, no API keys
- **AI Mode** — optional Apple Intelligence cleanup (supported Macs only)
- **Dev Mode** — chronological processing log window
- **Launch at Login** — optional
- State-driven menu bar icon: idle → waiting → processing → success/failure

## Project structure

```
CopyText/
├── CopyTextApp.swift       # App entry + MenuBarExtra
├── AppController.swift     # State machine + pipeline orchestration
├── AppState.swift          # WorkflowState enum
├── ClipboardWatcher.swift  # Poll clipboard for screenshots
├── OCRService.swift        # Vision text recognition
├── AICleaner.swift         # Foundation Models cleanup
├── EventLog.swift          # Dev log + file mirror
├── DevLogWindow.swift      # Log viewer window
├── MenuContentView.swift   # Menu bar dropdown
└── MenuBarIconView.swift   # Icon per state
```

→ [[about_CopyText_MacApp]] · [[plan_CopyText_MVP]]
