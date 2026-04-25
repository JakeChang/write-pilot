import SwiftUI
import Sparkle

struct SettingsView: View {
    @Environment(FileService.self) private var fileService
    @State private var apiKeyInput = ""
    @State private var hasStoredKey = false
    @State private var statusMessage = ""
    @State private var isTesting = false

    let aiService: AIService
    let updater: SPUUpdater

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("一般", systemImage: "gear")
                }

            apiKeyTab
                .tabItem {
                    Label("API Key", systemImage: "key")
                }

            updateTab
                .tabItem {
                    Label("更新", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 480, height: 280)
        .onAppear {
            hasStoredKey = KeychainService.retrieve() != nil
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("工作區") {
                if let url = fileService.workspaceURL {
                    LabeledContent("目前路徑") {
                        Text(url.path)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                } else {
                    Text("尚未選擇工作區")
                        .foregroundStyle(.secondary)
                }

                Button("更換工作區…") {
                    fileService.openWorkspace()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - API Key Tab

    private var apiKeyTab: some View {
        Form {
            Section("Google AI API Key") {
                if hasStoredKey {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("API Key 已儲存")
                        Spacer()
                        Button("刪除", role: .destructive) {
                            KeychainService.delete()
                            hasStoredKey = false
                            statusMessage = "已刪除"
                            Task {
                                await aiService.configure(apiKey: "")
                            }
                        }
                        .controlSize(.small)
                    }
                } else {
                    SecureField("AIza...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                    Button("儲存") {
                        saveAPIKey()
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("測試連線")
                    }
                }
                .disabled(!hasStoredKey || isTesting)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Update Tab

    private var updateTab: some View {
        Form {
            Section("軟體更新") {
                LabeledContent("目前版本") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .foregroundStyle(.secondary)
                }

                Button("檢查更新") {
                    updater.checkForUpdates()
                }

                Toggle("自動檢查更新", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Actions

    private func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        do {
            try KeychainService.save(apiKey: key)
            hasStoredKey = true
            apiKeyInput = ""
            statusMessage = "✓ 已儲存"
            Task {
                await aiService.configure(apiKey: key)
            }
        } catch {
            statusMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    private func testConnection() {
        isTesting = true
        statusMessage = ""
        Task {
            do {
                let response = try await aiService.send(
                    messages: [ChatMessage(role: .user, content: "Hi, reply with just 'OK'.")],
                    maxTokens: 10
                )
                statusMessage = "✓ 連線成功：\(response)"
            } catch {
                statusMessage = "✗ 連線失敗：\(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
