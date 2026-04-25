import SwiftUI

struct OutlineToolbarView: View {
    let file: OpenFile
    @Environment(FileService.self) private var fileService
    var autoSave: AutoSaveService
    var sourceTracker: SourceTracker

    @State private var isGenerating = false
    @State private var resultMessage = ""

    var body: some View {
        Group {
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                Text("產生中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                generateFromOutline()
            } label: {
                Label("產生章節檔案", systemImage: "sparkles")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isGenerating)
        }
    }

    private func generateFromOutline() {
        let folderURL = file.url.deletingLastPathComponent()
        autoSave.saveNow(file: file, fileService: fileService, sourceTracker: sourceTracker)

        isGenerating = true
        resultMessage = ""

        Task {
            do {
                let planService = PlanService()
                let (title, chapters) = planService.parseOutline(markdown: file.content)
                let folderName = folderURL.lastPathComponent
                var plan = WritingPlan(
                    title: title.isEmpty ? folderName : title,
                    chapters: chapters
                )
                plan.description = ""

                let (created, skipped) = try planService.generateChapterFiles(
                    plan: plan,
                    outlineMarkdown: file.content,
                    in: folderURL,
                    fileService: fileService
                )

                fileService.rescan()

                if !created.isEmpty {
                    resultMessage = "新建 \(created.count) 個檔案"
                } else if !skipped.isEmpty {
                    resultMessage = "所有章節檔案已存在"
                } else {
                    resultMessage = "大綱中沒有偵測到章節"
                }
            } catch {
                resultMessage = "產生失敗：\(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}
