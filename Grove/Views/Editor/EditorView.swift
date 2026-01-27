import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorView: View {
    @StateObject var viewModel: DocumentViewModel
    @StateObject private var gitViewModel = GitViewModel()
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var isFocused: Bool = false
    @State private var isPreviewMode: Bool
    @State private var showCommitSheet: Bool = false
    @State private var showHistory: Bool = false
    @State private var isGitRepo: Bool = false
    @State private var commitError: String?
    @State private var scrollFraction: CGFloat = 0  // 0.0 to 1.0 position in document
    @State private var isExporting: Bool = false
    @State private var exportError: String?
    @State private var showExportError: Bool = false

    init(document: Document) {
        _viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
        // Initialize view mode from settings
        _isPreviewMode = State(initialValue: SettingsManager.shared.settings.defaultView == .rendered)
    }
    
    private var folderURL: URL {
        viewModel.document.url.deletingLastPathComponent()
    }
    
    private func checkGitStatus() {
        let gitPath = folderURL.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        isGitRepo = FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    var body: some View {
        Group {
            if isPreviewMode {
                RenderedView(
                    content: viewModel.content,
                    settings: settingsManager.settings,
                    scrollFraction: $scrollFraction,
                    documentURL: viewModel.document.url
                )
            } else {
                MarkdownTextView(
                    text: $viewModel.content,
                    font: NSFont(name: settingsManager.settings.fontFamily, size: settingsManager.settings.fontSize)
                        ?? NSFont.monospacedSystemFont(ofSize: settingsManager.settings.fontSize, weight: .regular),
                    lineSpacing: (settingsManager.settings.lineHeight - 1.0) * settingsManager.settings.fontSize,
                    scrollFraction: $scrollFraction,
                    documentURL: viewModel.document.url,
                    isFocusMode: $isFocused
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showCommitSheet = true }) {
                    Label("Save Version", systemImage: "arrow.triangle.2.circlepath")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!isGitRepo)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { showHistory = true }) {
                    Label("History", systemImage: "clock")
                }
                .disabled(!isGitRepo)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isPreviewMode.toggle()
                    // Save view mode preference
                    settingsManager.settings.defaultView = isPreviewMode ? .rendered : .raw
                }) {
                    Label(isPreviewMode ? "Edit" : "Preview", systemImage: isPreviewMode ? "chevron.left.forwardslash.chevron.right" : "eye")
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { isFocused.toggle() }) {
                    Label(
                        isFocused ? "Disable Focus" : "Focus Mode",
                        systemImage: isFocused ? "eye.circle.fill" : "eye.circle"
                    )
                }
                .keyboardShortcut("d", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { exportPDF() }) {
                    Label("Export PDF", systemImage: "arrow.down.doc")
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(isExporting)
            }
        }
        .sheet(isPresented: $showCommitSheet) {
            VStack(spacing: 20) {
                Text("Save Version")
                    .font(.headline)
                
                if let error = commitError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                TextField("Describe your changes...", text: $gitViewModel.commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 300)
                
                HStack {
                    Button("Cancel") {
                        showCommitSheet = false
                        commitError = nil
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Save Version") {
                        Task {
                            commitError = nil
                            do {
                                try await gitViewModel.commit(in: folderURL)
                                await MainActor.run {
                                    showCommitSheet = false
                                }
                            } catch {
                                await MainActor.run {
                                    commitError = "Failed to commit: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(gitViewModel.commitMessage.isEmpty || gitViewModel.isCommitting)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .onAppear {
                // Pre-fill message or check status
                gitViewModel.commitMessage = "Update \(viewModel.document.name)"
                commitError = nil
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                HistoryView(document: viewModel.document)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showHistory = false }
                        }
                    }
            }
            .frame(minWidth: 400, minHeight: 500)
        }
        .onAppear {
            checkGitStatus()
        }
        .onChange(of: viewModel.document.url) {
            checkGitStatus()
        }
        .alert("File Changed Externally", isPresented: $viewModel.showExternalChangeAlert) {
            Button("Reload from Disk") {
                viewModel.reloadFromDisk()
            }
            Button("Keep Local Changes", role: .cancel) {
                viewModel.keepLocalChanges()
            }
        } message: {
            Text("\(viewModel.document.name) has been modified outside Grove.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "An unknown error occurred")
        }
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = viewModel.document.name
            .replacingOccurrences(of: ".md", with: ".pdf")
            .replacingOccurrences(of: ".markdown", with: ".pdf")
        panel.title = "Export as PDF"
        panel.message = "Choose where to save the PDF"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        isExporting = true

        Task {
            do {
                let markdownService = MarkdownService()
                let bodyHTML = markdownService.renderToHTML(
                    viewModel.content,
                    novelStyle: settingsManager.settings.novelStyleParagraphs
                )
                let css = markdownService.getCSS(settings: settingsManager.settings)

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

                let exportService = ExportService()
                try await exportService.exportToPDF(html: fullHTML, to: url)

                await MainActor.run {
                    isExporting = false
                }

                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                    showExportError = true
                }
            }
        }
    }
}
