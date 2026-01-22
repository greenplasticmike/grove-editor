import Foundation
import Combine
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: AppSettings {
        didSet {
            // Only save if we're not currently syncing (to prevent infinite recursion)
            if !isSyncing {
                save()
            }
        }
    }
    
    private let key = "GroveSettings"
    private var isSyncing = false
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
            
            // Resolve bookmarks and ensure security scopes are started
            let resolvedFolders = settings.recentFolders
            for folder in resolvedFolders {
                // Ensure SecurityScopeManager has the bookmark and is accessing it
                SecurityScopeManager.shared.persistPermission(for: folder)
            }
        } else {
            self.settings = AppSettings()
        }
        
        // Sync recentFolders with SecurityScopeManager's accessible folders
        // Set flag to prevent didSet from triggering during init
        isSyncing = true
        syncRecentFolders()
        isSyncing = false
    }
    
    private func save() {
        // Don't sync during save to prevent recursion - sync happens explicitly when needed
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func syncRecentFolders() {
        // Get accessible folders from SecurityScopeManager
        // These are folders we have bookmarks for and are currently accessing
        let accessibleFolders = SecurityScopeManager.shared.accessibleFolders
        
        // Check if folders actually changed to avoid unnecessary updates
        let currentFolders = Set(settings.recentFolders.map { $0.path })
        let newFolders = Set(accessibleFolders.map { $0.path })
        
        guard currentFolders != newFolders else {
            return // No change, skip update
        }
        
        // Update Settings with the current accessible folders
        // This will convert URLs to bookmark data for storage
        // Set flag to prevent didSet from triggering save (which would call sync again)
        isSyncing = true
        settings.recentFolders = accessibleFolders
        isSyncing = false
        
        // Now save explicitly after syncing (without triggering another sync)
        save()
    }
    
    func addRecentFolder(_ url: URL) {
        // SecurityScopeManager handles bookmark persistence
        // We just sync our settings
        syncRecentFolders()
    }
}
