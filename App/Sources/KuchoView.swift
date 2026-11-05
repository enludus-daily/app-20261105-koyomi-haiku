import SwiftUI

struct KuchoView: View {
    let store: KuchoStore
    let scene: ScreenshotScene?
    let startWriting: () -> Void

    @State private var selectedKou: Int?
    @State private var detail: Verse?
    @State private var handledScene = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.palette) private var palette

    private var now: Date { .now }
    private var current: Int { Almanac.kouIndex(on: now, calendar: store.calendar) }
    private var shown: [Verse] {
        guard let selectedKou else { return store.sorted }
        return store.sorted.filter { $0.kouIndex == selectedKou }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("句帳").font(Typeset.title(34)).kerning(-1).foregroundStyle(Ink.text)
                        Text("今年 \(store.daysThisYear(today: now)) 日・\(store.kousThisYear(today: now).count) の候・ぜんぶで \(store.verses.count) 句")
                            .font(Typeset.small).foregroundStyle(Ink.sub)
                    }
                    if store.verses.isEmpty {
                        emptyState
                    } else if sizeClass == .regular {
                        HStack(alignment: .top, spacing: Space.xxl) {
                            VStack(spacing: Space.l) { wheel; selectionInfo }.frame(width: 360)
                            grid
                        }
                    } else {
                        wheel.frame(maxWidth: 300).frame(maxWidth: .infinity)
                        selectionInfo
                        grid
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.l)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
            .background(Ink.ground)
        }
        .sheet(item: $detail) { verse in
            VerseDetailView(verse: verse) { store.delete(verse); detail = nil }
        }
        .onAppear {
            guard !handledScene else { return }
            handledScene = true
            if scene == .detail { detail = store.sorted.first }
        }
    }

    private var wheel: some View {
        KoyomiWheel(filled: store.kousThisYear(today: now), current: current, selected: selectedKou) { index in
            withAnimation(.easeOut(duration: 0.25)) { selectedKou = selectedKou == index ? nil : index }
        }
        .haptic(.selection, trigger: selectedKou)
    }

    @ViewBuilder
    private var selectionInfo: some View {
        if let selectedKou {
            let kou = Almanac.kous[selectedKou]
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kou.name).font(Typeset.title(20)).foregroundStyle(Ink.text)
                    Text("\(kou.sekki)・\(kou.phase)・\(kou.startLabel)").font(Typeset.small).foregroundStyle(Ink.sub)
                }
                Spacer()
                Button("すべて") { withAnimation(.easeOut(duration: 0.25)) { self.selectedKou = nil } }
                    .buttonStyle(LineButtonStyle())
            }
        } else {
            Text("輪の弧をさわると、その候の句だけを見られます").font(Typeset.small).foregroundStyle(Ink.sub)
        }
    }

    @ViewBuilder
    private var grid: some View {
        if shown.isEmpty, let selectedKou {
            let kou = Almanac.kous[selectedKou]
            Text("「\(kou.name)」の句は、まだありません。\(kou.startLabel)に、また巡ってきます。")
                .font(Typeset.body).foregroundStyle(Ink.sub)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Space.l)], alignment: .leading, spacing: Space.xl) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { offset, verse in
                    Button { detail = verse } label: {
                        VStack(spacing: Space.s) {
                            Tanzaku(lines: verse.lines, width: 72, seed: UInt64(offset + 1))
                                .rotationEffect(.degrees(offset % 5 == 2 ? -1.5 : 0))
                                .softShadow()
                            Text(verse.date.formatted(.dateTime.month().day()))
                                .font(Typeset.label).monospacedDigit().foregroundStyle(Ink.sub)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(verse.lines.joined(separator: "、"))。\(verse.date.formatted(.dateTime.month().day()))")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.xl) {
            HStack(alignment: .top, spacing: Space.xl) {
                Tanzaku(lines: ["古池や", "蛙飛びこむ", "水の音"], signature: "芭蕉", width: 86, placeholder: true)
                    .rotationEffect(.degrees(-2))
                KoyomiWheel(filled: [], current: current, showsCenter: false)
                    .frame(width: 170)
            }
            Text("句帳はまだ白紙です。今日の季語で一句詠むと、ここに短冊が並び、暦の輪がひとつ染まります。")
                .font(Typeset.body).foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("今日の季語で詠む", action: startWriting)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xl)
    }
}

struct VerseDetailView: View {
    let verse: Verse
    let onDelete: () -> Void
    @State private var confirming = false
    @State private var shareImage: Image?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    VStack(spacing: 0) {
                        TanzakuString(length: 34)
                        Tanzaku(lines: verse.lines, width: 132)
                            .rotationEffect(.degrees(-1.5))
                            .liftShadow()
                    }
                    VStack(spacing: Space.xs) {
                        Text(verse.kou.name).font(Typeset.title(24)).kerning(-0.5).foregroundStyle(Ink.text)
                        Text("\(verse.kou.reading)・\(verse.kou.sekki) \(verse.kou.phase)").font(Typeset.small).foregroundStyle(Ink.sub)
                        Text(verse.date.formatted(.dateTime.year().month().day().weekday())).font(Typeset.small).foregroundStyle(Ink.sub)
                        if !verse.kigo.isEmpty {
                            Text("季語：\(verse.kigo.joined(separator: "・"))").font(Typeset.small).foregroundStyle(palette.deep)
                                .padding(.top, Space.xs)
                        }
                    }
                    HStack(spacing: Space.m) {
                        if let shareImage {
                            ShareLink(item: shareImage, preview: SharePreview(verse.lines.joined(separator: " "), image: shareImage)) {
                                Label("画像で残す", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(LineButtonStyle())
                        }
                        Button(role: .destructive) { confirming = true } label: {
                            Label("句帳から外す", systemImage: "trash")
                        }
                        .buttonStyle(LineButtonStyle())
                    }
                }
                .padding(Space.xl)
                .frame(maxWidth: .infinity)
            }
            .background(Ink.ground)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
            .confirmationDialog("この短冊を句帳から外しますか？", isPresented: $confirming, titleVisibility: .visible) {
                Button("外す", role: .destructive, action: onDelete)
            } message: {
                Text("外した句は戻せません。")
            }
            .task { renderShareImage() }
        }
    }

    /// 共有用の画像（360×640 を 3 倍 → 1080×1920）
    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: ShareCard(verse: verse).environment(\.palette, palette))
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

struct ShareCard: View {
    let verse: Verse
    var body: some View {
        VStack(spacing: Space.l) {
            Spacer()
            TanzakuString(length: 30)
            Tanzaku(lines: verse.lines, width: 104).padding(.top, -2)
            VStack(spacing: 4) {
                Text(verse.kou.name).font(Typeset.title(20)).foregroundStyle(Ink.text)
                Text(verse.date.formatted(.dateTime.year().month().day())).font(.system(size: 11)).foregroundStyle(Ink.sub)
            }
            Spacer()
            Text("こよみ句帳").font(.system(size: 10)).kerning(0.6).foregroundStyle(Ink.sub)
                .padding(.bottom, Space.l)
        }
        .frame(width: 360, height: 640)
        .background(Ink.ground)
    }
}
