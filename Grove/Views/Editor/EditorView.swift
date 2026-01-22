import SwiftUI

struct EditorView: View {
    @StateObject var viewModel: DocumentViewModel
    @StateObject private var gitViewModel = GitViewModel()
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var isFocused: Bool = false
    @State private var isPreviewMode: Bool = false
    @State private var showCommitSheet: Bool = false
    @State private var showHistory: Bool = false
    @State private var isGitRepo: Bool = false
    @State private var commitError: String?
    
    init(document: Document) {
        _viewModel = StateObject(wrappedValue: DocumentViewModel(document: document))
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
                RenderedView(content: viewModel.content, settings: settingsManager.settings)
            } else {
                TextEditor(text: $viewModel.content)
                    .font(.custom(settingsManager.settings.fontFamily, size: settingsManager.settings.fontSize))
                    .lineSpacing((settingsManager.settings.lineHeight - 1.0) * settingsManager.settings.fontSize)
                    .padding()
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
    }
}
