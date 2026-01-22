import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Text("Select a file")
            // In real app, this binds to selected document
        }
    }
}
