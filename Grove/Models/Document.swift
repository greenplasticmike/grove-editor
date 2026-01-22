import Foundation
import Markdown

struct Document: Identifiable, Hashable {
    let id: UUID
    var content: String
    var url: URL
    
    init(url: URL, content: String = "") {
        self.id = UUID()
        self.url = url
        self.content = content
    }
    
    init(parsing content: String) {
        self.id = UUID()
        self.url = URL(fileURLWithPath: "") // Temporary or in-memory
        self.content = content
    }
    
    var name: String {
        url.lastPathComponent
    }
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
