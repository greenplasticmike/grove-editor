import Foundation
import WebKit

class ExportService {
    func exportToPDF(html: String, to url: URL) async throws {
        // Requires UI-related dispatch usually, WKWebView must be on main thread
        await MainActor.run {
            let webView = WKWebView()
            webView.loadHTMLString(html, baseURL: nil)
            // In a real implementation, we need to wait for navigation delegate to finish
            // This is a placeholder for the logic structure
        }
    }

    func exportToDocx(markdown: URL, to output: URL) async throws {
        guard let pandocPath = Bundle.main.path(forResource: "pandoc", ofType: nil, inDirectory: "Pandoc") else {
            throw NSError(domain: "ExportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pandoc binary not found"])
        }
        _ = try await shell(pandocPath, "-o", output.path, markdown.path)
    }
}
