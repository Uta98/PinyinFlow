import Foundation
import Translation

enum TranslationTargetLanguage: String, CaseIterable, Identifiable, Sendable {
    case japanese = "ja"
    case english = "en"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "英語"
        case .korean: "韓国語"
        case .french: "フランス語"
        case .german: "ドイツ語"
        case .spanish: "スペイン語"
        }
    }

    var deeplCode: String {
        switch self {
        case .japanese: "JA"
        case .english: "EN-US"
        case .korean: "KO"
        case .french: "FR"
        case .german: "DE"
        case .spanish: "ES"
        }
    }

    var appleLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }

    var azureCode: String {
        switch self {
        case .japanese: "ja"
        case .english: "en"
        case .korean: "ko"
        case .french: "fr"
        case .german: "de"
        case .spanish: "es"
        }
    }
}

protocol TranslationServicing: Sendable {
    func translate(_ chineseText: String) async throws -> String
    func translate(_ chineseTexts: [String]) async throws -> [String]
}

struct DisabledTranslationService: TranslationServicing {
    func translate(_ chineseText: String) async throws -> String {
        ""
    }

    func translate(_ chineseTexts: [String]) async throws -> [String] {
        Array(repeating: "", count: chineseTexts.count)
    }
}

struct PreviewTranslationService: TranslationServicing {
    func translate(_ chineseText: String) async throws -> String {
        "今日は中国語を勉強します。"
    }

    func translate(_ chineseTexts: [String]) async throws -> [String] {
        chineseTexts.map { _ in "今日は中国語を勉強します。" }
    }
}

struct DeepLTranslationService: TranslationServicing {
    let apiKey: String
    let targetLanguage: TranslationTargetLanguage

    func translate(_ chineseText: String) async throws -> String {
        try await translate([chineseText]).first ?? ""
    }

    func translate(_ chineseTexts: [String]) async throws -> [String] {
        var translations: [String] = []
        for chunk in Self.chunks(for: chineseTexts) {
            let chunkTranslations = try await translateChunkWithRetry(chunk)
            translations.append(contentsOf: chunkTranslations)
        }
        return translations
    }

    private func translateChunkWithRetry(_ texts: [String]) async throws -> [String] {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                return try await translateChunk(texts)
            } catch {
                lastError = error
                guard attempt < 2 else { break }
                try await Task.sleep(for: .seconds(Double(attempt + 1)))
            }
        }
        throw lastError ?? AppError.translationFailed
    }

    private func translateChunk(_ chineseTexts: [String]) async throws -> [String] {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DeepLTranslationRequest(
            text: chineseTexts,
            sourceLang: "ZH",
            targetLang: targetLanguage.deeplCode
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AppError.translationFailed
        }

        let decoded = try JSONDecoder().decode(DeepLTranslationResponse.self, from: data)
        let values = decoded.translations.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if values.count < chineseTexts.count {
            return values + Array(repeating: "", count: chineseTexts.count - values.count)
        }
        return values
    }

    private var endpointURL: URL {
        let host = apiKey.hasSuffix(":fx") ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate"
        return URL(string: host)!
    }

    static func chunks(for texts: [String]) -> [[String]] {
        var chunks: [[String]] = []
        var current: [String] = []
        var currentCharacters = 0
        let maxTextsPerRequest = 40
        let maxCharactersPerRequest = 18_000

        for text in texts {
            let textCharacters = text.count
            if current.isEmpty == false,
               (current.count >= maxTextsPerRequest || currentCharacters + textCharacters > maxCharactersPerRequest) {
                chunks.append(current)
                current = []
                currentCharacters = 0
            }

            current.append(text)
            currentCharacters += textCharacters
        }

        if current.isEmpty == false {
            chunks.append(current)
        }
        return chunks
    }
}

struct AppleTranslationService: TranslationServicing {
    let targetLanguage: TranslationTargetLanguage

    func translate(_ chineseText: String) async throws -> String {
        try await translate([chineseText]).first ?? ""
    }

