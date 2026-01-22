# CLAUDE.md — AI Coding Assistant Instructions

This file provides context and instructions for AI coding assistants (Claude Code, Cursor, etc.) working on the Grove project.

## Project Overview

**Grove** is a Git-native Markdown editor for macOS. Think "Bear meets Git" — a beautiful, distraction-free writing app that stores files as plain Markdown in a user-chosen folder, with built-in version control.

Read `Grove_PRD.docx` for the full product requirements document.

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (with AppKit integration where needed)
- **Architecture:** MVVM with Combine
- **Minimum Target:** macOS 13.0 (Ventura)
- **Git:** Shell out to `git` CLI (not libgit2)
- **Export:** Bundled Pandoc for DOCX, WebKit for PDF

## Project Structure

```
grove/
├── grove.xcodeproj
├── grove/
│   ├── GroveApp.swift           # App entry point
│   ├── Models/
│   │   ├── Document.swift       # Markdown document model
│   │   ├── FileSystemItem.swift # File tree item model
│   │   ├── Folder.swift         # Folder/workspace model
│   │   └── Settings.swift       # AppSettings (user preferences model)
│   ├── Views/
│   │   ├── ContentView.swift    # Main window layout
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift
│   │   │   └── FileTreeView.swift
│   │   ├── Editor/
│   │   │   ├── EditorView.swift
│   │   │   └── RenderedView.swift
│   │   ├── History/
│   │   │   └── HistoryView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── ViewModels/
│   │   ├── DocumentViewModel.swift
│   │   ├── SidebarViewModel.swift
│   │   └── GitViewModel.swift
│   ├── Services/
│   │   ├── FileService.swift         # File operations, FSEvents
│   │   ├── GitService.swift          # Git CLI wrapper
│   │   ├── MarkdownService.swift     # Parsing, rendering
│   │   ├── ExportService.swift       # PDF, DOCX export
│   │   ├── SecurityScopeManager.swift # Security-scoped bookmark management
│   │   └── SettingsManager.swift     # Settings persistence and sync
│   ├── Utilities/
│   │   ├── KeyboardShortcuts.swift
│   │   └── Shell.swift               # Shell command execution
│   └── Resources/
│       └── Assets.xcassets
└── README.md
```

## Key Implementation Notes

### Markdown Parsing

Use Apple's `swift-markdown` as the base parser. Extend with:
- GFM tables, task lists, strikethrough (cmark-gfm or manual)
- Footnotes
- Math blocks (KaTeX via WKWebView)
- Mermaid diagrams (WKWebView with sandboxed CSP)

```swift
import Markdown

func parseDocument(_ content: String) -> Document {
    return Document(parsing: content)
}
```

### Git Integration

Shell out to git CLI. Do NOT use libgit2 for v1.

```swift
class GitService {
    func commit(message: String, in directory: URL) async throws {
        try await shell("git", "add", ".", in: directory)
        try await shell("git", "commit", "-m", message, in: directory)
    }

    func log(for file: URL) async throws -> [Commit] {
        let output = try await shell("git", "log", "--oneline", "--", file.lastPathComponent, in: file.deletingLastPathComponent())
        // Parse output...
    }
}
```

### Auto-Save

Use Combine's `debounce` for 1-second auto-save:

```swift
textChanges
    .debounce(for: .seconds(1), scheduler: RunLoop.main)
    .sink { [weak self] in self?.saveDocument() }
    .store(in: &cancellables)
```

### Settings Management

`SettingsManager` is a singleton that manages `AppSettings` persistence and syncs with `SecurityScopeManager`:

```swift
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    @Published var settings: AppSettings {
        didSet {
            if !isSyncing { save() }  // Prevent recursion
        }
    }
    
    private func syncRecentFolders() {
        // Check if folders actually changed before updating
        let currentFolders = Set(settings.recentFolders.map { $0.path })
        let newFolders = Set(SecurityScopeManager.shared.accessibleFolders.map { $0.path })
        guard currentFolders != newFolders else { return }
        
        isSyncing = true
        settings.recentFolders = SecurityScopeManager.shared.accessibleFolders
        isSyncing = false
        save()  // Explicit save after sync
    }
}
```

**Critical:** Always use `isSyncing` flag when updating `settings.recentFolders` to prevent infinite recursion between `didSet` → `save()` → `syncRecentFolders()` → `didSet`.

### External File Change Detection

Use `DispatchSource.makeFileSystemObjectSource` or FSEvents:

```swift
func watchFile(_ url: URL) {
    let descriptor = open(url.path, O_EVTONLY)
    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor,
        eventMask: .write,
        queue: .main
    )
    source.setEventHandler { [weak self] in
        self?.handleExternalChange(url)
    }
    source.resume()
}
```

### Image Handling

When user drags/pastes image:
1. Create `./assets/` folder if it doesn't exist
2. Generate unique filename (timestamp or UUID)
3. Copy image to assets folder
4. Insert Markdown: `![](assets/filename.png)`

### Focus Mode

