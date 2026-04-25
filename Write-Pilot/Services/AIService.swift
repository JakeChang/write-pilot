import Foundation

// MARK: - Models

struct ChatMessage: Codable, Identifiable, Sendable {
    let id: UUID
    var role: Role
    var content: String

    enum Role: String, Codable, Sendable {
        case user
        case assistant

        /// Google AI uses "model" instead of "assistant"
        nonisolated var googleRole: String {
            switch self {
            case .user: "user"
            case .assistant: "model"
            }
        }
    }

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}

enum StreamEvent: Sendable {
    case text(String)
    case done
    case error(String)
}

// MARK: - Google AI Service (Gemma 4 31B)

actor AIService {
    private var apiKey: String?
    private let model = "gemma-4-31b-it"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    var isConfigured: Bool {
        apiKey != nil && !(apiKey?.isEmpty ?? true)
    }

    // MARK: - Streaming

    func stream(
        messages: [ChatMessage],
        system: String? = nil,
        maxTokens: Int = 4096
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey else {
                        continuation.yield(.error("API Key 未設定"))
                        continuation.finish()
                        return
                    }

                    let url = URL(string: "\(baseURL)/\(model):streamGenerateContent?alt=sse&key=\(apiKey)")!

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "content-type")

                    // Build Google AI request body
                    var body: [String: Any] = [
                        "contents": messages.map { msg -> [String: Any] in
                            [
                                "role": msg.role.googleRole,
                                "parts": [["text": msg.content]]
                            ]
                        },
                        "generationConfig": [
                            "maxOutputTokens": maxTokens,
                            "temperature": 0.7,
                        ]
                    ]

                    if let system {
                        body["systemInstruction"] = [
                            "parts": [["text": system]]
                        ]
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        continuation.yield(.error("API 錯誤 (\(httpResponse.statusCode)): \(errorBody)"))
                        continuation.finish()
                        return
                    }

                    // Parse SSE stream from Google AI
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                            continue
                        }

                        // Check for errors
                        if let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            continuation.yield(.error(message))
                            continuation.finish()
                            return
                        }

                        // Extract text from candidates[0].content.parts
                        // Skip "thought" parts (thinking mode output)
                        if let candidates = json["candidates"] as? [[String: Any]],
                           let candidate = candidates.first,
                           let content = candidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]] {
                            for part in parts {
                                // Skip thought parts from thinking mode
                                if part["thought"] as? Bool == true { continue }
                                if let text = part["text"] as? String {
                                    continuation.yield(.text(text))
                                }
                            }
                        }

                        // Check if this is the last chunk
                        if let candidates = json["candidates"] as? [[String: Any]],
                           let candidate = candidates.first,
                           let finishReason = candidate["finishReason"] as? String,
                           finishReason == "STOP" {
                            continuation.yield(.done)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Non-streaming (convenience)

    func send(
        messages: [ChatMessage],
        system: String? = nil,
        maxTokens: Int = 4096
    ) async throws -> String {
        var result = ""
        for try await event in stream(messages: messages, system: system, maxTokens: maxTokens) {
            switch event {
            case .text(let text):
                result += text
            case .done:
                break
            case .error(let message):
                throw AppError.apiError(message)
            }
        }
        return result
    }
}
