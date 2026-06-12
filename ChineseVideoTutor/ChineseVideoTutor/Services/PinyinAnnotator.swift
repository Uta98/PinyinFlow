import Foundation

protocol PinyinAnnotating: Sendable {
    func tokens(for text: String) -> [PinyinToken]
}

struct MandarinPinyinAnnotator: PinyinAnnotating {
    private static let phraseOverrides: [(text: String, pinyin: [String])] = [
        ("地方", ["dì", "fang"]),
        ("目的", ["mù", "dì"]),
        ("地图", ["dì", "tú"]),
        ("地铁", ["dì", "tiě"]),
        ("地下", ["dì", "xià"]),
        ("土地", ["tǔ", "dì"]),
        ("银行", ["yín", "háng"]),
        ("行业", ["háng", "yè"]),
        ("行李", ["xíng", "li"]),
        ("不行", ["bù", "xíng"]),
        ("了解", ["liǎo", "jiě"]),
        ("为了", ["wèi", "le"]),
        ("因为", ["yīn", "wèi"]),
        ("还是", ["hái", "shi"]),
        ("还没", ["hái", "méi"]),
        ("重庆", ["chóng", "qìng"]),
        ("音乐", ["yīn", "yuè"]),
        ("快乐", ["kuài", "lè"]),
        ("长大", ["zhǎng", "dà"]),
        ("长度", ["cháng", "dù"]),
        ("重要", ["zhòng", "yào"]),
        ("重新", ["chóng", "xīn"]),
        ("曾经", ["céng", "jīng"]),
        ("姓曾", ["xìng", "zēng"])
    ].sorted { $0.text.count > $1.text.count }

    func tokens(for text: String) -> [PinyinToken] {
        let characters = text.map(String.init)
        var tokens: [PinyinToken] = []
        var index = 0

        while index < characters.count {
            guard characters[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                index += 1
                continue
            }

            if let override = Self.overrideStarting(at: index, in: characters) {
                for (offset, pinyin) in override.pinyin.enumerated() {
                    tokens.append(PinyinToken(
                        character: characters[index + offset],
                        pinyin: pinyin
                    ))
                }
                index += override.text.count
                continue
            }

            let character = characters[index]
            guard character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                index += 1
                continue
            }

            guard character.range(of: #"\p{Han}"#, options: .regularExpression) != nil else {
                tokens.append(PinyinToken(character: character, pinyin: ""))
                index += 1
                continue
            }

            let mutable = NSMutableString(string: character) as CFMutableString
            CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)

            tokens.append(PinyinToken(character: character, pinyin: (mutable as String).lowercased()))
            index += 1
        }

        return tokens
    }

    private static func overrideStarting(
        at index: Int,
        in characters: [String]
    ) -> (text: String, pinyin: [String])? {
        for override in phraseOverrides {
            guard override.text.count == override.pinyin.count else { continue }
            guard index + override.text.count <= characters.count else { continue }
            let candidate = characters[index..<(index + override.text.count)].joined()
            if candidate == override.text {
                return override
            }
        }
        return nil
    }
}
