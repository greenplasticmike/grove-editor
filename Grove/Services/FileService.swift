import Foundation

class FileService {
    
    func watchFile(_ url: URL, onChange: @escaping () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .main
        )
        
        source.setEventHandler {
            onChange()
        }
        
        source.resume()
    }
    
    func save(content: String, to url: URL) throws {
        // Ensure we have security-scoped access to the parent directory
        guard SecurityScopeManager.shared.ensureAccess(for: url) else {
            throw NSError(
                domain: "FileServiceError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No security-scoped access to save file at \(url.path)"]
            )
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func read(from url: URL) throws -> String {
        // Ensure we have security-scoped access to the parent directory
        guard SecurityScopeManager.shared.ensureAccess(for: url) else {
            throw NSError(
                domain: "FileServiceError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No security-scoped access to read file at \(url.path)"]
            )
        }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
}
