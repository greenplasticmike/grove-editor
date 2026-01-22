import Foundation
import Markdown

struct Document: Identifiable {
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
}
