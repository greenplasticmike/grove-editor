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
    
    func commit(in folderURL: URL) async throws {
        guard !commitMessage.isEmpty else {
            throw NSError(domain: "GitViewModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Commit message cannot be empty"])
        }
        
        await MainActor.run { isCommitting = true }
        defer {
            Task { @MainActor in
                self.isCommitting = false
            }
        }
        
        do {
            try await gitService.commit(message: commitMessage, in: folderURL)
            await MainActor.run {
                self.commitMessage = ""
                self.hasChanges = false
            }
        } catch {
            // Re-throw the error so the caller can handle it
            throw error
        }
    }
}
