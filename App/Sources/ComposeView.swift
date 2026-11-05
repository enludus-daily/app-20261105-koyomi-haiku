import SwiftUI

/// 音の数の目盛り：目標の数だけ点、超えた分は差し色の小さな点
struct MoraMeter: View {
    let count: Int
    let target: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(target, count), id: \.self) { i in
                Circle()
                    .fill(i < count ? (i < target ? palette.accent : palette.tint) : Color.clear)
                    .overlay(Circle().stroke(i < target ? Ink.line : palette.tint, lineWidth: 0.6))
                    .frame(width: i < target ? 8 : 6, height: i < target ? 8 : 6)
            }
            Text(count == target ? "ちょうど" : "\(count) / \(target)")
                .font(Typeset.label).monospacedDigit()
                .foregroundStyle(count == target ? palette.deep : Ink.sub)
                .padding(.leading, 2)
        }
        .scaleEffect(count == target ? 1.0 : 0.98, anchor: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
        .accessibilityElement()
        .accessibilityLabel("\(count) 音、目安は \(target) 音")
    }
}

enum AdvicePhase: Equatable {
    case idle, loading
    case done([String])
    case failed
}

struct ComposeView: View {
    let request: ComposeRequest
    let advisor: any VerseAdvisor
    let season: Season
    let onSave: ([String]) -> Void

    @State private var lines: [String]
    @State private var advice: AdvicePhase = .idle
    @FocusState private var focus: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.palette) private var palette

    init(request: ComposeRequest, advisor: any VerseAdvisor, season: Season, onSave: @escaping ([String]) -> Void) {
        self.request = request
        self.advisor = advisor
        self.season = season
        self.onSave = onSave
        _lines = State(initialValue: request.lines)
    }

    private var readings: [String] { lines.map(Mora.reading(of:)) }
    private var counts: [Int] { readings.map(Mora.count) }
    private var exactLines: Int { zip(counts, VerseCoach.targets).filter { $0 == $1 }.count }
    private var allExact: Bool { counts == VerseCoach.targets }
    private var canSave: Bool { lines.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    private var hints: [Hint] { VerseCoach.hints(lines: lines, counts: counts, season: season, todaysKigo: request.kigo) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("季語「\(request.kigo.word)」・\(request.kigo.reading)").font(Typeset.title(20)).foregroundStyle(Ink.text)
                        Text(request.kigo.prompt).font(Typeset.small).foregroundStyle(Ink.sub)
                    }
                    HStack(alignment: .top, spacing: sizeClass == .regular ? Space.xxl : Space.l) {
                        VStack(spacing: 0) {
                            TanzakuString()
                            Tanzaku(lines: shownLines, width: sizeClass == .regular ? 150 : 92, placeholder: lines.allSatisfy(\.isEmpty))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.paper)
                                        .stroke(palette.accent, lineWidth: allExact ? 1.2 : 0)
                                        .animation(.easeOut(duration: 0.25), value: allExact)
                                )
                                .softShadow()
                        }
                        VStack(alignment: .leading, spacing: Space.l) {
                            ForEach(0..<3, id: \.self) { i in lineField(i) }
                        }
                    }
                    hintList
                    aiSection
                    Button("句帳に納める") { onSave(lines) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                    if !canSave {
                        Text("三つの行が埋まると、句帳に納められます").font(Typeset.small).foregroundStyle(Ink.sub)
                    }
                }
                .padding(Space.xl)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Ink.ground)
            .navigationTitle("一句を詠む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
            .haptic(.impact(weight: .light), trigger: exactLines)
            .haptic(.impact(weight: .medium), trigger: allExact)
        }
    }

    /// 何も書いていないときは、季語を上五に置いた見本を薄く出す
    private var shownLines: [String] {
        lines.allSatisfy(\.isEmpty) ? [request.kigo.word + "や", "", ""] : lines
    }

    private func lineField(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(VerseCoach.lineNames[i]).smallCaps()
            TextField(i == 0 ? "\(request.kigo.word)や" : (i == 1 ? "見えたもの・聞こえたもの" : "終わりの五音"), text: $lines[i])
                .font(Typeset.title(20))
                .foregroundStyle(Ink.text)
                .focused($focus, equals: i)
                .submitLabel(i < 2 ? .next : .done)
                .onSubmit { focus = i < 2 ? i + 1 : nil }
                .padding(.vertical, Space.xs)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(focus == i ? palette.accent : Ink.line).frame(height: focus == i ? 1.2 : 0.6)
                }
            MoraMeter(count: counts[i], target: VerseCoach.targets[i])
            if !lines[i].isEmpty, readings[i] != lines[i] {
                Text("読み：\(readings[i])（目安）").font(Typeset.label).foregroundStyle(Ink.sub)
            }
        }
    }

    private var hintList: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("推敲のヒント").smallCaps()
            ForEach(hints) { hint in
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Circle()
                        .fill(hint.kind == .good ? palette.accent : Color.clear)
                        .overlay(Circle().stroke(hint.kind == .suggest ? palette.deep : (hint.kind == .good ? palette.accent : Ink.sub), lineWidth: 0.8))
                        .frame(width: 7, height: 7)
                    Text(hint.text).font(Typeset.body).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: hints)
    }

    @ViewBuilder
    private var aiSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Apple Intelligence の読み").smallCaps()
            switch advisor.status {
            case .unavailable(let reason):
                Text(reason).font(Typeset.small).foregroundStyle(Ink.sub)
            case .available:
                switch advice {
                case .idle:
                    Button("この句を読んでもらう") { Task { await ask() } }
                        .buttonStyle(LineButtonStyle())
                        .disabled(!canSave)
                    Text("端末の中のモデルが、ヒントを 3 つ返します。句は書き換えません。").font(Typeset.small).foregroundStyle(Ink.sub)
                case .loading:
                    HStack(spacing: Space.s) {
                        ProgressView()
                        Text("読んでいます…").font(Typeset.small).foregroundStyle(Ink.sub)
                    }
                case .done(let items):
                    ForEach(items, id: \.self) { text in
                        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                            Text("・").foregroundStyle(palette.deep)
                            Text(text).font(Typeset.body).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("提案です。採るかどうかは、あなたが決めます。").font(Typeset.label).foregroundStyle(Ink.sub)
                    Button("もう一度読んでもらう") { Task { await ask() } }.buttonStyle(LineButtonStyle())
                case .failed:
                    Text("うまく読めませんでした。少し言葉を変えて、もう一度試してください。").font(Typeset.small).foregroundStyle(Ink.sub)
                    Button("もう一度") { Task { await ask() } }.buttonStyle(LineButtonStyle())
                }
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.soft.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
    }

    private func ask() async {
        advice = .loading
        do {
            advice = .done(try await advisor.advise(lines: lines, season: season))
        } catch {
            advice = .failed
        }
    }
}
