# Write Pilot

[English](#english) | [繁體中文](#繁體中文)

---

## English

> A native macOS writing tool with Markdown editor, file management, and AI writing assistant

Built with **SwiftUI + NSTextView**, a three-column writing environment designed for writers.

### Features

* **Markdown Editor** — NSTextView-based with syntax highlighting, live preview, and full CJK IME support
* **File Tree** — Workspace folder browser with create, rename, and delete operations
* **AI Writing Assistant** — Powered by Google Gemma 4, with writing suggestions, content analysis, and source detection modes
* **Markdown Preview** — WKWebView live rendering with dark mode support
* **Outline & Planning** — Auto-generate chapter file structures from Markdown outlines
* **Image Drag & Drop** — Drop images to auto-copy to `images/` and insert Markdown syntax
* **Writing Stats** — Menu Bar daily word count, distinguishing typed vs. pasted characters
* **Auto Save** — 1.5s debounced auto-save with source tracking sidecar
* **Auto Update** — Built-in Sparkle update checker

### Download

Go to [Releases](https://github.com/JakeChang/write-pilot/releases/latest) to download the latest DMG.

On first launch, run:

```
xattr -cr /Applications/Write-Pilot.app
```

### Development

1. Clone the repo and open `Write-Pilot.xcodeproj` in Xcode
2. Select the **Write-Pilot** scheme and press `Cmd+R` to run

**Requirements:** Xcode 26.3, macOS 15.7+, Swift 5.0

### License

MIT

---

## 繁體中文

> macOS 原生寫作工具，整合 Markdown 編輯器、檔案管理與 AI 寫作助手

基於 **SwiftUI + NSTextView** 打造，專為中文寫作者設計的三欄式寫作環境。

## 功能

* **Markdown 編輯器** — NSTextView 核心，語法高亮、即時預覽，CJK 輸入法完整支援
* **檔案樹管理** — 工作區資料夾瀏覽，支援新增、重新命名、刪除檔案與資料夾
* **AI 寫作助手** — 整合 Google Gemma 4，支援寫作建議、內容分析、來源偵測三種模式
* **Markdown 預覽** — WKWebView 即時渲染，支援深色模式
* **大綱與計畫** — 從 Markdown 大綱自動生成章節檔案結構
* **圖片拖放** — 拖入圖片自動複製至 `images/` 並插入 Markdown 語法
* **寫作統計** — Menu Bar 即時顯示每日字數，區分手打與貼上字數
* **自動儲存** — 1.5 秒防抖自動存檔，搭配來源追蹤 sidecar
* **自動更新** — 內建 Sparkle 更新檢查

## 下載

前往 [Releases](https://github.com/JakeChang/write-pilot/releases/latest) 下載最新版 DMG。

首次安裝需執行：

```
xattr -cr /Applications/Write-Pilot.app
```

## 開發

1. Clone 專案後，用 Xcode 開啟 `Write-Pilot.xcodeproj`
2. 選擇 Scheme **Write-Pilot**，按 `Cmd+R` 即可執行

**需求：** Xcode 26.3、macOS 15.7+、Swift 5.0

## License

MIT
