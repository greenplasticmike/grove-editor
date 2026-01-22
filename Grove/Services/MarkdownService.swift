import Foundation
import Markdown

class MarkdownService {
    func renderToHTML(_ content: String) -> String {
        let document = Markdown.Document(parsing: content)
        var visitor = HTMLVisitor()
        return visitor.visit(document)
    }
    
    // Basic CSS for styling the output
    func getCSS() -> String {
        return """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 16px;
                line-height: 1.6;
                color: var(--text-color);
                background-color: var(--bg-color);
                padding: 20px;
                max-width: 800px;
                margin: 0 auto;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --text-color: #e0e0e0;
                    --bg-color: #1e1e1e;
                }
            }
            @media (prefers-color-scheme: light) {
                :root {
                    --text-color: #333;
                    --bg-color: #ffffff;
                }
            }
            h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; font-weight: 600; }
            p { margin-bottom: 1em; }
            code { background-color: rgba(127, 127, 127, 0.1); padding: 2px 4px; border-radius: 4px; font-family: "Menlo", monospace; }
            pre { background-color: rgba(127, 127, 127, 0.1); padding: 10px; border-radius: 8px; overflow-x: auto; }
            blockquote { border-left: 4px solid #ccc; padding-left: 1em; color: #666; margin-left: 0; }
            ul, ol { padding-left: 2em; }
            li { margin-bottom: 0.25em; }
            img { max-width: 100%; height: auto; border-radius: 4px; }
        </style>
        """
    }
}

// Simple visitor to convert Markdown AST to HTML
struct HTMLVisitor: MarkupVisitor {
    typealias Result = String
    
    mutating func defaultVisit(_ markup: Markup) -> String {
        return markup.children.map { visit($0) }.joined()
    }
    
    mutating func visitDocument(_ document: Markdown.Document) -> String {
        return defaultVisit(document)
    }
    
    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        let content = defaultVisit(heading)
        return "<h\(level)>\(content)</h\(level)>"
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        return "<p>\(defaultVisit(paragraph))</p>"
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        return "<em>\(defaultVisit(emphasis))</em>"
    }
    
    mutating func visitStrong(_ strong: Strong) -> String {
        return "<strong>\(defaultVisit(strong))</strong>"
    }
    
    mutating func visitText(_ text: Text) -> String {
        return text.string
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        return "<pre><code>\(codeBlock.code)</code></pre>"
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        return "<code>\(inlineCode.code)</code>"
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        return "<ul>\(defaultVisit(unorderedList))</ul>"
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        return "<ol>\(defaultVisit(orderedList))</ol>"
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> String {
        return "<li>\(defaultVisit(listItem))</li>"
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        return "<blockquote>\(defaultVisit(blockQuote))</blockquote>"
    }
    
    mutating func visitLink(_ link: Link) -> String {
        let content = defaultVisit(link)
        let href = link.destination ?? "#"
        return "<a href=\"\(href)\">\(content)</a>"
    }
    
    mutating func visitImage(_ image: Image) -> String {
        let src = image.source ?? ""
        let alt = image.title ?? ""
        return "<img src=\"\(src)\" alt=\"\(alt)\" />"
    }
    
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        return " "
    }
    
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        return "<br>"
    }
}
