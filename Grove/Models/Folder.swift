import Foundation

struct Folder: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var children: [Folder]?
    
    init(url: URL, children: [Folder]? = nil) {
        self.id = UUID()
        self.url = url
        self.children = children
    }
    
    var name: String {
        url.lastPathComponent
    }
}
