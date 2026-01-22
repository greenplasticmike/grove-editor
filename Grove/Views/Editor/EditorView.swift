import SwiftUI

struct EditorView: View {
    @StateObject var viewModel: DocumentViewModel
    @StateObject private var gitViewModel = GitViewModel()
    @State private var isFocused: Bool = false
    @State private var isPreviewMode: Bool = false
    @State private var showCommitSheet: Bool = false
    @State private var showHistory: Bool = false
    
    init(document: Document) {
        _viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
    }
    
    var body: some View {
        Group {
            if isPreviewMode {
                RenderedView(content: viewModel.content)
            } else {
                TextEditor(text: $viewModel.content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showCommitSheet = true }) {
                    Label("Save Version", systemImage: "arrow.triangle.2.circlepath")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { showHistory = true }) {
                    Label("History", systemImage: "clock")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { isPreviewMode.toggle() }) {
                    Label(isPreviewMode ? "Edit" : "Preview", systemImage: isPreviewMode ? "chevron.left.forwardslash.chevron.right" : "eye")
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }
        .sheet(isPresented: $showCommitSheet) {
            VStack(spacing: 20) {
                Text("Save Version")
                    .font(.headline)
                
                TextField("Describe your changes...", text: $gitViewModel.commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 300)
                
                HStack {
                    Button("Cancel") {
                        showCommitSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Save Version") {
                        Task {
                            // Use the document's parent directory as the context for git
                            let folderURL = viewModel.document.url.deletingLastPathComponent()
                            await gitViewModel.commit(in: folderURL)
                            showCommitSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(gitViewModel.commitMessage.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .onAppear {
                // Pre-fill message or check status
                gitViewModel.commitMessage = "Update \(viewModel.document.name)"
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
    }
}
