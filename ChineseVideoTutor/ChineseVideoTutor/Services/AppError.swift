import Foundation

enum AppError: LocalizedError {
    case audioExtractionUnavailable
    case audioExtractionFailed
    case speechPermissionDenied
    case speechRecognizerUnavailable
    case missingAPIKey(String)
    case transcriptionFailed(String)
    case translationFailed
    case translationUnavailable(String)
    case linkVideoNotFound
    case youtubeLinkUnsupported

    var errorDescription: String? {
        switch self {
        case .audioExtractionUnavailable:
            "この動画から音声を抽出できません。"
        case .audioExtractionFailed:
            "音声抽出に失敗しました。別の動画形式で試してください。"
        case .speechPermissionDenied:
            "音声認識の許可が必要です。設定アプリで許可してください。"
        case .speechRecognizerUnavailable:
            "中国語の音声認識を利用できません。WhisperKit の端末内文字起こしへ切り替えます。"
        case .missingAPIKey(let serviceName):
            "\(serviceName) のAPIキーを設定してください。"
        case .transcriptionFailed(let message):
            message.isEmpty ? "文字起こしに失敗しました。" : message
        case .translationFailed:
            "翻訳の作成に失敗しました。翻訳ツールの設定を確認してください。"
        case .translationUnavailable(let reason):
            "翻訳を作成できませんでした。\(reason)"
        case .linkVideoNotFound:
            "リンク先から動画を見つけられませんでした。共有リンクまたは動画URLを確認してください。"
        case .youtubeLinkUnsupported:
            "YouTubeリンクは、この方式では動画データを取得できないため文字起こしできません。動画ファイルとして保存してから取り込んでください。"
        }
    }
}
