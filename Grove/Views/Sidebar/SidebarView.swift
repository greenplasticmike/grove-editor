import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Label("Documents", systemImage: "folder")
            // This would recursively show FileTreeView
        }
        .listStyle(SidebarListStyle())
    }
}
