import Foundation
import Observation

/// 句帳の 1 枚（短冊）
struct Verse: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var kouIndex: Int
    var lines: [String]
    var kigo: [String]

    var text: String { lines.joined(separator: " ") }
    var kou: Kou { Almanac.kous[kouIndex] }
}

/// 句帳の決まり（画面から切り離してテストする）
enum KuchoRules {
    /// 続けた日数：今日まで（今日がまだなら昨日まで）毎日詠んだ日数
    static func streak(_ verses: [Verse], today: Date, calendar: Calendar) -> Int {
        let days = Set(verses.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day), days.contains(y) else { return 0 }
            day = y
        }
        var n = 0
        while days.contains(day) {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// この暦の 1 年（立春から）に詠んだ候
    static func kousThisYear(_ verses: [Verse], today: Date, calendar: Calendar) -> Set<Int> {
        let start = Almanac.yearStart(onOrBefore: today, calendar: calendar)
        return Set(verses.filter { $0.date >= start && $0.date <= today.addingTimeInterval(86_400) }.map(\.kouIndex))
    }

    /// この 1 年に詠んだ日数（途切れても積み上がる数）
    static func daysThisYear(_ verses: [Verse], today: Date, calendar: Calendar) -> Int {
        let start = Almanac.yearStart(onOrBefore: today, calendar: calendar)
        return Set(verses.filter { $0.date >= start }.map { calendar.startOfDay(for: $0.date) }).count
    }

    /// 前の年の同じ候に詠んだ句（新しい順）
    static func lastYear(_ verses: [Verse], today: Date, calendar: Calendar) -> [Verse] {
        let index = Almanac.kouIndex(on: today, calendar: calendar)
        let start = Almanac.yearStart(onOrBefore: today, calendar: calendar)
        return verses.filter { $0.kouIndex == index && $0.date < start }.sorted { $0.date > $1.date }
    }
}

@MainActor
@Observable
final class KuchoStore {
    private(set) var verses: [Verse]
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored let calendar: Calendar
    static let key = "kucho.verses.v1"

    /// defaults が nil なら保存しない（スクリーンショットとテスト用）
    init(defaults: UserDefaults? = .standard, seed: [Verse]? = nil, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if let seed {
            verses = seed
        } else if let data = defaults?.data(forKey: Self.key), let saved = try? JSONDecoder().decode([Verse].self, from: data) {
            verses = saved
        } else {
            verses = []
        }
    }

    var sorted: [Verse] { verses.sorted { $0.date > $1.date } }

    @discardableResult
    func add(lines: [String], on date: Date = .now) -> Verse {
        let clean = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let verse = Verse(
            date: date, kouIndex: Almanac.kouIndex(on: date, calendar: calendar), lines: clean,
            kigo: KigoFinder.find(in: clean.joined()).map(\.word)
        )
        verses.append(verse)
        save()
        return verse
    }

    func delete(_ verse: Verse) {
        verses.removeAll { $0.id == verse.id }
        save()
    }

    func streak(today: Date = .now) -> Int { KuchoRules.streak(verses, today: today, calendar: calendar) }
    func kousThisYear(today: Date = .now) -> Set<Int> { KuchoRules.kousThisYear(verses, today: today, calendar: calendar) }
    func daysThisYear(today: Date = .now) -> Int { KuchoRules.daysThisYear(verses, today: today, calendar: calendar) }
    func lastYear(today: Date = .now) -> [Verse] { KuchoRules.lastYear(verses, today: today, calendar: calendar) }
    func wroteToday(_ today: Date = .now) -> Bool { verses.contains { calendar.isDate($0.date, inSameDayAs: today) } }

    private func save() {
        guard let defaults, let data = try? JSONEncoder().encode(verses) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
