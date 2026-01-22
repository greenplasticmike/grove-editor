import Foundation
import Combine

class DocumentViewModel: ObservableObject {
    @Published var content: String = ""
    let document: Document
    private var fileService = FileService()
    private var cancellables = Set<AnyCancellable>()
    
    init(document: Document) {
        self.document = document
        
        do {
            let loadedContent = try fileService.read(from: document.url)
            self.content = loadedContent
        } catch {
            print("Failed to load document content: \(error)")
            self.content = document.content
        }
        
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        $content
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.saveDocument()
            }
            .store(in: &cancellables)
    }
    
    func saveDocument() {
        // Ensure we have permission to write to this file's location
        if !SecurityScopeManager.shared.ensureAccess(for: document.url) {
            print("Warning: Could not ensure security scope access for \(document.url)")
        }
        
        do {
            try fileService.save(content: content, to: document.url)
            // Handle success (maybe update last modified)
        } catch {
            print("Error saving document: \(error)")
        }
    }
}
