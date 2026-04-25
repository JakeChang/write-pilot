import Foundation

struct KeychainService {
    private static let key = "google-ai-api-key"

    static func save(apiKey: String) throws {
        UserDefaults.standard.set(apiKey, forKey: key)
    }

    static func retrieve() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
