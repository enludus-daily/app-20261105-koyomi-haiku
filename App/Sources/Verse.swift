import Foundation

/// 音（モーラ）の数え方。拗音の小さい字（ゃ・ゅ・ょ など）は前の字と合わせて 1 音、促音「っ」・撥音「ん」・長音「ー」は 1 音。
enum Mora {
    static let smallKana: Set<Character> = Set("ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ")

    static func count(_ kana: String) -> Int {
        kana.reduce(0) { n, ch in
            if smallKana.contains(ch) { return n }
            return isKana(ch) || ch == "ー" ? n + 1 : n
        }
    }

    static func isKana(_ ch: Character) -> Bool {
        guard let s = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return false }
        return (0x3041...0x3096).contains(s.value) || (0x30A1...0x30FA).contains(s.value)
    }

    /// 読み（ひらがな）。仮名はそのまま、漢字は端末の辞書（CFStringTokenizer）の読みを使う。目安で、読み違えることがある
    static func reading(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let cf = trimmed as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, cf, CFRange(location: 0, length: CFStringGetLength(cf)), kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "ja_JP") as CFLocale
        )
        var result = ""
        var type = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while type != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let token = (trimmed as NSString).substring(with: NSRange(location: range.location, length: range.length))
            if token.allSatisfy({ isKana($0) || $0 == "ー" }) {
                result += token.applyingTransform(.hiraganaToKatakana, reverse: true) ?? token
            } else if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String,
                      let kana = latin.applyingTransform(.latinToHiragana, reverse: false) {
                result += kana.filter { isKana($0) || $0 == "ー" }
            } else {
                result += token.filter { isKana($0) || $0 == "ー" }
            }
            type = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        return result
    }
}

/// 句の中の季語を探す。長い季語を先に取り、重なる短い季語は数えない（「名月」の中の「月」など）
enum KigoFinder {
    static func find(in text: String, among list: [Kigo] = Almanac.allKigo) -> [Kigo] {
        let body = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
        guard !body.isEmpty else { return [] }
        var candidates: [(range: Range<String.Index>, kigo: Kigo)] = []
        for kigo in list {
            for needle in needles(for: kigo) {
                var start = body.startIndex
                while start < body.endIndex, let r = body.range(of: needle, range: start..<body.endIndex) {
                    candidates.append((r, kigo))
                    start = r.upperBound
                }
            }
        }
        candidates.sort { body.distance(from: $0.range.lowerBound, to: $0.range.upperBound) > body.distance(from: $1.range.lowerBound, to: $1.range.upperBound) }
        var taken: [Range<String.Index>] = []
        var found: [Kigo] = []
        for c in candidates where !taken.contains(where: { $0.overlaps(c.range) }) {
            taken.append(c.range)
            if !found.contains(where: { $0.word == c.kigo.word }) { found.append(c.kigo) }
        }
        return found
    }

    /// 表記と、3 字以上の読み（「か（蚊）」のような短い読みは、ほかの言葉に紛れるので使わない）
    static func needles(for kigo: Kigo) -> [String] {
        kigo.reading.count >= 3 && kigo.reading != kigo.word ? [kigo.word, kigo.reading] : [kigo.word]
    }
}

struct Hint: Identifiable, Hashable, Sendable {
    enum Kind: Sendable { case good, suggest, info }
    let kind: Kind
    let text: String
    var id: String { text }
}

/// 決まりで作る推敲のヒント（Apple Intelligence が使えなくても出る）
enum VerseCoach {
    static let targets = [5, 7, 5]
    static let lineNames = ["上五", "中七", "下五"]
    static let kireji = ["や", "かな", "けり"]
    static let feelingWords = ["嬉し", "うれし", "悲し", "かなし", "寂し", "さびし", "淋し", "楽し", "たのし", "きれい", "綺麗", "美し", "うつくし", "好き"]

    static func hints(lines: [String], counts: [Int], season: Season, todaysKigo: Kigo) -> [Hint] {
        let filled = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        guard filled.contains(where: { !$0.isEmpty }) else {
            return [Hint(kind: .info, text: "今日の季語「\(todaysKigo.word)」を上五に置くと、書きはじめやすくなります")]
        }
        var out: [Hint] = []
        // 音の数
        if counts == targets {
            out.append(Hint(kind: .good, text: "五・七・五、ちょうどです"))
        } else {
            for i in 0..<3 where !filled[i].isEmpty && counts[i] != targets[i] {
                let diff = counts[i] - targets[i]
                if diff > 0 {
                    out.append(Hint(kind: .suggest, text: "\(lineNames[i])が \(counts[i]) 音（字余り \(diff)）。助詞をひとつ削れないか見てみましょう"))
                } else {
                    out.append(Hint(kind: .suggest, text: "\(lineNames[i])が \(counts[i]) 音（あと \(-diff) 音）。言葉を足すか、長い言い方に"))
                }
            }
            for i in 0..<3 where filled[i].isEmpty {
                out.append(Hint(kind: .info, text: "\(lineNames[i])がまだ空です"))
            }
        }
        // 季語
        let found = KigoFinder.find(in: filled.joined())
        switch found.count {
        case 0:
            out.append(Hint(kind: .suggest, text: "季語が見つかりません。今日の季語「\(todaysKigo.word)」を入れると季節が立ちます（季語のない句もあります）"))
        case 1:
            let k = found[0]
            out.append(Hint(kind: .good, text: "季語は「\(k.word)」（\(k.season.name)）"))
            if k.season != season {
                out.append(Hint(kind: .info, text: "「\(k.word)」は\(k.season.name)の季語です。いまは\(season.name)。思い出の句なら、そのままで"))
            }
        default:
            let words = found.map(\.word).joined(separator: "・")
            out.append(Hint(kind: .suggest, text: "季語が \(found.count) つ（\(words)）。季重なりです。主役をひとつに絞ると句が締まります"))
        }
        // 切れ字
        let usedKireji = kireji.first { k in filled.contains { $0.hasSuffix(k) } }
        if let k = usedKireji {
            out.append(Hint(kind: .good, text: "切れ字「\(k)」で、場面に間が生まれています"))
        } else if !filled[0].isEmpty {
            out.append(Hint(kind: .info, text: "上五の終わりを「や」にすると、場面が切り替わります"))
        }
        // 気持ちの言葉
        if let w = feelingWords.first(where: { w in filled.contains { $0.contains(w) } }) {
            out.append(Hint(kind: .suggest, text: "「\(w)…」の気持ちを、見えたもの・聞こえたものに置き換えると、読む人に伝わります"))
        }
        return out
    }
}
