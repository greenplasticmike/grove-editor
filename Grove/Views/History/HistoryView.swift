import SwiftUI

struct HistoryView: View {
    let document: Document
    @StateObject private var gitViewModel = GitViewModel()
    @State private var commits: [Commit] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if commits.isEmpty {
                Text("No history available")
                    .foregroundStyle(.secondary)
            } else {
                List(commits) { commit in
                    VStack(alignment: .leading) {
                        Text(commit.message)
                            .font(.headline)
                        HStack {
                            Text(commit.id)
                                .font(.caption)
                                .monospaced()
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text(commit.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("History: \(document.name)")
        .task {
            isLoading = true
            let service = GitService()
            do {
                commits = try await service.log(for: document.url)
            } catch {
                print("Failed to load history: \(error)")
            }
            isLoading = false
        }
    }
}
