import Foundation

enum Season: Int, CaseIterable, Codable, Sendable {
    case spring, summer, autumn, winter

    var name: String { ["春", "夏", "秋", "冬"][rawValue] }
}

struct Kigo: Hashable, Sendable {
    let word: String
    let reading: String
    /// 散歩のお題（その季語を探す・感じる小さな行動）
    let prompt: String
    let season: Season
    let kouIndex: Int
}

/// 七十二候の 1 つ（約 5 日）
struct Kou: Identifiable, Hashable, Sendable {
    let index: Int
    let name: String
    let reading: String
    let month: Int
    let day: Int
    let meaning: String
    let kigo: [Kigo]

    var id: Int { index }
    var season: Season { Season(rawValue: index / 18)! }
    var sekki: String { AlmanacData.sekki[index / 3] }
    var phase: String { ["初候", "次候", "末候"][index % 3] }
    var startLabel: String { "\(month)/\(day)ごろ" }
}

enum Almanac {
    static let kous: [Kou] = parse(AlmanacData.raw)
    static let allKigo: [Kigo] = kous.flatMap(\.kigo)

    static func parse(_ raw: String) -> [Kou] {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, line in
                let f = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                let md = f[2].split(separator: "/").compactMap { Int($0) }
                let season = Season(rawValue: index / 18)!
                let kigo = f[4].split(separator: ",").map { item -> Kigo in
                    let p = item.split(separator: ":", maxSplits: 2).map(String.init)
                    return Kigo(word: p[0], reading: p[1], prompt: p[2], season: season, kouIndex: index)
                }
                return Kou(index: index, name: f[0], reading: f[1], month: md[0], day: md[1], meaning: f[3], kigo: kigo)
            }
    }

    /// その日の候の番号（0 = 東風解凍 … 71 = 鶏始乳）
    static func kouIndex(on date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.month, .day], from: date)
        let key = (c.month ?? 1) * 100 + (c.day ?? 1)
        var best: (key: Int, index: Int)?
        var latest: (key: Int, index: Int) = (0, 0)
        for kou in kous {
            let k = kou.month * 100 + kou.day
            if k <= key, k > (best?.key ?? -1) { best = (k, kou.index) }
            if k > latest.key { latest = (k, kou.index) }
        }
        // 1/1〜1/4 は、前の年の 12/31 に始まった候
        return best?.index ?? latest.index
    }

    static func kou(on date: Date, calendar: Calendar) -> Kou {
        kous[kouIndex(on: date, calendar: calendar)]
    }

    /// その候が始まった日（その日より前で、いちばん近い年の月日）
    static func startDate(of index: Int, onOrBefore date: Date, calendar: Calendar) -> Date {
        let kou = kous[index]
        let year = calendar.component(.year, from: date)
        for y in [year, year - 1] {
            if let d = calendar.date(from: DateComponents(year: y, month: kou.month, day: kou.day)),
               calendar.startOfDay(for: d) <= calendar.startOfDay(for: date) {
                return calendar.startOfDay(for: d)
            }
        }
        return calendar.startOfDay(for: date)
    }

    /// 候が始まってから何日目か（0 始まり）
    static func dayInKou(on date: Date, calendar: Calendar) -> Int {
        let index = kouIndex(on: date, calendar: calendar)
        let start = startDate(of: index, onOrBefore: date, calendar: calendar)
        return calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// 次の候が始まるまでの日数（今日を含めない）
    static func daysUntilNextKou(on date: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: date)
        for offset in 1...20 {
            guard let d = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            if kouIndex(on: d, calendar: calendar) != kouIndex(on: today, calendar: calendar) { return offset }
        }
        return 5
    }

    /// 今日の季語：その候の季語を、候の中の日ごとに順に渡す
    static func todaysKigo(on date: Date, calendar: Calendar) -> Kigo {
        let kou = kou(on: date, calendar: calendar)
        return kou.kigo[dayInKou(on: date, calendar: calendar) % kou.kigo.count]
    }

    /// 暦の 1 年の始まり（その日より前で、いちばん近い立春）
    static func yearStart(onOrBefore date: Date, calendar: Calendar) -> Date {
        startDate(of: 0, onOrBefore: date, calendar: calendar)
    }
}
