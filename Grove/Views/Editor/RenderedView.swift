import SwiftUI
import WebKit

struct RenderedView: NSViewRepresentable {
    let content: String
    let settings: AppSettings
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // In a real app, we would configure this with a custom scheme handler for images
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let markdownService = MarkdownService()
        let bodyHTML = markdownService.renderToHTML(content)
        let css = markdownService.getCSS(settings: settings)
        
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            \(css)
        </head>
        <body>
            \(bodyHTML)
        </body>
        </html>
        """
        
        nsView.loadHTMLString(fullHTML, baseURL: nil)
    }
}
