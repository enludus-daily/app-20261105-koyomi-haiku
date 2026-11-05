import SwiftUI

/// 色・書体・形を 1 か所で決める（app-quality-bar look.md）。
/// アプリの色は 1 系統：いまの季節の色（春 桜・夏 空・秋 柿・冬 藤）を全画面で使う。季節が変わると色も変わる。
/// 主な色は明度 0.72〜0.86、deep は彩度 0.5 以下（scripts/tone-check.py で確かめる）。
struct SeasonPalette: Equatable, Sendable {
    let name: String
    /// 主な色（広い面・暦の輪・短冊の雲）
    let accent: Color
    /// 淡い地（選択中・札の地）
    let soft: Color
    /// 白い文字を載せるボタンと小さな文字だけ
    let deep: Color
    /// 差し色（短冊の下の雲・今の候の印）。1 画面に少しだけ
    let tint: Color

    static func of(_ season: Season) -> SeasonPalette {
        switch season {
        case .spring:
            SeasonPalette(name: "桜", accent: Color(hex: 0xF1BFCB), soft: Color(hex: 0xFBEAEE), deep: Color(hex: 0xA86F7C), tint: Color(hex: 0x9EC3E2))
        case .summer:
            SeasonPalette(name: "空", accent: Color(hex: 0x9EC3E2), soft: Color(hex: 0xE1EDF6), deep: Color(hex: 0x5E8DB8), tint: Color(hex: 0xF4BBA4))
        case .autumn:
            SeasonPalette(name: "柿", accent: Color(hex: 0xF4BBA4), soft: Color(hex: 0xFBE8E0), deep: Color(hex: 0xB5765E), tint: Color(hex: 0x9EC3E2))
        case .winter:
            SeasonPalette(name: "藤", accent: Color(hex: 0xC9BFEA), soft: Color(hex: 0xEEEAF8), deep: Color(hex: 0x7D72A8), tint: Color(hex: 0xF4BBA4))
        }
    }
}

enum Ink {
    /// 地（ほぼ白、わずかに青）
    static let ground = Color(hex: 0xF3F6F9)
    /// 紙（短冊・札）
    static let paper = Color(hex: 0xFBFBF9)
    static let text = Color(hex: 0x2E3A46)
    static let sub = Color(hex: 0x8E9AA6)
    static let line = Color(hex: 0xE3E9EF)
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    /// 短冊・札（紙の角はほとんど丸くない）
    static let paper: CGFloat = 3
    static let chip: CGFloat = 6
    static let button: CGFloat = 14
    static let panel: CGFloat = 18
}

enum Typeset {
    /// 見出しと大きな数字はセリフ（明朝）。字間を詰める
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .light, design: .serif).monospacedDigit() }
    /// 本文はサンセリフ。Dynamic Type に追従する
    static let body = Font.system(.subheadline)
    static let small = Font.system(.footnote)
    static let label = Font.system(.caption2, weight: .medium)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// いまの季節の色。設定で固定もできる（自動 = 今日の候の季節）
struct PaletteKey: EnvironmentKey {
    static let defaultValue = SeasonPalette.of(.autumn)
}

extension EnvironmentValues {
    var palette: SeasonPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// 小さなラベル（字間を開ける）
struct SmallCaps: ViewModifier {
    func body(content: Content) -> some View {
        content.font(Typeset.label).kerning(0.6).foregroundStyle(Ink.sub)
    }
}

/// 主なボタン：deep の地に白い文字、高さ 52、押すと 0.97 倍
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(palette.deep.opacity(enabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 細い線のボタン（選択肢・脇の操作）
struct LineButtonStyle: ButtonStyle {
    var filled = false
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline))
            .foregroundStyle(Ink.text)
            .padding(.horizontal, Space.l)
            .frame(minHeight: 44)
            .background(filled ? palette.soft : Ink.paper, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).stroke(filled ? palette.accent : Ink.line, lineWidth: 0.8))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func smallCaps() -> some View { modifier(SmallCaps()) }

    /// 振動（設定でオフにできる）
    func haptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger))
    }

    /// 弱い影（普段）
    func softShadow() -> some View { shadow(color: Ink.text.opacity(0.07), radius: 10, y: 4) }
    /// 浮いた物（短冊を持ち上げたとき）
    func liftShadow() -> some View { shadow(color: Ink.text.opacity(0.16), radius: 8, y: 6) }
}

struct HapticModifier<T: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: T
    @AppStorage("settings.haptics") private var enabled = true

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}
