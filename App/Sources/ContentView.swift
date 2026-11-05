import SwiftUI

/// CI のスクリーンショットで開く画面（起動引数 -screenshotScene <名前> は UserDefaults の引数ドメインに入る）
enum ScreenshotScene: String {
    case launch, onboarding, today, compose, saved, kucho, detail, quiz, answered, result, settings, empty

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }

    /// 見本の句帳を入れて開くか（空の画面とオンボーディングは入れない）
    var usesDemo: Bool { self != .empty && self != .onboarding }
}

enum AppTab: Hashable { case today, kucho, classic }

struct ContentView: View {
    @State private var store: KuchoStore
    @State private var tab: AppTab
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("settings.palette") private var paletteSetting = "auto"
    @AppStorage("settings.reminder") private var reminderOn = false
    @AppStorage("settings.reminderMinutes") private var reminderMinutes = 7 * 60 + 30
    @Environment(\.scenePhase) private var scenePhase
    private let advisor: any VerseAdvisor
    private let scene = ScreenshotScene.current

    init() {
        let scene = ScreenshotScene.current
        if let scene {
            _store = State(initialValue: KuchoStore(defaults: nil, seed: scene.usesDemo ? DemoKucho.verses() : []))
        } else {
            _store = State(initialValue: KuchoStore())
        }
        switch scene {
        case .kucho, .detail, .empty: _tab = State(initialValue: .kucho)
        case .quiz, .answered, .result: _tab = State(initialValue: .classic)
        default: _tab = State(initialValue: .today)
        }
        // スクリーンショットでは、端末によって変わる Apple Intelligence の表示を固定する
        advisor = scene == nil
            ? OnDeviceAdvisor()
            : UnavailableAdvisor(reason: "Apple Intelligence が使えない端末では、決まりで作るヒントだけを出します。")
    }

    private var palette: SeasonPalette {
        if let season = Season.allCases.first(where: { "\($0)" == paletteSetting }) { return .of(season) }
        return .of(Almanac.kou(on: .now, calendar: .current).season)
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("今日", systemImage: "leaf", value: AppTab.today) {
                TodayView(store: store, advisor: advisor, scene: scene, openKucho: { tab = .kucho })
            }
            Tab("句帳", systemImage: "book.closed", value: AppTab.kucho) {
                KuchoView(store: store, scene: scene, startWriting: { tab = .today })
            }
            Tab("手本", systemImage: "text.book.closed", value: AppTab.classic) {
                ClassicView(scene: scene)
            }
        }
        .tint(palette.deep)
        .environment(\.palette, palette)
        // 短冊の紙と墨の世界観は明るい地で作っている（StudyReel と同じく light に固定）
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: onboardingShown) {
            OnboardingView { onboarded = true }
                .environment(\.palette, palette)
        }
        .onChange(of: scenePhase) { _, phase in
            // 開くたびに、先の 14 日分のお知らせを今日の季語で入れ直す
            guard phase == .active, reminderOn, scene == nil else { return }
            Task { await Reminder.schedule(hour: reminderMinutes / 60, minute: reminderMinutes % 60) }
        }
    }

    private var onboardingShown: Binding<Bool> {
        Binding(
            get: { scene == .onboarding || (scene == nil && !onboarded) },
            set: { shown in if !shown { onboarded = true } }
        )
    }
}

/// スクリーンショット用の見本の句帳（このアプリのために作った句）
enum DemoKucho {
    static let items: [(daysAgo: Int, lines: [String])] = [
        (1, ["蔦あかく", "ひと筋ごとに", "影を持つ"]),
        (2, ["行く秋の", "改札に置く", "てのひらよ"]),
        (3, ["冷やかや", "ポストの口の", "暗さかな"]),
        (5, ["紅葉して", "坂の途中の", "自転車屋"]),
        (8, ["秋時雨", "傘の内側", "まだ乾く"]),
        (12, ["きのこ生え", "公園の木の", "根の深さ"]),
        (17, ["こおろぎや", "階段の灯の", "消えるまで"]),
        (24, ["菊の鉢", "並べて朝の", "八百屋かな"]),
        (31, ["雁わたる", "ビルの谷間の", "うすあかり"]),
        (36, ["金木犀", "角を曲がれば", "また香る"]),
        (44, ["秋晴や", "洗濯ばさみ", "みな光る"]),
        (52, ["鰯雲", "校庭の端", "まで続く"]),
        (58, ["名月や", "コンビニの灯の", "ほそき影"]),
        (66, ["すすき揺れ", "川の向こうの", "帰り道"]),
        (75, ["赤とんぼ", "止まる一瞬", "空静か"]),
        (84, ["秋風や", "駅のホームの", "長き影"]),
        (93, ["蜩や", "宿題の山", "まだ高し"]),
        (110, ["炎天の", "横断歩道", "白く跳ね"]),
        (128, ["風鈴の", "鳴らぬ午後なり", "本を閉づ"]),
        (150, ["紫陽花や", "雨の匂いの", "通学路"]),
        (200, ["桜咲く", "まだ硬い靴", "鳴らしけり"]),
        (240, ["梅一つ", "ほどけて坂の", "明るさよ"]),
    ]

    static func verses(now: Date = .now, calendar: Calendar = .current) -> [Verse] {
        items.compactMap { item in
            guard let d = calendar.date(byAdding: .day, value: -item.daysAgo, to: now) else { return nil }
            return Verse(
                date: d, kouIndex: Almanac.kouIndex(on: d, calendar: calendar), lines: item.lines,
                kigo: KigoFinder.find(in: item.lines.joined()).map(\.word)
            )
        }
    }
}

#Preview {
    ContentView()
}
