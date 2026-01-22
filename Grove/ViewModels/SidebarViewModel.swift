import Foundation
import Combine

class SidebarViewModel: ObservableObject {
    @Published var rootFolder: Folder?
    @Published var selectedItem: FileSystemItem?
    @Published var isGitRepo: Bool = false
    
    private let fileManager = FileManager.default
    
    init() {
        // Restore last opened folder if available
        if let lastFolder = SecurityScopeManager.shared.accessibleFolders.first {
            loadFolder(url: lastFolder)
        }
    }
    
    func loadFolder(url: URL) {
        // Persist permission and start accessing
        SecurityScopeManager.shared.persistPermission(for: url)
        
        // We do NOT stop accessing here, because we need to maintain access
        // for the duration of the app session (for auto-save, etc.)
        // In a more complex app, we would track this and stop accessing when closing the folder.
        
        let items = loadItems(from: url)
        self.rootFolder = Folder(url: url, children: items)
        checkGitStatus(url: url)
    }
    
    func checkGitStatus(url: URL) {
        let gitPath = url.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        isGitRepo = fileManager.fileExists(atPath: gitPath.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    func initGitRepo() {
        guard let url = rootFolder?.url else { return }
        Task {
            try? await GitService().initRepo(in: url)
            await MainActor.run {
                self.checkGitStatus(url: url)
            }
        }
    }
    
    private func loadItems(from url: URL) -> [FileSystemItem] {
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        var items: [FileSystemItem] = []
        
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Start accessing for subfolders if needed? Usually parent access covers it.
                    let subItems = loadItems(from: itemURL)
                    let folder = Folder(url: itemURL, children: subItems)
                    items.append(.folder(folder))
                } else if itemURL.pathExtension == "md" {
                    let document = Document(url: itemURL)
                    items.append(.document(document))
                }
            }
        }
        
        return items.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.folder, .document): return true
            case (.document, .folder): return false
            case (.folder(let l), .folder(let r)): return l.name.localizedStandardCompare(r.name) == .orderedAscending
            case (.document(let l), .document(let r)): return l.name.localizedStandardCompare(r.name) == .orderedAscending
            }
        }
    }
}
