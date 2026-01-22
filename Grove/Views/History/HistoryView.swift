import SwiftUI

struct HistoryView: View {
    let document: Document
    @StateObject private var gitViewModel = GitViewModel()
    @State private var commits: [Commit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Failed to load history")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if commits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No history available")
                        .foregroundStyle(.secondary)
                    Text("This file has no commit history yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(commits) { commit in
                    VStack(alignment: .leading, spacing: 8) {
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
            await loadHistory()
        }
    }
    
    private func loadHistory() async {
        isLoading = true
        errorMessage = nil
        
        let service = GitService()
        do {
            commits = try await service.log(for: document.url)
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load history: \(error)")
        }
        
        isLoading = false
    }
}
