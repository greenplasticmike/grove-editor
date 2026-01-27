import Foundation
import Combine

class DocumentViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var showExternalChangeAlert: Bool = false
    let document: Document
    private var fileService = FileService()
    private var cancellables = Set<AnyCancellable>()
    private var fileWatcher: FileWatcher?
    private var lastSaveTime: Date = Date()
    private var isSaving: Bool = false

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
        startWatching()
    }

    deinit {
        fileWatcher?.cancel()
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

    private func startWatching() {
        fileWatcher = fileService.watchFile(document.url) { [weak self] in
            self?.handleFileSystemChange()
        }
    }

    private func handleFileSystemChange() {
        // Ignore changes caused by our own auto-save
        guard !isSaving else { return }

        let timeSinceSave = Date().timeIntervalSince(lastSaveTime)
        if timeSinceSave < 2.0 {
            return
        }

        // Check if file modification date is newer than our last save
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: document.url.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }

        if modDate > lastSaveTime {
            showExternalChangeAlert = true
        }
    }

    func reloadFromDisk() {
        do {
            let loadedContent = try fileService.read(from: document.url)
            self.content = loadedContent
            self.lastSaveTime = Date()
        } catch {
            print("Failed to reload document: \(error)")
        }
        showExternalChangeAlert = false
    }

    func keepLocalChanges() {
        lastSaveTime = Date()
        showExternalChangeAlert = false
    }

    func saveDocument() {
        isSaving = true

        // Ensure we have permission to write to this file's location
        if !SecurityScopeManager.shared.ensureAccess(for: document.url) {
            print("Warning: Could not ensure security scope access for \(document.url)")
        }

        do {
            try fileService.save(content: content, to: document.url)
            lastSaveTime = Date()
        } catch {
            print("Error saving document: \(error)")
        }

        // Small delay before clearing isSaving to avoid race with DispatchSource
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSaving = false
        }
    }
}
