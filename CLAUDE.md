# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
xcodebuild -scheme Write-Pilot -configuration Debug build
```

No SPM dependencies. Xcode 26.3, macOS 15.7 deployment target, Swift 5.0.

The project uses `PBXFileSystemSynchronizedRootGroup` — adding `.swift` files to disk auto-includes them in the build. No manual pbxproj edits needed for new source files.

## Architecture

Three-column macOS writing app (file tree | markdown editor | AI assistant panel) built with SwiftUI + NSTextView.

### Concurrency Model

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor`. Services needing background work use `actor` (AIService) or `nonisolated`. Computed properties accessed from actors must be marked `nonisolated`.

### State Management

Uses `@Observable` (not ObservableObject). Services injected via `.environment()`. Chat/reader/detect states are `@Observable` classes held by `AIPanelView` via `@State` to survive tab switches.

### Key Data Flow

- `ContentView` owns `EditorState` (shared selection state) and `SourceTracker`
- `EditorState.pendingAIPrompt` / `switchToAIMode` — floating menu → AI panel communication
- `FileService` passed via `.environment()`, `AIService` passed as parameter

### Editor (NSTextView)

`MarkdownTextView` wraps NSTextView via `NSViewRepresentable`. Critical patterns:
- **IME support**: `guard !textView.hasMarkedText()` in `updateNSView` prevents breaking CJK input
- **Sync loop prevention**: `lastSyncedText` tracks what was written to the binding; `updateNSView` only overwrites when `text != lastSyncedText` (external change)
- **Source tracking**: `shouldChangeTextIn:replacementString:` detects typed (1 char) vs pasted (>1 chars), counting only non-whitespace characters

### File Watching

`DispatchSource.makeFileSystemObjectSource` with `suppressWatcher` flag. All CRUD methods set `suppressWatcher = true` before filesystem operations to prevent false "external change" alerts.

### AI Integration

Google AI Gemma 4 31B via `generativelanguage.googleapis.com/v1beta`. Actor-based service with SSE streaming. API key stored in UserDefaults (not Keychain, to avoid password prompts during development). Streaming responses filter out `thought: true` parts.

### Persistence

- `.md` files: direct filesystem read/write
- `.md.source` files: JSON sidecar with typed/pasted char counts
- `.writepilot` files: JSON plan metadata per folder
- Both `.source` and `.writepilot` are filtered from file tree display in `scanDirectory`
- Workspace path: security-scoped bookmark in UserDefaults

### Auto-Save

`AutoSaveService` debounces at 1.5 seconds per keystroke — cancels previous task before scheduling. Also persists `SourceTracker` data to `.source` sidecar on each save.

### View Communication

Three mechanisms beyond `@Observable` bindings:
- **`EditorState` bridge**: `pendingAIPrompt`, `switchToAIMode`, `showFloatingMenu` + `floatingMenuPosition`
- **`Notification.Name` posts**: `.toggleSourceView`, `.openAISuggest`, `.switchAIMode` — fired by keyboard shortcuts in `WritePilotCommands`
- **Callback closures**: `onTextChange`, `onCursorChange`, `onSelectionChange` in `MarkdownTextView`; `onApply` in AI views to push text back to the editor

### Markdown Preview

WKWebView-based (`NSViewRepresentable`), custom markdown→HTML conversion with dark-mode-aware CSS. Not a SwiftUI native view.

### Image Drag & Drop

Dropping images into the editor copies files to `workspace/images/` and inserts `![](images/filename)` markdown.

### Plan/Outline Parsing

`PlanService.parseOutline()` reads markdown conventions: `# ` = title, `## ` = chapter, indented lines = writing prompts. Chapter file generation skips files that already exist.

## Testing

No test target exists. No CI configuration.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+S | Save |
| Cmd+Shift+O | Open workspace |
| Cmd+Shift+L | Toggle source view |
| Cmd+Shift+A | Open AI suggest |
| Cmd+Shift+P | Toggle preview |
| Cmd+1/2/3 | Switch AI mode (assist/reader/source) |

## UI Language

All UI strings, error messages, and AI system prompts use Traditional Chinese (繁體中文). Strings are hardcoded (no `.strings` localization files).
