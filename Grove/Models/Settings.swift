import Foundation

enum ViewMode: String, Codable {
    case raw
    case rendered
}

enum Theme: String, Codable {
    case light
    case dark
    case system
}

struct Settings: Codable {
    var defaultView: ViewMode = .rendered
    var fontFamily: String = "Menlo"
    var fontSize: CGFloat = 14
    var lineHeight: CGFloat = 1.6
    var theme: Theme = .system
    var recentFolders: [URL] = []
}
