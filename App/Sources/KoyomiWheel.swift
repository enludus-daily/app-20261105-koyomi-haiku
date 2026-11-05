import SwiftUI

/// 七十二候の暦の輪。72 の弧が 1 年。詠んだ候は季節の色に染まり、今の候には差し色の点。
/// 上が立春、時計回りに夏・秋・冬。
struct KoyomiWheel: View {
    let filled: Set<Int>
    let current: Int
    var selected: Int? = nil
    var showsCenter = true
    var onSelect: ((Int) -> Void)? = nil
    @Environment(\.palette) private var palette

    static let gap = 0.45

    static func angle(of index: Int) -> (start: Double, end: Double) {
        let step = 360.0 / 72
        return (Double(index) * step - 90 + gap / 2, Double(index + 1) * step - 90 - gap / 2)
    }

    /// 輪の中の位置から候の番号（中心からの角度で決める）
    static func index(at point: CGPoint, in size: CGSize) -> Int? {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - c.x, dy = point.y - c.y
        let r = min(size.width, size.height) / 2
        let d = (dx * dx + dy * dy).squareRoot()
        guard d > r * 0.5, d <= r * 1.05 else { return nil }
        var deg = atan2(dy, dx) * 180 / .pi + 90
        if deg < 0 { deg += 360 }
        return min(71, Int(deg / 5))
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let outer = side / 2 - 6
                    let inner = outer * 0.72
                    for i in 0..<72 {
                        let a = Self.angle(of: i)
                        var p = Path()
                        p.addArc(center: c, radius: outer, startAngle: .degrees(a.start), endAngle: .degrees(a.end), clockwise: false)
                        p.addArc(center: c, radius: inner, startAngle: .degrees(a.end), endAngle: .degrees(a.start), clockwise: true)
                        p.closeSubpath()
                        if filled.contains(i) {
                            ctx.fill(p, with: .color(palette.accent))
                        } else {
                            ctx.fill(p, with: .color(Ink.paper))
                            ctx.stroke(p, with: .color(Ink.line), lineWidth: 0.6)
                        }
                        if i == selected {
                            ctx.stroke(p, with: .color(palette.deep), lineWidth: 1.4)
                        }
                    }
                    // 節気の区切り（3 候ごと）に細い目盛り
                    for s in 0..<24 {
                        let deg = Double(s) * 15 - 90
                        let rad = deg * .pi / 180
                        var t = Path()
                        t.move(to: CGPoint(x: c.x + cos(rad) * (inner - 4), y: c.y + sin(rad) * (inner - 4)))
                        t.addLine(to: CGPoint(x: c.x + cos(rad) * (inner - (s % 6 == 0 ? 12 : 7)), y: c.y + sin(rad) * (inner - (s % 6 == 0 ? 12 : 7))))
                        ctx.stroke(t, with: .color(Ink.sub.opacity(0.5)), lineWidth: 0.6)
                    }
                    // 今の候の印
                    let mid = (Self.angle(of: current).start + Self.angle(of: current).end) / 2 * .pi / 180
                    let dot = CGPoint(x: c.x + cos(mid) * (outer + 1), y: c.y + sin(mid) * (outer + 1))
                    ctx.fill(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)), with: .color(palette.tint))
                    ctx.stroke(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)), with: .color(.white), lineWidth: 1.2)
                }
                // 季節の字（四隅ではなく、各季節の真ん中の内側）
                ForEach(Season.allCases, id: \.rawValue) { season in
                    let deg = Double(season.rawValue) * 90 + 45 - 90
                    let r = (side / 2 - 6) * 0.58
                    Text(season.name)
                        .font(Typeset.title(side * 0.05))
                        .foregroundStyle(Ink.sub)
                        .offset(x: cos(deg * .pi / 180) * r, y: sin(deg * .pi / 180) * r)
                }
                if showsCenter {
                    VStack(spacing: 2) {
                        Text("\(filled.count)")
                            .font(Typeset.number(side * 0.2))
                            .kerning(-side * 0.008)
                            .foregroundStyle(Ink.text)
                            .contentTransition(.numericText())
                        Text("/ 72 の候").smallCaps()
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let onSelect, let i = Self.index(at: CGPoint(x: location.x - (geo.size.width - side) / 2, y: location.y - (geo.size.height - side) / 2), in: CGSize(width: side, height: side)) else { return }
                onSelect(i)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("七十二候の暦。今年は \(filled.count) の候で詠みました。今は「\(Almanac.kous[current].name)」")
        .accessibilityAddTraits(onSelect == nil ? [] : .isButton)
    }
}