    func translate(_ chineseTexts: [String]) async throws -> [String] {
        guard #available(iOS 26.0, *) else {
            throw AppError.translationFailed
        }

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "zh-Hans"),
            target: targetLanguage.appleLanguage
        )
        let requests = chineseTexts.enumerated().map { index, text in
            TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
        }
        let responses = try await session.translations(from: requests)
        var responseByIndex: [Int: String] = [:]
        for response in responses {
            guard let identifier = response.clientIdentifier, let index = Int(identifier) else { continue }
            responseByIndex[index] = response.targetText
        }

        return chineseTexts.indices.map { index in
            responseByIndex[index]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }
}

struct GoogleCloudTranslationService: TranslationServicing {
    let apiKey: String
    let targetLanguage: TranslationTargetLanguage

    func translate(_ chineseText: String) async throws -> String {
        try await translate([chineseText]).first ?? ""
    }

    func translate(_ chineseTexts: [String]) async throws -> [String] {
        var translations: [String] = []
        for chunk in DeepLTranslationService.chunks(for: chineseTexts) {
            translations.append(contentsOf: try await translateChunk(chunk))
        }
        return translations
    }

    private func translateChunk(_ chineseTexts: [String]) async throws -> [String] {
        var components = URLComponents(string: "https://translation.googleapis.com/language/translate/v2")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GoogleTranslationRequest(
            q: chineseTexts,
            source: "zh-CN",
            target: targetLanguage.rawValue,
            format: "text"
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AppError.translationFailed
        }

        let decoded = try JSONDecoder().decode(GoogleTranslationResponse.self, from: data)
        let values = decoded.data.translations.map { $0.translatedText.trimmingCharacters(in: .whitespacesAndNewlines) }
        if values.count < chineseTexts.count {
            return values + Array(repeating: "", count: chineseTexts.count - values.count)
        }
        return values
    }
}

struct AzureTranslatorService: TranslationServicing {
    let apiKey: String
    let region: String
    let targetLanguage: TranslationTargetLanguage

    func translate(_ chineseText: String) async throws -> String {
        try await translate([chineseText]).first ?? ""
    }

    func translate(_ chineseTexts: [String]) async throws -> [String] {
        var translations: [String] = []
        for chunk in DeepLTranslationService.chunks(for: chineseTexts) {
            translations.append(contentsOf: try await translateChunk(chunk))
        }
        return translations
    }

    private func translateChunk(_ chineseTexts: [String]) async throws -> [String] {
        var components = URLComponents(string: "https://api.cognitive.microsofttranslator.com/translate")!
        components.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "from", value: "zh-Hans"),
            URLQueryItem(name: "to", value: targetLanguage.azureCode)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(chineseTexts.map { AzureTranslationRequest(text: $0) })

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AppError.translationFailed
        }

        let decoded = try JSONDecoder().decode([AzureTranslationResponse].self, from: data)
        let values = decoded.map { item in
            item.translations.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if values.count < chineseTexts.count {
            return values + Array(repeating: "", count: chineseTexts.count - values.count)
        }
        return values
    }
}

private struct GoogleTranslationRequest: Encodable {
    var q: [String]
    var source: String
    var target: String
    var format: String
}

private struct GoogleTranslationResponse: Decodable {
    var data: TranslationData

    struct TranslationData: Decodable {
        var translations: [Translation]
    }

    struct Translation: Decodable {
        var translatedText: String
    }
}

private struct AzureTranslationRequest: Encodable {
    var text: String

    enum CodingKeys: String, CodingKey {
        case text = "Text"
    }
}

private struct AzureTranslationResponse: Decodable {
    var translations: [Translation]

    struct Translation: Decodable {
        var text: String
    }
}

private struct DeepLTranslationRequest: Encodable {
    var text: [String]
    var sourceLang: String
    var targetLang: String

    enum CodingKeys: String, CodingKey {
        case text
        case sourceLang = "source_lang"
        case targetLang = "target_lang"
    }
}

private struct DeepLTranslationResponse: Decodable {
    var translations: [Translation]

    struct Translation: Decodable {
        var text: String
    }
}
