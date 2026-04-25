import Foundation

class PlanService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Outline Parsing

    func parseOutline(markdown: String) -> (title: String, chapters: [Chapter]) {
        let lines = markdown.components(separatedBy: "\n")
        var title = ""
        var chapters: [Chapter] = []
        var currentChapterTitle = ""
        var currentPrompt: [String] = []
        var order = 0

        func saveCurrentChapter() {
            guard !currentChapterTitle.isEmpty else { return }
            order += 1
            let filename = makeFilename(title: currentChapterTitle)
            chapters.append(Chapter(
                title: currentChapterTitle,
                filename: filename,
                order: order,
                writingPrompt: currentPrompt.joined(separator: "\n")
            ))
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("# ") && title.isEmpty {
                title = String(trimmed.dropFirst(2))
                continue
            }

            if trimmed.hasPrefix("## ") {
                saveCurrentChapter()
                currentChapterTitle = String(trimmed.dropFirst(3))
                currentPrompt = []
                continue
            }

            if !currentChapterTitle.isEmpty && !trimmed.isEmpty {
                currentPrompt.append(trimmed)
            }
        }

        saveCurrentChapter()

        return (title, chapters)
    }

    private func makeFilename(title: String) -> String {
        let sanitized = title
            .replacingOccurrences(of: "：", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "")
        return "\(sanitized).md"
    }

    // MARK: - File Generation

    func generateChapterFiles(
        plan: WritingPlan,
        outlineMarkdown: String,
        in folderURL: URL,
        fileService: FileService
    ) throws -> (created: [String], skipped: [String]) {
        let fm = FileManager.default
        var created: [String] = []
        var skipped: [String] = []

        // Save the user's edited outline as-is
        let outlineURL = folderURL.appendingPathComponent("outline.md")
        try fileService.writeFile(url: outlineURL, content: outlineMarkdown)

        // Create chapter files — only new ones, skip existing
        for chapter in plan.chapters {
            let chapterURL = folderURL.appendingPathComponent(chapter.filename)
            if fm.fileExists(atPath: chapterURL.path) {
                skipped.append(chapter.filename)
                continue
            }

            let content = generateChapterContent(chapter: chapter)
            try fileService.writeFile(url: chapterURL, content: content)
            created.append(chapter.filename)
        }

        // Save plan metadata
        try savePlanMetadata(plan, to: folderURL)

        return (created, skipped)
    }

    private func generateChapterContent(chapter: Chapter) -> String {
        var content = "# \(chapter.title)\n\n"

        if !chapter.writingPrompt.isEmpty {
            content += "> ✦ 寫作提示\n"
            for line in chapter.writingPrompt.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    content += "> \(trimmed)\n"
                }
            }
            content += "\n"
        }

        content += "（在這裡開始寫）\n"
        return content
    }

    // MARK: - Metadata Persistence

    func savePlanMetadata(_ plan: WritingPlan, to folderURL: URL) throws {
        let metaURL = folderURL.appendingPathComponent(".writepilot")
        let data = try encoder.encode(plan)
        try data.write(to: metaURL)
    }

    func loadPlanMetadata(from folderURL: URL) -> WritingPlan? {
        let metaURL = folderURL.appendingPathComponent(".writepilot")
        guard let data = try? Data(contentsOf: metaURL) else { return nil }
        return try? decoder.decode(WritingPlan.self, from: data)
    }
}
