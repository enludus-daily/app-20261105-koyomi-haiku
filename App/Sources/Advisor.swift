import Foundation
import FoundationModels

enum AdvisorStatus: Equatable, Sendable {
    case available
    /// 使えない理由（画面に出す）
    case unavailable(String)
}

enum AdvisorError: Error, Equatable {
    case emptyVerse
    case emptyResult
}

/// 句を読んで推敲のヒントを返す役。本物は端末の中のモデル（OnDeviceAdvisor）、テストでは偽物に差し替える。
/// 句は書き換えない（ヒントだけ）。
protocol VerseAdvisor: Sendable {
    var status: AdvisorStatus { get }
    func advise(lines: [String], season: Season) async throws -> [String]
}

/// Apple Intelligence の端末の中のモデル（Foundation Models）。通信しない。
/// 使えるかは SystemLanguageModel.availability と supportsLocale(_:) で確かめる
/// （https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel）。
struct OnDeviceAdvisor: VerseAdvisor {
    var status: AdvisorStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "ja_JP"))
                ? .available
                : .unavailable("Apple Intelligence が日本語に対応していない設定です。決まりで作るヒントだけを出します。")
        case .unavailable(.deviceNotEligible):
            return .unavailable("この iPhone は Apple Intelligence に対応していません。決まりで作るヒントだけを出します。")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Apple Intelligence がオフです（設定 › Apple Intelligence と Siri）。決まりで作るヒントだけを出します。")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence のモデルを準備中です。それまでは決まりで作るヒントだけを出します。")
        case .unavailable:
            return .unavailable("Apple Intelligence が使えません。決まりで作るヒントだけを出します。")
        @unknown default:
            return .unavailable("Apple Intelligence が使えません。決まりで作るヒントだけを出します。")
        }
    }

    func advise(lines: [String], season: Season) async throws -> [String] {
        let verse = lines.map { String($0.prefix(30)) }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !verse.isEmpty else { throw AdvisorError.emptyVerse }
        let session = LanguageModelSession(instructions: """
            あなたは、俳句を始めたばかりの人にやさしく寄り添う句会の先輩です。
            利用者の句を読み、推敲のヒントを 3 つ返してください。
            - 句をまるごと書き換えない。言葉を一つ替える・語順を入れ替える、などの小さな提案にとどめる。
            - 一つめは、句の良いところを具体的に一つほめる。
            - 季語・五七五・切れ字・「見えたもの」で気持ちを伝える、のどれかに触れる。
            - それぞれ 40 文字以内の、自然でやわらかい日本語にする。
            """)
        let response = try await session.respond(
            to: "いまの季節：\(season.name)\n句：\(verse)", generating: VerseAdvice.self
        )
        let hints = response.content.hints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
        guard !hints.isEmpty else { throw AdvisorError.emptyResult }
        return Array(hints)
    }
}

@Generable
struct VerseAdvice {
    @Guide(description: "推敲のヒント。ちょうど三つ。一つめは良いところ")
    var hints: [String]
}

/// モデルを使わない（使えない）ときの役
struct UnavailableAdvisor: VerseAdvisor {
    var reason: String
    var status: AdvisorStatus { .unavailable(reason) }
    func advise(lines: [String], season: Season) async throws -> [String] { throw AdvisorError.emptyResult }
}
