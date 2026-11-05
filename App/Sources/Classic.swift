import Foundation

struct ClassicVerse: Identifiable, Hashable, Sendable {
    let index: Int
    let lines: [String]
    let kigo: String
    let season: Season
    let poet: String

    var id: Int { index }
    var text: String { lines.joined() }
}

enum Classics {
    static let verses: [ClassicVerse] = ClassicData.raw.split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .enumerated()
        .map { i, line in
            let f = line.split(separator: "|").map(String.init)
            let season = Season.allCases.first { $0.name == f[2] } ?? .spring
            return ClassicVerse(index: i, lines: f[0].split(separator: " ").map(String.init), kigo: f[1], season: season, poet: f[3])
        }
}

/// 毎回同じ並びにできる乱数（スクリーンショットとテストが安定する）
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum QuizMode: String, CaseIterable, Identifiable, Sendable {
    case kigo, season
    var id: String { rawValue }
    var title: String { self == .kigo ? "季語あて" : "季節あて" }
    var lead: String { self == .kigo ? "空いた所に入る季語は？" : "この句の季節は？" }
}

struct QuizQuestion: Identifiable, Hashable, Sendable {
    let verse: ClassicVerse
    let choices: [String]
    let answer: String
    var id: Int { verse.index }

    /// 季語を伏せた句（季語あて）。行をまたぐ季語（「親の / ない雀」）も伏せる
    var maskedLines: [String] {
        var chars = Array(verse.text)
        let kigo = Array(verse.kigo)
        if let at = (0...max(0, chars.count - kigo.count)).first(where: { Array(chars[$0..<min(chars.count, $0 + kigo.count)]) == kigo }) {
            for i in at..<(at + kigo.count) { chars[i] = "〇" }
        }
        var out: [String] = []
        var cursor = 0
        for line in verse.lines {
            out.append(String(chars[cursor..<(cursor + line.count)]))
            cursor += line.count
        }
        return out
    }
}

enum QuizMaker {
    static let roundSize = 10

    static func round(mode: QuizMode, seed: UInt64, verses: [ClassicVerse] = Classics.verses) -> [QuizQuestion] {
        var rng = SeededRandom(seed: seed)
        let picked = Array(verses.shuffled(using: &rng).prefix(roundSize))
        return picked.map { verse in
            switch mode {
            case .season:
                return QuizQuestion(verse: verse, choices: Season.allCases.map(\.name), answer: verse.season.name)
            case .kigo:
                // ほかの季節の季語から 3 つ。季節で見分けられるようにする
                let others = Almanac.allKigo
                    .filter { $0.season != verse.season && $0.word != verse.kigo && !verse.text.contains($0.word) }
                    .shuffled(using: &rng)
                var wrong: [String] = []
                for k in others where !wrong.contains(k.word) {
                    wrong.append(k.word)
                    if wrong.count == 3 { break }
                }
                return QuizQuestion(verse: verse, choices: ([verse.kigo] + wrong).shuffled(using: &rng), answer: verse.kigo)
            }
        }
    }
}

/// 1 回分（10 問）の進み具合
struct QuizRun: Sendable {
    let questions: [QuizQuestion]
    private(set) var current = 0
    private(set) var correct = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var picked: String?

    init(questions: [QuizQuestion]) { self.questions = questions }

    var question: QuizQuestion? { current < questions.count ? questions[current] : nil }
    var isFinished: Bool { current >= questions.count }
    var answered: Bool { picked != nil }

    /// 答える。正解なら true
    @discardableResult
    mutating func answer(_ choice: String) -> Bool {
        guard let q = question, picked == nil else { return false }
        picked = choice
        if choice == q.answer {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            return true
        }
        streak = 0
        return false
    }

    mutating func next() {
        guard picked != nil else { return }
        picked = nil
        current += 1
    }
}
