import SwiftUI

/// 手本：古典の句で遊ぶ（季語あて・季節あて）。遊びの部分なので、正誤の手応えは少し強め
struct ClassicView: View {
    let scene: ScreenshotScene?

    @State private var mode: QuizMode = .kigo
    @State private var run: QuizRun
    @State private var shake = 0
    @State private var hop = 0
    @AppStorage("quiz.best.kigo") private var bestKigo = 0
    @AppStorage("quiz.best.season") private var bestSeason = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(scene: ScreenshotScene?) {
        self.scene = scene
        var run = QuizRun(questions: QuizMaker.round(mode: .kigo, seed: scene == nil ? UInt64.random(in: 1...UInt64.max) : 2026))
        // スクリーンショット：答えた直後・結果の場面
        if scene == .answered {
            run.answer(run.question?.answer ?? "")
        } else if scene == .result {
            for i in 0..<QuizMaker.roundSize {
                run.answer(i == 3 || i == 7 ? "" : (run.question?.answer ?? ""))
                run.next()
            }
        }
        _run = State(initialValue: run)
    }

    private var best: Int { mode == .kigo ? bestKigo : bestSeason }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("手本").font(Typeset.title(34)).kerning(-1).foregroundStyle(Ink.text)
                        Text("芭蕉・蕪村・一茶・子規たちの \(Classics.verses.count) 句で、季語の勘をやしなう")
                            .font(Typeset.small).foregroundStyle(Ink.sub)
                    }
                    HStack(spacing: Space.s) {
                        ForEach(QuizMode.allCases) { m in
                            Button(m.title) { restart(m) }
                                .buttonStyle(LineButtonStyle(filled: m == mode))
                        }
                        Spacer()
                        Text("最高 \(best) / \(QuizMaker.roundSize)").font(Typeset.small).monospacedDigit().foregroundStyle(Ink.sub)
                    }
                    if let q = run.question {
                        question(q)
                    } else {
                        result
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.l)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Ink.ground)
        }
        .haptic(.error, trigger: shake)
        .haptic(.impact(weight: .light), trigger: hop)
        .haptic(.success, trigger: run.isFinished)
    }

    private func question(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack {
                Text("\(run.current + 1) / \(run.questions.count)").font(Typeset.number(22)).foregroundStyle(Ink.text)
                    .contentTransition(.numericText())
                Spacer()
                if run.streak >= 2 {
                    Text("\(run.streak) 問つづけて").font(Typeset.small).foregroundStyle(palette.deep)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
            }
            Text(mode.lead).font(Typeset.body).foregroundStyle(Ink.sub)
            HStack(alignment: .top, spacing: sizeClass == .regular ? Space.xxl : Space.xl) {
                VStack(spacing: 0) {
                    TanzakuString()
                    Tanzaku(
                        lines: mode == .kigo && !run.answered ? q.maskedLines : q.verse.lines,
                        signature: q.verse.poet, width: sizeClass == .regular ? 140 : 104, seed: UInt64(q.verse.index + 11)
                    )
                    .softShadow()
                    .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, x in
                        view.offset(x: reduceMotion ? 0 : x)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0.0, duration: 0.05)
                            LinearKeyframe(-9.0, duration: 0.05)
                            LinearKeyframe(8.0, duration: 0.05)
                            LinearKeyframe(-6.0, duration: 0.05)
                            LinearKeyframe(5.0, duration: 0.05)
                            LinearKeyframe(-3.0, duration: 0.05)
                            LinearKeyframe(2.0, duration: 0.05)
                            LinearKeyframe(0.0, duration: 0.07)
                        }
                    }
                    .scaleEffect(hop > 0 && run.answered && !reduceMotion ? 1.03 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: run.answered)
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    ForEach(q.choices, id: \.self) { choice in
                        Button { pick(choice) } label: {
                            HStack {
                                Text(choice).font(Typeset.title(18))
                                Spacer(minLength: 0)
                                if run.answered && choice == q.answer { Text("◯").foregroundStyle(palette.deep) }
                                else if run.picked == choice { Text("×").foregroundStyle(Ink.sub) }
                            }
                        }
                        .buttonStyle(LineButtonStyle(filled: run.answered && choice == q.answer))
                        .disabled(run.answered)
                    }
                    if run.answered {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("季語「\(q.verse.kigo)」・\(q.verse.season.name)").font(Typeset.small).foregroundStyle(palette.deep)
                            Text("\(q.verse.lines.joined(separator: " "))　\(q.verse.poet)").font(Typeset.small).foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, Space.xs)
                        Button(run.current + 1 < run.questions.count ? "次の句へ" : "結果を見る") {
                            withAnimation(.easeOut(duration: 0.25)) { run.next() }
                            if run.isFinished { saveBest() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }

    private var result: some View {
        VStack(spacing: Space.l) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text("\(run.correct)")
                    .font(Typeset.number(96)).kerning(-4).foregroundStyle(Ink.text)
                    .contentTransition(.numericText())
                Text("/ \(run.questions.count)").font(Typeset.number(28)).foregroundStyle(Ink.sub)
            }
            .accessibilityElement(children: .combine)
            Text(run.correct == run.questions.count ? "すべて当たりました" : (run.correct >= 7 ? "季語の勘が育っています" : "手本の句は、何度でも出会えます"))
                .font(Typeset.title(20)).foregroundStyle(Ink.text)
            Text("いちばん長く続いた正解 \(run.bestStreak) 問・最高 \(max(best, run.correct)) 問").font(Typeset.small).foregroundStyle(Ink.sub)
            Button("もう一回") { restart(mode) }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xl)
    }

    private func pick(_ choice: String) {
        let correct = withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { run.answer(choice) }
        if correct { hop += 1 } else { shake += 1 }
    }

    private func saveBest() {
        if mode == .kigo { bestKigo = max(bestKigo, run.correct) } else { bestSeason = max(bestSeason, run.correct) }
    }

    private func restart(_ m: QuizMode) {
        withAnimation(.easeOut(duration: 0.25)) {
            mode = m
            run = QuizRun(questions: QuizMaker.round(mode: m, seed: UInt64.random(in: 1...UInt64.max)))
        }
    }
}
