import Foundation

enum FileSystemItem: Identifiable, Hashable {
    case folder(Folder)
    case document(Document)
    
    var id: UUID {
        switch self {
        case .folder(let folder): return folder.id
        case .document(let document): return document.id
        }
    }
    
    var url: URL {
        switch self {
        case .folder(let folder): return folder.url
        case .document(let document): return document.url
        }
    }
    
    var name: String {
        url.lastPathComponent
    }

    var children: [FileSystemItem]? {
        switch self {
        case .folder(let folder): return folder.children
        case .document: return nil
        }
    }
}
