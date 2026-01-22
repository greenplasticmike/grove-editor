import Foundation

struct Folder: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var children: [FileSystemItem]?
    
    init(url: URL, children: [FileSystemItem]? = nil) {
        self.id = UUID()
        self.url = url
        self.children = children
    }
    
    var name: String {
        url.lastPathComponent
    }
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
