import Foundation

struct WritingPlan: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var createdAt: Date
    var chapters: [Chapter]
    var targetWordCount: Int?

    init(title: String, description: String = "", chapters: [Chapter] = []) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.createdAt = Date()
        self.chapters = chapters
    }
}

struct Chapter: Codable, Identifiable {
    let id: UUID
    var title: String
    var filename: String
    var order: Int
    var writingPrompt: String
    var status: ChapterStatus
    var wordCountTarget: Int?

    init(title: String, filename: String, order: Int, writingPrompt: String = "") {
        self.id = UUID()
        self.title = title
        self.filename = filename
        self.order = order
        self.writingPrompt = writingPrompt
        self.status = .notStarted
    }
}

enum ChapterStatus: String, Codable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case complete = "complete"

    var dotColor: String {
        switch self {
        case .notStarted: "red"
        case .inProgress: "yellow"
        case .complete: "green"
        }
    }
}
