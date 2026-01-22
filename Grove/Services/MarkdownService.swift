import Foundation
import Markdown

class MarkdownService {
    func renderToHTML(_ content: String) -> String {
        let document = Markdown.Document(parsing: content)
        var visitor = HTMLVisitor()
        return visitor.visit(document)
    }
    
    func getCSS(settings: AppSettings) -> String {
        let (textColor, bgColor, linkColor, codeBg): (String, String, String, String)
        
        // Base colors
        switch settings.theme {
        case .dark:
            textColor = "#e0e0e0"
            bgColor = "#1e1e1e"
            linkColor = settings.style == .bear ? "#d85151" : "#58a6ff"
            codeBg = "rgba(127, 127, 127, 0.15)"
        case .light:
            textColor = "#333333"
            bgColor = "#ffffff"
            linkColor = settings.style == .bear ? "#cc2222" : "#0366d6"
            codeBg = "rgba(127, 127, 127, 0.1)"
        case .system:
            textColor = "var(--text-color)"
            bgColor = "var(--bg-color)"
            linkColor = "var(--link-color)"
            codeBg = "var(--code-bg)"
        }
        
        // Font Family logic
        let fontFamily: String
        let headingFont: String
        
        switch settings.style {
        case .iaWriter:
            // Monospace everything
            fontFamily = "\"\(settings.fontFamily)\", \"Monaco\", \"Courier New\", monospace"
            headingFont = fontFamily
        case .bear:
            // Sans-serif body, specific headers
            fontFamily = "-apple-system, BlinkMacSystemFont, \"Avenir Next\", \"Avenir\", sans-serif"
            headingFont = "-apple-system, BlinkMacSystemFont, \"Avenir Next\", \"Avenir\", sans-serif"
        case .standard:
            fontFamily = "-apple-system, BlinkMacSystemFont, sans-serif"
            headingFont = fontFamily
        }
        
        return """
        <style>
            :root {
                --text-color: #333333;
                --bg-color: #ffffff;
                --link-color: \(settings.style == .bear ? "#cc2222" : "#0366d6");
                --code-bg: rgba(127, 127, 127, 0.1);
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --text-color: #e0e0e0;
                    --bg-color: #1e1e1e;
                    --link-color: \(settings.style == .bear ? "#d85151" : "#58a6ff");
                    --code-bg: rgba(127, 127, 127, 0.15);
                }
            }
            
            body {
                font-family: \(fontFamily);
                font-size: \(Int(settings.fontSize))px;
                line-height: \(settings.lineHeight);
                color: \(textColor);
                background-color: \(bgColor);
                padding: 40px;
                max-width: 680px;
                margin: 0 auto;
            }
            
            /* Typography */
            h1, h2, h3, h4, h5, h6 {
                font-family: \(headingFont);
                margin-top: 1.5em;
                margin-bottom: 0.5em;
                font-weight: 600;
                color: \(textColor);
            }
            
            p { margin-bottom: 1em; }
            
            a {
                color: \(linkColor);
                text-decoration: none;
            }
            a:hover { text-decoration: underline; }
            
            /* Code */
            code {
                background-color: \(codeBg);
                padding: 0.2em 0.4em;
                border-radius: 3px;
                font-family: "\(settings.fontFamily)", "Menlo", monospace;
                font-size: 0.9em;
            }
            
            pre {
                background-color: \(codeBg);
                padding: 16px;
                overflow: auto;
                border-radius: 6px;
            }
            
            pre code {
                background-color: transparent;
                padding: 0;
            }
            
            /* Blockquotes */
            blockquote {
                border-left: 3px solid \(settings.style == .bear ? "#cc2222" : "#dfe2e5");
                color: #6a737d;
                padding-left: 1em;
                margin-left: 0;
            }
            
            /* Lists */
            ul, ol { padding-left: 2em; }
            li { margin-bottom: 0.25em; }
            
            /* Images */
            img { max-width: 100%; border-radius: 4px; }
            
            /* Tables */
            table { border-collapse: collapse; width: 100%; margin-bottom: 1em; }
            th, td { border: 1px solid #dfe2e5; padding: 6px 13px; }
            tr:nth-child(2n) { background-color: \(codeBg); }
            
            /* Specific Style Overrides */
            \(settings.style == .iaWriter ? """
            /* iA Writer Style Overrides */
            h1, h2, h3, h4, h5, h6 { font-weight: 500; }
            blockquote { border-color: rgba(127,127,127,0.3); }
            """ : "")
            
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
