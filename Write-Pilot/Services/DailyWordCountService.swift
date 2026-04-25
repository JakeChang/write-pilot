import Foundation

@Observable
class DailyWordCountService {
    private(set) var todayCount: Int = 0

    private let defaults = UserDefaults.standard
    private let countKey = "dailyWordCount.count"
    private let dateKey = "dailyWordCount.date"

    init() {
        loadToday()
    }

    func addChars(count: Int) {
        guard count > 0 else { return }
        resetIfNewDay()
        todayCount += count
        persist()
    }

    // MARK: - Persistence

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func loadToday() {
        let saved = defaults.string(forKey: dateKey) ?? ""
        if saved == todayString {
            todayCount = defaults.integer(forKey: countKey)
        } else {
            todayCount = 0
        }
    }

    private func resetIfNewDay() {
        let saved = defaults.string(forKey: dateKey) ?? ""
        if saved != todayString {
            todayCount = 0
        }
    }

    private func persist() {
        defaults.set(todayString, forKey: dateKey)
        defaults.set(todayCount, forKey: countKey)
    }
}
