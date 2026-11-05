import SwiftUI

/// 縦書きの 1 行。長音・括弧は 90° 回し、小さい仮名と句読点は右上へ寄せる
struct VerticalLine: View {
    let text: String
    let size: CGFloat
    var color: Color = Ink.text

    static let rotated: Set<Character> = Set("ー—―〜～…‥（）()「」『』-~")
    static let punctuation: Set<Character> = Set("、。，．")

    var body: some View {
        VStack(spacing: size * 0.08) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                glyph(ch)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func glyph(_ ch: Character) -> some View {
        let t = Text(String(ch)).font(Typeset.title(size)).foregroundStyle(color)
        if ch == " " || ch == "　" {
            Color.clear.frame(width: size, height: size * 0.5)
        } else if Self.rotated.contains(ch) {
            t.rotationEffect(.degrees(90)).frame(width: size, height: size)
        } else if Self.punctuation.contains(ch) {
            t.offset(x: size * 0.55, y: -size * 0.5).frame(width: size, height: size * 0.6)
        } else if Mora.smallKana.contains(ch) || "っッ".contains(ch) {
            t.offset(x: size * 0.12, y: -size * 0.1).frame(width: size, height: size)
        } else {
            t.frame(width: size, height: size)
        }
    }
}

/// 短冊の上下の雲（打曇り）。ゆるい波の帯
struct CloudBand: Shape {
    var top = true

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let edge = top ? rect.minY : rect.maxY
        let wave = top ? rect.maxY : rect.minY
        p.move(to: CGPoint(x: rect.minX, y: edge))
        p.addLine(to: CGPoint(x: rect.minX, y: wave - (top ? h * 0.25 : -h * 0.25)))
        p.addCurve(
            to: CGPoint(x: rect.minX + w * 0.5, y: wave - (top ? h * 0.1 : -h * 0.1)),
            control1: CGPoint(x: rect.minX + w * 0.15, y: wave + (top ? h * 0.05 : -h * 0.05)),
            control2: CGPoint(x: rect.minX + w * 0.3, y: wave - (top ? h * 0.45 : -h * 0.45))
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: wave - (top ? h * 0.35 : -h * 0.35)),
            control1: CGPoint(x: rect.minX + w * 0.7, y: wave + (top ? h * 0.25 : -h * 0.25)),
            control2: CGPoint(x: rect.minX + w * 0.88, y: wave - (top ? h * 0.05 : -h * 0.05))
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: edge))
        p.closeSubpath()
        return p
    }
}

/// 和紙の繊維（固定の乱数で毎回同じ）
struct WashiFibers: View {
    var seed: UInt64 = 7
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let n = Int(size.width * size.height / 900)
            for _ in 0..<max(n, 12) {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let len = Double.random(in: 4...12, using: &rng)
                let angle = Double.random(in: 0...(2 * .pi), using: &rng)
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addQuadCurve(
                    to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len),
                    control: CGPoint(x: x + cos(angle + 0.6) * len * 0.5, y: y + sin(angle + 0.6) * len * 0.5)
                )
                ctx.stroke(p, with: .color(Ink.sub.opacity(0.09)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 短冊。縦長の紙に、上の雲（季節の色）と下の雲（差し色）、穴と紐。
/// 句は 2 行の散らし書き：右に上五と中七、左に下五を少し下げて書く。
struct Tanzaku: View {
    let lines: [String]
    var signature: String? = nil
    var width: CGFloat = 120
    var placeholder = false
    var seed: UInt64 = 7
    @Environment(\.palette) private var palette

    /// 短冊の縦横比（実物は 6 × 36 cm）
    static let ratio: CGFloat = 4.6

    private var height: CGFloat { width * Self.ratio }

    private var columns: (right: String, left: String) {
        let l = lines + Array(repeating: "", count: max(0, 3 - lines.count))
        return (l[0] + (l[0].isEmpty || l[1].isEmpty ? "" : " ") + l[1], l[2])
    }

    private var glyph: CGFloat {
        let longest = max(columns.right.count, columns.left.count + 4, 12)
        return min(width * 0.26, (height * 0.72) / (CGFloat(longest) * 1.08))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Ink.paper)
            WashiFibers(seed: seed)
            CloudBand(top: true).fill(palette.accent.opacity(0.55)).frame(height: height * 0.12)
            VStack {
                Spacer()
                CloudBand(top: false).fill(palette.tint.opacity(0.35)).frame(height: height * 0.09)
            }
            // 穴
            Circle().stroke(Ink.line, lineWidth: 0.8).background(Circle().fill(Ink.ground))
                .frame(width: width * 0.07, height: width * 0.07)
                .offset(y: height * 0.035)
            HStack(alignment: .top, spacing: glyph * 0.5) {
                VStack(spacing: 0) {
                    Spacer().frame(height: glyph * 4)
                    VerticalLine(text: columns.left, size: glyph, color: placeholder ? Ink.sub.opacity(0.5) : Ink.text)
                    if let signature {
                        VerticalLine(text: signature, size: glyph * 0.5, color: Ink.sub)
                            .padding(.top, glyph * 0.6)
                    }
                }
                VerticalLine(text: columns.right, size: glyph, color: placeholder ? Ink.sub.opacity(0.5) : Ink.text)
            }
            .padding(.top, height * 0.15)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.paper, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.paper, style: .continuous).stroke(Ink.line, lineWidth: 0.6))
        .accessibilityElement()
        .accessibilityLabel(lines.filter { !$0.isEmpty }.joined(separator: "、") + (signature.map { "。\($0)" } ?? ""))
    }
}

/// 紐（短冊を吊るす細い線）
struct TanzakuString: View {
    var length: CGFloat = 26
    @Environment(\.palette) private var palette
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: 0, y: length), control: CGPoint(x: 4, y: length * 0.5))
        }
        .stroke(palette.deep.opacity(0.6), lineWidth: 0.8)
        .frame(width: 4, height: length)
        .accessibilityHidden(true)
    }
}