Dim all paragraphs except the one containing the cursor:

```swift
struct FocusModifier: ViewModifier {
    let isFocused: Bool
    let isCurrentParagraph: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isFocused && !isCurrentParagraph ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isCurrentParagraph)
    }
}
```

### Export

**PDF:** Render Markdown to HTML with CSS, then use WKWebView to create PDF:

```swift
func exportToPDF(html: String, to url: URL) async throws {
    let webView = WKWebView()
    webView.loadHTMLString(html, baseURL: nil)
    // Wait for load, then:
    let pdfData = try await webView.pdf()
    try pdfData.write(to: url)
}
```

**DOCX:** Use bundled Pandoc:

```swift
func exportToDocx(markdown: URL, to output: URL) async throws {
    let pandocPath = Bundle.main.path(forResource: "pandoc", ofType: nil, inDirectory: "Pandoc")!
    try await shell(pandocPath, "-o", output.path, markdown.path)
}
```

## Keyboard Shortcuts

Implement using SwiftUI's `.keyboardShortcut()`:

```swift
.keyboardShortcut("1", modifiers: .command)  // Heading 1
.keyboardShortcut("b", modifiers: .command)  // Bold
.keyboardShortcut("p", modifiers: .command)  // Toggle preview
.keyboardShortcut("d", modifiers: .command)  // Toggle focus mode
.keyboardShortcut("s", modifiers: [.command, .shift])  // Save Version (commit)
```

**Note:** For macOS 14.0+, use the new `onChange` API without the closure parameter:
```swift
.onChange(of: value) {
    // Handle change
}
// Not: .onChange(of: value) { _ in ... }
```

## User Preferences

Settings are managed by `SettingsManager` (singleton) and stored in UserDefaults. The model is `AppSettings` (note: renamed from `Settings` to avoid conflict with SwiftUI's `Settings` scene builder).

```swift
struct AppSettings: Codable {
    var defaultView: ViewMode = .rendered  // .raw or .rendered
    var fontFamily: String = "Menlo"
    var fontSize: CGFloat = 14
    var lineHeight: CGFloat = 1.6
    var theme: Theme = .system  // .light, .dark, .system
    var style: EditorStyle = .iaWriter  // .iaWriter, .bear, .standard
    
    // Recent folders stored as bookmark data (URLs aren't Codable)
    private var recentFolderBookmarks: [Data] = []
    var recentFolders: [URL] { get { /* resolve bookmarks */ } set { /* convert to bookmarks */ } }
}
```

**Important:** `SettingsManager` uses an `isSyncing` flag to prevent infinite recursion when syncing `recentFolders` with `SecurityScopeManager`. The sync only updates if folders actually changed, and saves are prevented during sync operations.

Use `SecurityScopeManager` for security-scoped bookmark persistence:

```swift
// SecurityScopeManager handles bookmark storage and access
SecurityScopeManager.shared.persistPermission(for: url)
// SettingsManager syncs recentFolders automatically
```

## Testing Priorities

1. **Document round-trip:** Open → Edit → Save → Reopen preserves content exactly
2. **Git operations:** Commit, log, show work correctly
3. **Auto-save:** Changes persist after 1s debounce
4. **External changes:** Prompt appears when file modified outside app
5. **Export:** PDF and DOCX output are valid and styled correctly

## Performance Targets

- Document open: < 100ms for files under 100KB
- Typing latency: < 16ms (60fps)
- Preview render: < 200ms for full document
- Memory: < 200MB baseline

## Common Pitfalls

1. **Don't use libgit2** — Shell to git CLI is simpler and leverages user's existing config
2. **Don't block main thread** — All file and git operations should be async
3. **Security-scoped bookmarks** — Required for persisting folder access across launches. Use `SecurityScopeManager` to manage bookmarks and `SettingsManager` to sync with settings.
4. **Settings recursion** — `SettingsManager.syncRecentFolders()` must use `isSyncing` flag to prevent infinite recursion when updating `settings.recentFolders`. Always check if folders actually changed before updating.
5. **Naming conflicts** — `AppSettings` struct (not `Settings`) to avoid conflict with SwiftUI's `Settings` scene builder. Use `SwiftUI.Settings { }` for the settings window scene.
6. **SF Symbols** — Use valid SF Symbols only (e.g., `arrow.triangle.branch` not `git.branch`). Check symbol availability before using.
7. **Sandbox considerations** — App should be sandboxed; use proper entitlements for file access
8. **Pandoc bundling** — The macOS arm64 binary is ~30MB; include in app bundle under Resources

## Build & Run

```bash
# Clone the repo
git clone <repo-url>
cd Grove

# Open in Xcode
open grove.xcodeproj

# Build and run
# Or use xcodebuild:
xcodebuild -scheme grove -configuration Debug build
```

## Questions?

If requirements are unclear, refer to `Grove_PRD.docx` or ask before implementing. When in doubt:
- Prioritize simplicity over features
- Match Bear/iA Writer UX patterns
- Keep files portable (standard Markdown, no proprietary extensions)
