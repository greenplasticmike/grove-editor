import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @Binding var selectedItem: FileSystemItem?
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rootFolder == nil {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            
            FileTreeView(items: viewModel.rootFolder?.children ?? [], selectedItem: $selectedItem)
            
            if viewModel.rootFolder != nil && !viewModel.isGitRepo {
                Divider()
                Button(action: viewModel.initGitRepo) {
                    Label("Initialize Git Repo", systemImage: "git.branch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }
    
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                viewModel.loadFolder(url: url)
            }
        }
    }
}
