import Foundation

enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case raw
    case rendered
    
    var id: String { rawValue }
    var label: String {
        switch self {
        case .raw: return "Raw Markdown"
        case .rendered: return "Preview"
        }
    }
}

enum Theme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum EditorStyle: String, Codable, CaseIterable, Identifiable {
    case iaWriter
    case bear
    case standard
    
    var id: String { rawValue }
    var label: String {
        switch self {
        case .iaWriter: return "Focus (iA Style)"
        case .bear: return "Modern (Bear Style)"
        case .standard: return "Standard"
        }
    }
}

struct AppSettings: Codable {
    var defaultView: ViewMode = .rendered
    var fontFamily: String = "Menlo"
    var fontSize: CGFloat = 14
    var lineHeight: CGFloat = 1.6
    var theme: Theme = .system
    var style: EditorStyle = .iaWriter
    
    // Store bookmark data instead of URLs since URLs aren't Codable
    // These are synced with SecurityScopeManager
    private var recentFolderBookmarks: [Data] = []
    
    // Computed property to get URLs from bookmarks
    // SettingsManager handles the actual resolution and security scope management
    var recentFolders: [URL] {
        get {
            return recentFolderBookmarks.compactMap { bookmarkData in
                var isStale = false
                do {
                    return try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                } catch {
                    return nil
                }
            }
        }
        set {
            // Convert URLs to bookmark data
            recentFolderBookmarks = newValue.compactMap { url in
                try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case defaultView
        case fontFamily
        case fontSize
        case lineHeight
        case theme
        case style
        case recentFolderBookmarks
    }
}
