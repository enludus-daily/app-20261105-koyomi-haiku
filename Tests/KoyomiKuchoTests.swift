import Foundation
import Testing
@testable import KoyomiKucho

private let tokyo: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return c
}()

private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 9) -> Date {
    tokyo.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

struct AlmanacTests {
    @Test func hasSeventyTwoKouWithFourKigoEach() {
        #expect(Almanac.kous.count == 72)
        #expect(Almanac.kous.allSatisfy { $0.kigo.count == 4 })
        #expect(Almanac.allKigo.count == 288)
        #expect(Almanac.kous.allSatisfy { !$0.name.isEmpty && !$0.reading.isEmpty && !$0.meaning.isEmpty })
    }

    @Test func kigoWordsAreUnique() {
        let words = Almanac.allKigo.map(\.word)
        #expect(Set(words).count == words.count)
    }

    @Test func seasonsFollowTheRisshunOrder() {
        #expect(Almanac.kous[0].name == "東風解凍")
        #expect(Almanac.kous[0].season == .spring)
        #expect(Almanac.kous[18].sekki == "立夏")
        #expect(Almanac.kous[36].season == .autumn)
        #expect(Almanac.kous[71].season == .winter)
        #expect(Almanac.kous[53].phase == "末候")
    }

    @Test(arguments: [
        (2026, 11, 5, "楓蔦黄"), (2026, 11, 7, "山茶始開"), (2026, 2, 4, "東風解凍"), (2026, 2, 3, "鶏始乳"),
        (2027, 1, 2, "雪下出麦"), (2026, 12, 31, "雪下出麦"), (2026, 3, 25, "桜始開"), (2026, 8, 7, "涼風至"),
    ])
    func findsTheKouOfADay(y: Int, m: Int, d: Int, name: String) {
        #expect(Almanac.kou(on: day(y, m, d), calendar: tokyo).name == name)
    }

    @Test func countsDaysInsideAndUntilTheNextKou() {
        // 楓蔦黄は 11/2 から、次の山茶始開は 11/7 から
        #expect(Almanac.dayInKou(on: day(2026, 11, 5), calendar: tokyo) == 3)
        #expect(Almanac.daysUntilNextKou(on: day(2026, 11, 5), calendar: tokyo) == 2)
        // 年をまたぐ候（12/31〜1/4）
        #expect(Almanac.dayInKou(on: day(2027, 1, 2), calendar: tokyo) == 2)
    }

    @Test func todaysKigoRotatesInsideAKou() {
        let a = Almanac.todaysKigo(on: day(2026, 11, 2), calendar: tokyo)
        let b = Almanac.todaysKigo(on: day(2026, 11, 3), calendar: tokyo)
        #expect(a.word == "蔦")
        #expect(b.word == "行く秋")
        #expect(a.kouIndex == b.kouIndex)
    }

    @Test func yearStartsAtRisshun() {
        let start = Almanac.yearStart(onOrBefore: day(2027, 1, 10), calendar: tokyo)
        #expect(tokyo.dateComponents([.year, .month, .day], from: start) == DateComponents(year: 2026, month: 2, day: 4))
    }
}

struct MoraTests {
    @Test(arguments: [
        ("ふるいけや", 5), ("かわずとびこむ", 7), ("みずのおと", 5), ("きゅうしょく", 4), ("がっこう", 4),
        ("コーヒー", 4), ("しゅんらい", 4), ("", 0), ("ちゃ ちゃ", 2),
    ])
    func countsMora(kana: String, expected: Int) {
        #expect(Mora.count(kana) == expected)
    }

    @Test func readingKeepsKanaAndTurnsKatakanaToHiragana() {
        #expect(Mora.reading(of: "ふるいけや") == "ふるいけや")
        #expect(Mora.reading(of: "コンビニ") == "こんびに")
    }

    @Test func readingOfKanjiIsKana() {
        let r = Mora.reading(of: "古池")
        #expect(!r.isEmpty)
        #expect(r.allSatisfy { Mora.isKana($0) || $0 == "ー" })
    }
}

struct KigoFinderTests {
    @Test func findsAKigoByWordOrLongReading() {
        #expect(KigoFinder.find(in: "柿食へば鐘が鳴るなり").map(\.word) == ["柿"])
        #expect(KigoFinder.find(in: "こおろぎや階段の灯の").map(\.word) == ["蟋蟀"])
    }

    @Test func prefersTheLongerKigo() {
        // 「名月」の中の「月」、「秋時雨」の中の「時雨」は数えない
        #expect(KigoFinder.find(in: "名月や池をめぐりて").map(\.word) == ["名月"])
        #expect(KigoFinder.find(in: "秋時雨傘の内側").map(\.word) == ["秋時雨"])
    }

    @Test func shortReadingsDoNotMatch() {
        // 「か（蚊）」は短いので、ひらがなの「か」には反応しない
        #expect(KigoFinder.find(in: "なにかかな").isEmpty)
    }

    @Test func findsSeveralKigo() {
        let found = KigoFinder.find(in: "梅咲いて雪のこる").map(\.word)
        #expect(Set(found) == ["梅", "雪"])
    }
}

struct VerseCoachTests {
    let kigo = Almanac.todaysKigo(on: day(2026, 11, 5), calendar: tokyo)

    private func hints(_ lines: [String], season: Season = .autumn) -> [Hint] {
        VerseCoach.hints(lines: lines, counts: lines.map { Mora.count(Mora.reading(of: $0)) }, season: season, todaysKigo: kigo)
    }

    @Test func emptyVerseSuggestsTodaysKigo() {
        let h = hints(["", "", ""])
        #expect(h.count == 1)
        #expect(h[0].text.contains(kigo.word))
    }

    @Test func exactVerseWithKigoAndKireji() {
        let h = hints(["こおろぎや", "かいだんのひの", "きえるまで"])
        #expect(h.contains { $0.kind == .good && $0.text.contains("ちょうど") })
        #expect(h.contains { $0.kind == .good && $0.text.contains("蟋蟀") })
        #expect(h.contains { $0.kind == .good && $0.text.contains("切れ字「や」") })
        #expect(!h.contains { $0.kind == .suggest })
    }

    @Test func overAndUnderCounts() {
        let h = hints(["あきのそらや", "まどをあけて", "ねこ"])
        #expect(h.contains { $0.text.contains("上五が 6 音（字余り 1）") })
        #expect(h.contains { $0.text.contains("中七が 6 音（あと 1 音）") })
        #expect(h.contains { $0.text.contains("下五が 2 音（あと 3 音）") })
    }

    @Test func noKigoAndTwoKigo() {
        #expect(hints(["ねこがいて", "まどべにすわる", "ひとりきり"]).contains { $0.text.contains("季語が見つかりません") })
        #expect(hints(["梅の花", "雪のこる道", "あるきけり"], season: .spring).contains { $0.text.contains("季重なり") })
    }

    @Test func kigoFromAnotherSeasonAndFeelingWords() {
        let h = hints(["さくらさく", "うれしいあさの", "みちをゆく"])
        #expect(h.contains { $0.kind == .info && $0.text.contains("春の季語") })
        #expect(h.contains { $0.text.contains("「うれし…」") })
    }
}

struct ClassicTests {
    @Test func everyClassicVerseHasThreeLinesAndItsKigo() {
        #expect(Classics.verses.count >= 40)
        for v in Classics.verses {
            #expect(v.lines.count == 3, "\(v.text)")
            #expect(v.text.contains(v.kigo), "\(v.text)")
        }
    }

    @Test func kigoRoundHasTenQuestionsWithTheAnswerAmongFourChoices() {
        let round = QuizMaker.round(mode: .kigo, seed: 1)
        #expect(round.count == QuizMaker.roundSize)
        for q in round {
            #expect(q.choices.count == 4)
            #expect(Set(q.choices).count == 4)
            #expect(q.choices.contains(q.answer))
            #expect(!q.maskedLines.joined().contains(q.answer))
        }
    }

    @Test func sameSeedGivesSameRound() {
        #expect(QuizMaker.round(mode: .kigo, seed: 42) == QuizMaker.round(mode: .kigo, seed: 42))
    }

    @Test func seasonRoundOffersFourSeasons() {
        let q = QuizMaker.round(mode: .season, seed: 3)[0]
        #expect(q.choices == ["春", "夏", "秋", "冬"])
        #expect(q.answer == q.verse.season.name)
    }

    @Test func runCountsCorrectAnswersAndStreaks() {
        var run = QuizRun(questions: QuizMaker.round(mode: .season, seed: 5))
        for i in 0..<QuizMaker.roundSize {
            let q = run.question!
            #expect(run.answer(i == 4 ? "×" : q.answer) == (i != 4))
            #expect(!run.answer(q.answer)) // 二度は答えられない
            run.next()
        }
        #expect(run.isFinished)
        #expect(run.correct == 9)
        #expect(run.bestStreak == 5)
    }
}

struct KuchoTests {
    private func verse(_ y: Int, _ m: Int, _ d: Int) -> Verse {
        let date = day(y, m, d)
        return Verse(date: date, kouIndex: Almanac.kouIndex(on: date, calendar: tokyo), lines: ["a", "b", "c"], kigo: [])
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        let vs = [verse(2026, 11, 3), verse(2026, 11, 4), verse(2026, 11, 5)]
        #expect(KuchoRules.streak(vs, today: day(2026, 11, 5), calendar: tokyo) == 3)
        #expect(KuchoRules.streak(vs, today: day(2026, 11, 6), calendar: tokyo) == 3)
        #expect(KuchoRules.streak(vs, today: day(2026, 11, 7), calendar: tokyo) == 0)
    }

    @Test func kousAndDaysThisYearStartAtRisshun() {
        let vs = [verse(2026, 1, 20), verse(2026, 2, 5), verse(2026, 11, 3), verse(2026, 11, 3)]
        let today = day(2026, 11, 5)
        #expect(KuchoRules.kousThisYear(vs, today: today, calendar: tokyo) == [0, 53])
        #expect(KuchoRules.daysThisYear(vs, today: today, calendar: tokyo) == 2)
    }

    @Test func lastYearFindsTheSameKou() {
        let vs = [verse(2025, 11, 4), verse(2025, 10, 1), verse(2026, 11, 3)]
        let found = KuchoRules.lastYear(vs, today: day(2026, 11, 5), calendar: tokyo)
        #expect(found.count == 1)
        #expect(tokyo.component(.year, from: found[0].date) == 2025)
    }

    @MainActor
    @Test func storeSavesAndReloads() throws {
        let defaults = try #require(UserDefaults(suiteName: "kucho-test-\(UUID())"))
        let store = KuchoStore(defaults: defaults, calendar: tokyo)
        let v = store.add(lines: [" 名月や ", "池をめぐりて", "夜もすがら"], on: day(2026, 9, 20))
        #expect(v.lines[0] == "名月や")
        #expect(v.kigo == ["名月"])
        #expect(v.kou.name == "玄鳥去")
        let reloaded = KuchoStore(defaults: defaults, calendar: tokyo)
        #expect(reloaded.verses == [v])
        reloaded.delete(v)
        #expect(KuchoStore(defaults: defaults, calendar: tokyo).verses.isEmpty)
    }
}

struct ReminderTests {
    @Test func morningTextUsesTheDaysKouAndKigo() {
        let t = Reminder.content(for: day(2026, 11, 7, hour: 7), calendar: tokyo)
        #expect(t.title == "立冬 初候「山茶始開」")
        #expect(t.body.contains("立冬"))
    }
}

struct FakeAdvisor: VerseAdvisor {
    var status: AdvisorStatus = .available
    func advise(lines: [String], season: Season) async throws -> [String] {
        guard lines.contains(where: { !$0.isEmpty }) else { throw AdvisorError.emptyVerse }
        return ["「\(lines[0])」の切れがよい", "中七を具体的に", "季語は\(season.name)"]
    }
}

struct AdvisorTests {
    @Test func fakeAdvisorReturnsThreeHints() async throws {
        let hints = try await FakeAdvisor().advise(lines: ["こおろぎや", "階段の灯の", "消えるまで"], season: .autumn)
        #expect(hints.count == 3)
    }

    @Test func unavailableAdvisorExplainsWhy() async {
        let a = UnavailableAdvisor(reason: "非対応")
        #expect(a.status == .unavailable("非対応"))
        await #expect(throws: AdvisorError.emptyResult) { try await a.advise(lines: ["a"], season: .autumn) }
    }
}
