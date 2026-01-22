import Foundation
import Markdown

class MarkdownService {
    func parseDocument(_ content: String) -> Document {
        // In a real app, this would return a parsed AST or similar
        // For now using the model wrapper
        return Document(parsing: content)
    }
}
