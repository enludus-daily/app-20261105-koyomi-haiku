import SwiftUI

/// 最初の 3 ページ：七十二候 → 一句を詠む → 暦が染まる（と、端末の中だけ）
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @State private var filled: Set<Int> = []
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let current = Almanac.kouIndex(on: .now, calendar: .current)

    var body: some View {
        VStack(spacing: Space.xl) {
            TabView(selection: $page) {
                pageView(
                    title: "一年は、七十二の季節",
                    body: "約五日ごとに、こよみの季節（候）が変わります。いまは「\(Almanac.kous[current].name)」。今日の候と季語が、毎日ひとつ届きます。"
                ) {
                    KoyomiWheel(filled: [current], current: current).frame(maxWidth: 240)
                }
                .tag(0)
                pageView(
                    title: "季語をひとつ、五・七・五で",
                    body: "散歩のお題を手がかりに、見えたもの・聞こえたものを一句に。音の数と季語は、書くそばから数えます。"
                ) {
                    HStack(alignment: .top, spacing: Space.xl) {
                        Tanzaku(lines: ["古池や", "蛙飛びこむ", "水の音"], signature: "芭蕉", width: 80)
                            .rotationEffect(.degrees(-2))
                        VStack(alignment: .leading, spacing: Space.m) {
                            MoraMeter(count: 5, target: 5)
                            MoraMeter(count: 7, target: 7)
                            MoraMeter(count: 5, target: 5)
                            Text("季語は「蛙」（春）").font(Typeset.small).foregroundStyle(palette.deep)
                        }
                        .padding(.top, Space.xxl)
                    }
                }
                .tag(1)
                pageView(
                    title: "短冊が、一年の暦を染めていく",
                    body: "詠んだ候の弧が色づき、一年で 72 の季節を巡ります。翌年は、去年の同じ候の自分の句と並べて読めます。"
                ) {
                    KoyomiWheel(filled: filled, current: current).frame(maxWidth: 240)
                        .onAppear(perform: fill)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: Space.m) {
                if page == 2 {
                    Text("句はこの iPhone の中だけに残ります。Apple Intelligence も端末の中で動き、句を外に送りません。")
                        .font(Typeset.small).foregroundStyle(Ink.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(page < 2 ? "次へ" : "はじめる") {
                    if page < 2 { withAnimation(.easeOut(duration: 0.35)) { page += 1 } } else { onFinish() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .haptic(.selection, trigger: page)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.l)
            .frame(maxWidth: 520)
        }
        .background(Ink.ground)
    }

    private func pageView<Art: View>(title: String, body: String, @ViewBuilder art: () -> Art) -> some View {
        VStack(spacing: Space.xl) {
            Spacer(minLength: Space.l)
            art()
            VStack(spacing: Space.m) {
                Text(title).font(Typeset.title(26)).kerning(-0.5).foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                Text(body).font(Typeset.body).foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .frame(maxWidth: 520)
            Spacer(minLength: Space.xxl)
        }
    }

    /// 暦が少しずつ染まる見本（動きを減らす設定では、一度に染める）
    private func fill() {
        let sample = Set((0..<72).filter { $0 <= current && $0 % 2 == 0 })
        guard !reduceMotion else { filled = sample; return }
        Task {
            for i in sample.sorted() {
                try? await Task.sleep(for: .milliseconds(40))
                withAnimation(.easeOut(duration: 0.2)) { _ = filled.insert(i) }
            }
        }
    }
}
