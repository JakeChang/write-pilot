import Foundation

@Observable
class SourceTracker {
    var typedChars: Int = 0
    var pastedChars: Int = 0
    var targetHumanRatio: Double = 0.70

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted]
    }

    // MARK: - Tracking

    func addTyped(count: Int) {
        typedChars += max(0, count)
    }

    func addPasted(count: Int) {
        pastedChars += max(0, count)
    }

    /// When characters are deleted, reduce typed/pasted proportionally
    /// since we can't know exactly which kind was deleted.
    func removeChars(count: Int) {
        guard count > 0, totalChars > 0 else { return }
        let removeCount = min(count, totalChars)

        let typedPortion = Double(typedChars) / Double(totalChars)
        let typedRemove = Int(round(Double(removeCount) * typedPortion))
        let pastedRemove = removeCount - typedRemove

        typedChars = max(0, typedChars - typedRemove)
        pastedChars = max(0, pastedChars - pastedRemove)
    }

    // MARK: - Statistics

    var totalChars: Int { typedChars + pastedChars }

    var typedRatio: Double {
        guard totalChars > 0 else { return 1.0 }
        return Double(typedChars) / Double(totalChars)
    }

    var pastedRatio: Double {
        guard totalChars > 0 else { return 0 }
        return Double(pastedChars) / Double(totalChars)
    }

    var meetsTarget: Bool {
        typedRatio >= targetHumanRatio
    }

    // MARK: - Persistence

    struct SourceData: Codable {
        var typedChars: Int
        var pastedChars: Int
        var version: String = "2.0"
    }

    func save(for fileURL: URL) throws {
        let sourceURL = fileURL.appendingPathExtension("source")
        let data = SourceData(typedChars: typedChars, pastedChars: pastedChars)
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: sourceURL)
    }

    func load(for fileURL: URL) {
        let sourceURL = fileURL.appendingPathExtension("source")
        guard let jsonData = try? Data(contentsOf: sourceURL),
              let data = try? decoder.decode(SourceData.self, from: jsonData) else {
            typedChars = 0
            pastedChars = 0
            return
        }
        typedChars = data.typedChars
        pastedChars = data.pastedChars
    }

    func reset() {
        typedChars = 0
        pastedChars = 0
    }
}
