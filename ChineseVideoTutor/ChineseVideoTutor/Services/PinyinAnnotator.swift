import Foundation

protocol PinyinAnnotating: Sendable {
    func tokens(for text: String) -> [PinyinToken]
}

struct MandarinPinyinAnnotator: PinyinAnnotating {
    func tokens(for text: String) -> [PinyinToken] {
        text.map(String.init).compactMap { character in
            guard character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return nil
            }

            guard character.range(of: #"\p{Han}"#, options: .regularExpression) != nil else {
                return PinyinToken(character: character, pinyin: "")
            }

            let mutable = NSMutableString(string: character) as CFMutableString
            CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)

            return PinyinToken(character: character, pinyin: (mutable as String).lowercased())
        }
    }
}
