import SwiftUI

struct ComposeRequest: Identifiable {
    let id = UUID()
    let kigo: Kigo
    var lines: [String] = ["", "", ""]
}

struct TodayView: View {
    let store: KuchoStore
    let advisor: any VerseAdvisor
    let scene: ScreenshotScene?
    let openKucho: () -> Void

    @State private var compose: ComposeRequest?
    @State private var showingSettings = false
    @State private var justSaved: Verse?
    @State private var handledScene = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var now: Date { .now }
    private var calendar: Calendar { store.calendar }
    private var kou: Kou { Almanac.kou(on: now, calendar: calendar) }
    private var kigo: Kigo { Almanac.todaysKigo(on: now, calendar: calendar) }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if sizeClass == .regular {
                        // iPhone Duo の内側など広い画面：左に今日、右に暦の輪と積み上げ
                        HStack(alignment: .top, spacing: Space.xxl) {
                            VStack(alignment: .leading, spacing: Space.xl) { todayColumn }
                                .frame(maxWidth: 440)
                            VStack(alignment: .leading, spacing: Space.xl) { yearColumn }
                                .frame(maxWidth: 420)
                        }
                        .frame(maxWidth: 960)
                    } else {
                        VStack(alignment: .leading, spacing: Space.xl) {
                            todayColumn
                            yearColumn
                        }
                        .frame(maxWidth: 560)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.l)
                .frame(maxWidth: .infinity)
            }
            .background(Ink.ground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(Ink.sub)
                    }
                    .accessibilityLabel("設定")
                }
            }
            .overlay { if let justSaved { SavedOverlay(verse: justSaved, kous: store.kousThisYear().count) } }
        }
        .sheet(item: $compose) { request in
            ComposeView(request: request, advisor: advisor, season: kou.season) { lines in
                let verse = store.add(lines: lines)
                compose = nil
                showSaved(verse)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(advisor: advisor)
        }
        .onAppear(perform: openScreenshotScene)
    }

    // MARK: 今日

    @ViewBuilder
    private var todayColumn: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(now.formatted(.dateTime.month().day().weekday(.wide)))
                .smallCaps()
            Text("\(kou.sekki)・\(kou.phase)").smallCaps()
        }
        kouHero
        kigoFuda
        otherKigo
    }

    private var kouHero: some View {
        let day = Almanac.dayInKou(on: now, calendar: calendar)
        let left = Almanac.daysUntilNextKou(on: now, calendar: calendar)
        let next = Almanac.kous[(kou.index + 1) % 72]
        return VStack(alignment: .leading, spacing: Space.s) {
            if day == 0 {
                Text("今日から、新しい候").font(Typeset.small).foregroundStyle(palette.deep)
            }
            Text(kou.name)
                .font(Typeset.title(44))
                .kerning(-1.5)
                .foregroundStyle(Ink.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(kou.reading).font(Typeset.small).kerning(0.6).foregroundStyle(Ink.sub)
            Text(kou.meaning).font(Typeset.body).foregroundStyle(Ink.text)
                .padding(.top, Space.xs)
            HStack(spacing: Space.s) {
                HStack(spacing: 5) {
                    ForEach(0..<(day + left), id: \.self) { i in
                        Capsule()
                            .fill(i <= day ? palette.accent : Ink.line)
                            .frame(width: i == day ? 18 : 8, height: 4)
                    }
                }
                Text("次の候「\(next.name)」まで あと \(left) 日")
                    .font(Typeset.small).foregroundStyle(Ink.sub)
            }
            .padding(.top, Space.xs)
            .accessibilityElement(children: .combine)
        }
    }

    /// 今日の季語の札
    private var kigoFuda: some View {
        let wrote = store.wroteToday(now)
        return VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .top, spacing: Space.l) {
                ZStack(alignment: .top) {
                    Rectangle().fill(Ink.paper)
                    WashiFibers(seed: 3)
                    CloudBand(top: true).fill(palette.accent.opacity(0.55)).frame(height: 22)
                    VerticalLine(text: kigo.word, size: 30)
                        .padding(.top, 34)
                }
                .frame(width: 64, height: max(170, CGFloat(kigo.word.count) * 34 + 60))
                .clipShape(RoundedRectangle(cornerRadius: Radius.paper))
                .overlay(RoundedRectangle(cornerRadius: Radius.paper).stroke(Ink.line, lineWidth: 0.6))
                .rotationEffect(.degrees(-2))
                .softShadow()
                .accessibilityLabel("今日の季語 \(kigo.word)")

                VStack(alignment: .leading, spacing: Space.s) {
                    Text("今日の季語").smallCaps()
                    Text(kigo.reading).font(Typeset.small).kerning(0.6).foregroundStyle(Ink.sub)
                    Text("\(kigo.season.name)の季語").font(Typeset.small).foregroundStyle(palette.deep)
                    Rectangle().fill(Ink.line).frame(height: 0.6).padding(.vertical, Space.xs)
                    Text("散歩のお題").smallCaps()
                    Text(kigo.prompt).font(Typeset.body).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if wrote {
                Label("今日の一句は、句帳に納めました", systemImage: "checkmark")
                    .font(Typeset.small).foregroundStyle(palette.deep)
            }
            Button(wrote ? "もう一句、詠む" : "この季語で詠む") { compose = ComposeRequest(kigo: kigo) }
                .buttonStyle(PrimaryButtonStyle())
                .haptic(.selection, trigger: compose?.id)
            if store.verses.isEmpty {
                // はじめての一句の案内（句帳が空のあいだだけ）
                HStack(alignment: .top, spacing: Space.s) {
                    Text("初").font(Typeset.title(13)).foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(palette.deep, in: Circle())
                    Text("はじめての一句は、散歩のお題で見つけたものを一つ、季語と並べるだけ。季語「\(kigo.word)」を上五に置くと書きはじめやすくなります。")
                        .font(Typeset.small).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.m)
                .background(palette.soft.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
        }
    }

    private var otherKigo: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("この候の季語（\(kou.kigo.count)）").smallCaps()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(kou.kigo, id: \.word) { k in
                        Button { compose = ComposeRequest(kigo: k) } label: {
                            Text(k.word).font(Typeset.title(15))
                        }
                        .buttonStyle(LineButtonStyle(filled: k.word == kigo.word))
                        .accessibilityLabel("\(k.word)で詠む")
                    }
                }
            }
        }
    }

    // MARK: 積み上げ

    @ViewBuilder
    private var yearColumn: some View {
        let kous = store.kousThisYear(today: now)
        HStack(spacing: 0) {
            stat(store.streak(today: now), "続けた日")
            Rectangle().fill(Ink.line).frame(width: 0.6, height: 36)
            stat(store.daysThisYear(today: now), "今年 詠んだ日")
            Rectangle().fill(Ink.line).frame(width: 0.6, height: 36)
            stat(kous.count, "詠んだ候")
        }
        Button(action: openKucho) {
            VStack(spacing: Space.m) {
                KoyomiWheel(filled: kous, current: kou.index)
                    .frame(maxWidth: sizeClass == .regular ? 380 : 260)
                Text("句帳をひらく").font(Typeset.small).foregroundStyle(palette.deep)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        if let last = store.lastYear(today: now).first {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("去年の「\(kou.name)」に詠んだ句").smallCaps()
                HStack(alignment: .top, spacing: Space.l) {
                    Tanzaku(lines: last.lines, width: 60)
                    Text(last.date.formatted(.dateTime.year().month().day())).font(Typeset.small).foregroundStyle(Ink.sub)
                }
            }
        } else if let recent = store.sorted.first {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("いちばん新しい短冊").smallCaps()
                HStack(alignment: .top, spacing: Space.l) {
                    Tanzaku(lines: recent.lines, width: 60)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(recent.kou.name).font(Typeset.title(17)).foregroundStyle(Ink.text)
                        Text(recent.date.formatted(.dateTime.month().day())).font(Typeset.small).foregroundStyle(Ink.sub)
                        Text("一年たつと、ここに去年の同じ候の句が出ます").font(Typeset.small).foregroundStyle(Ink.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else {
            Text("一句詠むと、暦の輪がひとつ染まります。72 の候を、一年かけて巡ります。")
                .font(Typeset.small).foregroundStyle(Ink.sub)
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(Typeset.number(30)).kerning(-1).foregroundStyle(Ink.text)
                .contentTransition(.numericText())
            Text(label).smallCaps()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func showSaved(_ verse: Verse) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { justSaved = verse }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.easeOut(duration: 0.35)) { justSaved = nil }
        }
    }

    private func openScreenshotScene() {
        guard !handledScene else { return }
        handledScene = true
        switch scene {
        case .compose:
            compose = ComposeRequest(kigo: kigo, lines: ["冷やかや", "改札を出る", "人の肩"])
        case .saved:
            justSaved = store.sorted.first
        case .settings:
            showingSettings = true
        default:
            break
        }
    }
}

/// 句帳に納めた瞬間：短冊が少し傾いて置かれ、暦の数が増える
struct SavedOverlay: View {
    let verse: Verse
    let kous: Int
    @Environment(\.palette) private var palette
    @State private var placed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Ink.ground.opacity(0.86).ignoresSafeArea()
            VStack(spacing: Space.l) {
                TanzakuString()
                Tanzaku(lines: verse.lines, width: 80)
                    .rotationEffect(.degrees(placed ? -3 : 0))
                    .offset(y: placed ? 0 : -24)
                    .liftShadow()
                Text("句帳に納めました").font(Typeset.title(20)).foregroundStyle(Ink.text)
                Text("\(verse.kou.name)・今年 \(kous) の候").font(Typeset.small).foregroundStyle(Ink.sub)
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { placed = true }
        }
        .haptic(.success, trigger: placed)
        .accessibilityElement(children: .combine)
    }
}
