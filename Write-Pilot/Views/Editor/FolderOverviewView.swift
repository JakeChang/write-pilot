import SwiftUI

struct FolderOverviewView: View {
    let node: FileNode
    @Environment(FileService.self) private var fileService
    @State private var plan: WritingPlan?
    @State private var files: [FileInfo] = []
    @State private var totalWords = 0

    private let planService = PlanService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: plan != nil ? "sparkles" : "folder.fill")
                    .foregroundStyle(.tint)
                    .font(.system(size: 18))
                Text(plan?.title ?? node.name)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("共 \(totalWords) 字")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            if let plan {
                planInfoSection(plan)
            }

            Divider()

            // File list
            if files.isEmpty {
                Spacer()
                Text("此資料夾沒有檔案")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                List {
                    ForEach(files, id: \.url) { file in
                        fileRow(file)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: node.id) {
            plan = planService.loadPlanMetadata(from: node.url)
            loadFiles()
        }
    }

    // MARK: - Plan Info

    private func planInfoSection(_ plan: WritingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 16) {
                Label("\(plan.chapters.count) 章", systemImage: "list.number")
                Label(planProgress(plan), systemImage: "chart.bar.fill")
                Label(formatDate(plan.createdAt), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func planProgress(_ plan: WritingPlan) -> String {
        let done = plan.chapters.filter { $0.status == .complete }.count
        return "\(done)/\(plan.chapters.count) 完成"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }

    private func fileRow(_ file: FileInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: file.isDirectory ? "folder" : "doc.text")
                .foregroundStyle(file.isDirectory ? Color.accentColor : Color.secondary)
                .font(.system(size: 13))
                .frame(width: 18)

            Text(file.name)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            if !file.isDirectory {
                Text("\(file.wordCount) 字")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private struct FileInfo {
        let name: String
        let url: URL
        let isDirectory: Bool
        let wordCount: Int
    }

    private struct FileNodeSnapshot: Sendable {
        let name: String
        let url: URL
        let isDirectory: Bool
        let isFile: Bool
    }

    nonisolated private static func computeFiles(snapshots: [FileNodeSnapshot]) -> [FileInfo] {
        snapshots.map { snap in
            let count: Int
            if snap.isFile, let content = try? String(contentsOf: snap.url, encoding: .utf8) {
                count = content.filter { !$0.isWhitespace && !$0.isNewline }.count
            } else {
                count = 0
            }
            return FileInfo(name: snap.name, url: snap.url, isDirectory: snap.isDirectory, wordCount: count)
        }
    }

    private func loadFiles() {
        guard let children = node.sortedChildren else {
            files = []
            totalWords = 0
            return
        }
        let snapshots = children.map {
            FileNodeSnapshot(name: $0.name, url: $0.url, isDirectory: $0.isDirectory, isFile: $0.isFile)
        }
        Task.detached {
            let result = FolderOverviewView.computeFiles(snapshots: snapshots)
            let total = result.reduce(0) { $0 + $1.wordCount }
            await MainActor.run {
                self.files = result
                self.totalWords = total
            }
        }
    }
}
