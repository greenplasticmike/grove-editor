import Foundation
import Combine

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
        
        for (_, data) in bookmarks {
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
                
                // Start accessing the security scope so we can use it immediately
                // This is critical for auto-save to work
                if startAccessing(url: url) {
                    print("Restored and started accessing bookmark for: \(url.path)")
                } else {
                    print("Failed to start accessing restored bookmark for: \(url.path)")
                }
                
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
    }
    
    /// Call this when opening a folder to ensure we have persistent access
    func persistPermission(for url: URL) {
        saveBookmark(for: url)
        _ = startAccessing(url: url)
    }
    
    /// Ensure we have access to a file's parent directory for saving
    func ensureAccess(for fileURL: URL) -> Bool {
        let parentURL = fileURL.deletingLastPathComponent()
        
        // Check if we're already accessing this folder or a parent
        for accessibleFolder in accessibleFolders {
            if parentURL.path.hasPrefix(accessibleFolder.path) {
                return true
            }
        }
        
        // Try to restore and access if we have a bookmark
        if let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: Data] {
            for (_, data) in bookmarks {
                var isStale = false
                do {
                    let url = try URL(
                        resolvingBookmarkData: data,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    
                    if parentURL.path.hasPrefix(url.path) || url.path.hasPrefix(parentURL.path) {
                        if isStale {
                            saveBookmark(for: url)
                        }
                        return startAccessing(url: url)
                    }
                } catch {
                    continue
                }
            }
        }
        
        return false
    }
}
