import Foundation
import Combine

class GitViewModel: ObservableObject {
    @Published var isCommitting = false
    @Published var commitMessage = ""
    @Published var hasChanges = false
    
    private let gitService = GitService()
    
    func checkStatus(in folderURL: URL) {
        Task {
            let changed = await gitService.hasChanges(in: folderURL)
            await MainActor.run {
                self.hasChanges = changed
            }
        }
    }
    
    func commit(in folderURL: URL) async {
        guard !commitMessage.isEmpty else { return }
        
        await MainActor.run { isCommitting = true }
        
        do {
            try await gitService.commit(message: commitMessage, in: folderURL)
            await MainActor.run {
                self.commitMessage = ""
                self.hasChanges = false
            }
        } catch {
            print("Commit failed: \(error)")
        }
        
        await MainActor.run { isCommitting = false }
    }
}
