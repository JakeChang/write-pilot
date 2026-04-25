# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
xcodebuild -scheme Write-Pilot -configuration Debug build
```

Xcode 26.3, macOS 15.7 deployment target, Swift 5.0. One SPM dependency: **Sparkle** (auto-updates). Ad-hoc code signing (`CODE_SIGN_IDENTITY = "-"`), no development team — first launch may require `xattr -cr`.

The project uses `PBXFileSystemSynchronizedRootGroup` — adding `.swift` files to disk auto-includes them in the build. No manual pbxproj edits needed for new source files.

## CI/CD

GitHub Actions release workflow (`.github/workflows/release.yml`): triggered on `v*.*.*` tag pushes. Builds universal binary (arm64 + x86_64) on `macos-15`, creates DMG via `create-dmg`, signs with Sparkle EdDSA, deploys `appcast.xml` + `index.html` to GitHub Pages.

## Testing

No test target exists.

## Architecture

Three-column macOS writing app (file tree | markdown editor | AI assistant panel) built with SwiftUI + NSTextView.

### Concurrency Model

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor`. Services needing background work use `actor` (AIService) or `nonisolated`. Computed properties accessed from actors must be marked `nonisolated`.

### State Management

Uses `@Observable` (not ObservableObject). Services injected via `.environment()`. Chat/reader/detect states are `@Observable` classes held by `AIPanelView` via `@State` to survive tab switches.

### Key Data Flow

- `WritePilotApp` owns `FileService` and `DailyWordCountService` as `@State`; `AIService` is a plain `let` (actor, not `@State`)
- `ContentView` owns `EditorState`, `SourceTracker`, `openFiles: [OpenFile]` (tab model), and `activeFile: OpenFile?`
- `EditorState.pendingAIPrompt` / `switchToAIMode` — floating menu → AI panel communication
- `FileService` passed via `.environment()`, `AIService` passed as parameter
- When AI text is applied via `onApplyText`, it is counted as "pasted" in `SourceTracker` and tracked in `DailyWordCountService`

### Editor (NSTextView)

`MarkdownTextView` wraps NSTextView via `NSViewRepresentable`. Critical patterns:
- **IME support**: `guard !textView.hasMarkedText()` in `updateNSView` prevents breaking CJK input
- **Sync loop prevention**: `lastSyncedText` tracks what was written to the binding; `updateNSView` only overwrites when `text != lastSyncedText` (external change)
- **Source tracking**: `shouldChangeTextIn:replacementString:` detects typed (1 char) vs pasted (>1 chars), counting only non-whitespace characters
- **Syntax highlighting**: `MarkdownHighlighter` applies highlighting to `NSTextStorage` — incremental on edits (edited range only), full-document on initial load and external reloads

### File Watching

`DispatchSource.makeFileSystemObjectSource` with `suppressWatcher` flag. All CRUD methods set `suppressWatcher = true` before filesystem operations to prevent false "external change" alerts. External changes debounce at 0.3s before triggering `rescan()`.

`FileService.rescan()` has two paths: if `rootNode` exists, `updateNode()` diffs in-place (preserving `FileNode` identity and expansion state); if nil, `scanDirectory()` builds fresh.

### AI Integration

Google AI Gemma 4 31B (`gemma-4-31b-it`) via `generativelanguage.googleapis.com/v1beta`. Actor-based service with SSE streaming. Streaming responses filter out `thought: true` parts.

API key stored in UserDefaults via `KeychainService` (misnamed — it's a UserDefaults wrapper, not actual Keychain, to avoid password prompts during development).

### Persistence

- `.md` files: direct filesystem read/write
- `.md.source` files: JSON sidecar with typed/pasted char counts
- `.writepilot` files: JSON plan metadata per folder
- Both `.source` and `.writepilot` are filtered from file tree display in `scanDirectory` and `updateNode`
- Workspace path: security-scoped bookmark in UserDefaults

### Auto-Save

`AutoSaveService` debounces at 1.5 seconds per keystroke — cancels previous task before scheduling. Also persists `SourceTracker` data to `.source` sidecar on each save.

### Menu Bar Word Count

`AppDelegate` manages an `NSStatusItem` + `NSPopover` showing daily word count via `MenuBarWordCountView`. A `MenuBarBridge` (`@Observable`) connects `AppDelegate` to SwiftUI. The status item label uses `withObservationTracking` to reactively update when `DailyWordCountService.todayCount` changes.

### Sparkle Auto-Updates

`SPUStandardUpdaterController` created in `WritePilotApp`, passed to `SettingsView` for the update tab.

### View Communication

Three mechanisms beyond `@Observable` bindings:
- **`EditorState` bridge**: `pendingAIPrompt`, `switchToAIMode`, `showFloatingMenu` + `floatingMenuPosition`
- **`Notification.Name` posts**: `.toggleSourceView`, `.openAISuggest`, `.switchAIMode` — fired by keyboard shortcuts in `WritePilotCommands`
- **Callback closures**: `onTextChange`, `onCursorChange`, `onSelectionChange` in `MarkdownTextView`; `onApply` in AI views to push text back to the editor

### Markdown Preview

WKWebView-based (`NSViewRepresentable`), custom markdown→HTML conversion with dark-mode-aware CSS. Not a SwiftUI native view.

### Image Drag & Drop

Dropping images into the editor copies files to `workspace/images/` and inserts `\n![](images/filename)\n` (newline-wrapped). Supported formats: png, jpg, jpeg, gif, webp.

### Plan/Outline Parsing

`PlanService.parseOutline()` reads markdown conventions: `# ` = title (first occurrence only), `## ` = chapter, any non-empty non-header line after a chapter header = writing prompt (indentation not required, lines are trimmed). Chapter file generation skips files that already exist. Filenames sanitize `：` (fullwidth colon), `:`, `/`, and spaces.

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
