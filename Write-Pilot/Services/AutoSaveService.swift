import Foundation

@Observable
class AutoSaveService {
    var lastSavedDate: Date?
    var isSaving = false

    private var saveTask: Task<Void, Never>?

    func scheduleAutoSave(file: OpenFile, fileService: FileService, sourceTracker: SourceTracker? = nil) {
        saveTask?.cancel()
        file.hasUnsavedChanges = true

        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            saveNow(file: file, fileService: fileService, sourceTracker: sourceTracker)
        }
    }

    func saveNow(file: OpenFile, fileService: FileService, sourceTracker: SourceTracker? = nil) {
        saveTask?.cancel()
        isSaving = true
        do {
            try fileService.writeFile(url: file.url, content: file.content)
            try sourceTracker?.save(for: file.url)
            file.hasUnsavedChanges = false
            lastSavedDate = Date()
        } catch {
            // Error will be surfaced later
        }
        isSaving = false
    }

    func cancelPending() {
        saveTask?.cancel()
    }
}
