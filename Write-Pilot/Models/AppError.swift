import Foundation

enum AppError: LocalizedError {
    case fileAccessDenied(URL)
    case fileNotFound(URL)
    case fileWriteFailed(URL, Error)
    case apiKeyMissing
    case apiError(String)
    case networkError(Error)
    case bookmarkStale

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied(let url):
            "無法存取檔案：\(url.lastPathComponent)"
        case .fileNotFound(let url):
            "找不到檔案：\(url.lastPathComponent)"
        case .fileWriteFailed(let url, _):
            "無法寫入檔案：\(url.lastPathComponent)"
        case .apiKeyMissing:
            "尚未設定 API Key"
        case .apiError(let message):
            "API 錯誤：\(message)"
        case .networkError(let error):
            "網路錯誤：\(error.localizedDescription)"
        case .bookmarkStale:
            "工作區書籤已過期，請重新選擇資料夾"
        }
    }
}
