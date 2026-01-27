import SwiftUI
import WebKit

struct RenderedView: NSViewRepresentable {
    let content: String
    let settings: AppSettings
    @Binding var scrollFraction: CGFloat
    var documentURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Set up scroll observation via JavaScript
        let script = WKUserScript(
            source: """
                window.addEventListener('scroll', function() {
                    var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
                    var scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
                    var fraction = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
                    window.webkit.messageHandlers.scrollHandler.postMessage(fraction);
                });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(script)
        webView.configuration.userContentController.add(context.coordinator, name: "scrollHandler")

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let markdownService = MarkdownService()
        let bodyHTML = markdownService.renderToHTML(content, novelStyle: settings.novelStyleParagraphs)
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

        // Only reload if content actually changed
        let contentHash = fullHTML.hashValue
        if context.coordinator.lastContentHash != contentHash {
            context.coordinator.lastContentHash = contentHash
            context.coordinator.shouldRestoreScroll = true

            // To load local images, we need to write HTML to a temp file and use loadFileURL
            // This grants the WebView access to the document's folder
            if let documentURL = documentURL {
                let folderURL = documentURL.deletingLastPathComponent()
                let tempHTMLURL = folderURL.appendingPathComponent(".grove-preview.html")

                do {
                    try fullHTML.write(to: tempHTMLURL, atomically: true, encoding: .utf8)
                    nsView.loadFileURL(tempHTMLURL, allowingReadAccessTo: folderURL)
                } catch {
                    print("Failed to write temp HTML: \(error)")
                    nsView.loadHTMLString(fullHTML, baseURL: folderURL)
                }
            } else {
                nsView.loadHTMLString(fullHTML, baseURL: nil)
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: RenderedView
        weak var webView: WKWebView?
        var lastContentHash: Int = 0
        var shouldRestoreScroll = false
        private var isRestoringScroll = false

        init(_ parent: RenderedView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore scroll position after content loads
            if shouldRestoreScroll {
                shouldRestoreScroll = false
                restoreScrollPosition()
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !isRestoringScroll,
                  message.name == "scrollHandler",
                  let fraction = message.body as? Double else { return }

            DispatchQueue.main.async {
                self.parent.scrollFraction = CGFloat(min(max(fraction, 0), 1))
            }
        }

        func restoreScrollPosition() {
            guard let webView = webView else { return }

            isRestoringScroll = true
            let fraction = parent.scrollFraction

            let js = """
                var scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
                var targetScroll = scrollHeight * \(fraction);
                window.scrollTo(0, targetScroll);
            """

            webView.evaluateJavaScript(js) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.isRestoringScroll = false
                }
            }
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "scrollHandler")
        }
    }
}
