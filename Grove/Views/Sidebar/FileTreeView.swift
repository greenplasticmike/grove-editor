import SwiftUI

struct FileTreeView: View {
    let items: [FileSystemItem]
    @Binding var selectedItem: FileSystemItem?
    
    var body: some View {
        List(items, children: \.children, selection: $selectedItem) { item in
            switch item {
            case .folder(let folder):
                Label(folder.name, systemImage: "folder")
            case .document(let document):
                NavigationLink(value: item) {
                    Label(document.url.lastPathComponent, systemImage: "doc.text")
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}
