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
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func read(from url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }
}
