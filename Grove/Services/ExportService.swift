import Foundation
import WebKit

enum ExportError: LocalizedError {
    case pdfGenerationFailed(String)
    case webViewLoadFailed(String)
    case fileWriteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .pdfGenerationFailed(let reason):
            return "PDF generation failed: \(reason)"
        case .webViewLoadFailed(let reason):
            return "Failed to load content for export: \(reason)"
        case .fileWriteFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        }
    }
}

class ExportService {

    /// Export styled HTML to PDF at the given URL.
    /// Must be called on the main thread (WKWebView requirement).
    @MainActor
    func exportToPDF(html: String, to url: URL) async throws {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))

        // Wait for HTML to finish loading via navigation delegate
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = ExportNavigationDelegate(continuation: continuation)
            webView.navigationDelegate = delegate
            // Retain delegate on the webView to prevent deallocation
            objc_setAssociatedObject(webView, "exportDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.loadHTMLString(html, baseURL: nil)
        }

        // Generate PDF
        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = NSRect(x: 0, y: 0, width: 595, height: 842)

        let pdfData: Data
        do {
            pdfData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                webView.createPDF(configuration: pdfConfig) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            throw ExportError.pdfGenerationFailed(error.localizedDescription)
        }

        do {
            try pdfData.write(to: url)
        } catch {
            throw ExportError.fileWriteFailed(error)
        }
    }

    func exportToDocx(markdown: URL, to output: URL) async throws {
        guard let pandocPath = Bundle.main.path(forResource: "pandoc", ofType: nil, inDirectory: "Pandoc") else {
            throw NSError(domain: "ExportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pandoc binary not found"])
        }
        _ = try await shell(pandocPath, "-o", output.path, markdown.path)
    }
}

/// Navigation delegate that signals completion via a checked continuation
private class ExportNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: ExportError.webViewLoadFailed(error.localizedDescription))
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: ExportError.webViewLoadFailed(error.localizedDescription))
        continuation = nil
    }
}
