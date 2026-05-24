import Foundation

enum TranscriptTextCleaner {
    static func clean(_ text: String) -> String {
        var cleaned = text
        let patterns = [
            #"<\|[0-9]+(?:\.[0-9]+)?\|>"#,
            #"<<[0-9]+(?:\.[0-9]+)?>>"#,
            #"<[0-9]+(?:\.[0-9]+)\|>"#,
            #"<\|[0-9]+(?:\.[0-9]+)>"#,
            #"<\*+>"#,
            #"<[^>\n]{0,32}>"#,
            #"＜[^＞\n]{0,32}＞"#
        ]

        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        return cleaned
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanChinese(_ text: String) -> String {
        clean(text).applyingTransform(StringTransform("Any-Hans"), reverse: false) ?? clean(text)
    }
}

struct TranscriptSegment: Identifiable, Hashable, Codable {
    var id = UUID()
    var sourceText: String
    var pinyinTokens: [PinyinToken]
    var japaneseTranslation: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var isFavorite = false

    enum CodingKeys: String, CodingKey {
        case id
        case sourceText
        case pinyinTokens
        case japaneseTranslation
        case startTime
        case endTime
        case isFavorite
    }

    init(
        id: UUID = UUID(),
        sourceText: String,
        pinyinTokens: [PinyinToken],
        japaneseTranslation: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sourceText = sourceText
        self.pinyinTokens = pinyinTokens
        self.japaneseTranslation = japaneseTranslation
        self.startTime = startTime
        self.endTime = endTime
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceText = try container.decode(String.self, forKey: .sourceText)
        pinyinTokens = try container.decode([PinyinToken].self, forKey: .pinyinTokens)
        japaneseTranslation = try container.decode(String.self, forKey: .japaneseTranslation)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    var timecode: String {
        "\(Self.format(startTime)) - \(Self.format(endTime))"
    }

    func contains(time: TimeInterval) -> Bool {
        startTime <= time && time < endTime
    }

    private static func format(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time.rounded(.down)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RawTranscriptSegment: Hashable, Sendable {
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
}

struct TranscriptSession: Identifiable, Hashable, Codable {
    var id = UUID()
    var videoName: String
    var videoPath: String
    var createdAt: Date
    var duration: TimeInterval?
    var segments: [TranscriptSegment]

    var videoURL: URL {
        URL(fileURLWithPath: videoPath)
    }

    var isTextOnly: Bool {
        videoPath.isEmpty
    }

    var isAudioOnly: Bool {
        videoURL.isStandaloneAudioFile
    }

    var durationText: String {
        let totalSeconds = max(Int((duration ?? 0).rounded(.down)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct PinyinToken: Identifiable, Hashable, Codable {
    var id = UUID()
    var character: String
    var pinyin: String
}

enum ProcessingPhase: Equatable {
    case idle
    case importing
    case extractingAudio
    case requestingSpeechPermission
    case transcribing
    case annotating
    case translating
    case finished

    var isBusy: Bool {
        switch self {
        case .idle, .finished:
            false
        case .importing, .extractingAudio, .requestingSpeechPermission, .transcribing, .annotating, .translating:
            true
        }
    }

    var statusText: String {
        switch self {
        case .idle:
            "動画を選んで解析を開始できます。"
        case .importing:
            "動画を読み込んでいます。"
        case .extractingAudio:
            "動画から音声を抽出しています。"
        case .requestingSpeechPermission:
            "音声認識の許可を確認しています。"
        case .transcribing:
            "中国語音声を文字起こししています。"
        case .annotating:
            "ピンインを付与しています。"
        case .translating:
            "翻訳を作成しています。"
        case .finished:
            "解析が完了しました。"
        }
    }
}
