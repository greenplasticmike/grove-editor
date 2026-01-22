import Foundation

class SecurityScopeManager: ObservableObject {
    static let shared = SecurityScopeManager()
    
    @Published var accessibleFolders: [URL] = []
    
    private let bookmarkKey = "SavedFolderBookmarks"
    
    private init() {
        restoreBookmarks()
    }
    
    func startAccessing(url: URL) -> Bool {
        // If we're already accessing it (or a parent), this might be redundant but safe.
        // For simplicity, we just try to start accessing.
        let success = url.startAccessingSecurityScopedResource()
        if success {
            if !accessibleFolders.contains(url) {
                accessibleFolders.append(url)
            }
        }
        return success
    }
    
    func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
        if let index = accessibleFolders.firstIndex(of: url) {
            accessibleFolders.remove(at: index)
        }
    }
    
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            var bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) ?? [:]
            bookmarks[url.path] = bookmarkData
            UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
            
        } catch {
            print("Failed to save bookmark for \(url): \(error)")
        }
    }
    
    private func restoreBookmarks() {
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: Data] else { return }
        
        for (path, data) in bookmarks {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    // Re-save if stale
                    saveBookmark(for: url)
                }
                
                // We don't automatically start accessing everything on launch, 
                // but we could if we wanted to restore the last session.
                // For now, we just ensure we can resolve them.
                print("Restored bookmark for: \(url.path)")
                
            } catch {
                print("Failed to resolve bookmark for \(path): \(error)")
            }
        }
    }
    
    /// Call this when opening a folder to ensure we have persistent access
    func persistPermission(for url: URL) {
        saveBookmark(for: url)
        _ = startAccessing(url: url)
    }
}
