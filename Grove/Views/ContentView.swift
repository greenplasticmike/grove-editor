import SwiftUI

struct ContentView: View {
    @StateObject private var sidebarViewModel = SidebarViewModel()
    @State private var selectedItem: FileSystemItem?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarViewModel, selectedItem: $selectedItem)
        } detail: {
            if let item = selectedItem, case .document(let document) = item {
                EditorView(document: document)
                    .id(document.id) // Force recreate view when document changes
            } else {
                Text("Select a file")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
