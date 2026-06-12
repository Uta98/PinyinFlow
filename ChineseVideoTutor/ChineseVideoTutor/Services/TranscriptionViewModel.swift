import Foundation
import Combine
import UIKit

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var selectedVideoName: String?
    @Published var phase: ProcessingPhase = .idle
    @Published var segments: [TranscriptSegment] = []
    @Published var history: [TranscriptSession] = []
    @Published var errorMessage: String?
    @Published var translationWarningMessage: String?
    @Published var activeSessionID: TranscriptSession.ID?
    @Published var initialPlaybackTime: TimeInterval?
    @Published var isTextOnlySession = false

    var shouldShowWorkspace: Bool {
        selectedVideoURL != nil || isTextOnlySession || phase.isBusy || (errorMessage != nil && selectedVideoName != nil)
    }

    private let audioExtractor: AudioExtracting
    private let pinyinAnnotator: PinyinAnnotating
    private var speechTranscriber: SpeechTranscribing
    private var translationService: TranslationServicing
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    init(
        audioExtractor: AudioExtracting = AVAssetAudioExtractor(),
        speechTranscriber: SpeechTranscribing = SpeechSpeechTranscriber(localeIdentifier: "zh-CN"),
        pinyinAnnotator: PinyinAnnotating = MandarinPinyinAnnotator(),
        translationService: TranslationServicing = DisabledTranslationService()
    ) {
        self.audioExtractor = audioExtractor
        self.speechTranscriber = speechTranscriber
        self.pinyinAnnotator = pinyinAnnotator
        self.translationService = translationService
        self.history = Self.loadHistory()
    }

    func configureServices(
        apiKey: String,
        googleTranslateAPIKey: String = "",
        azureTranslateAPIKey: String = "",
        azureTranslateRegion: String = "",
        openAIAPIKey: String = "",
        assemblyAIAPIKey: String = "",
        whisperModel: String = "base",
        translationEngine: String = "ios",
        transcriptionEngine: String = "whisperkit",
        translationTarget: String = TranslationTargetLanguage.japanese.rawValue
    ) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGoogleTranslateKey = googleTranslateAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAzureTranslateKey = azureTranslateAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAzureTranslateRegion = azureTranslateRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAssemblyAIKey = assemblyAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLanguage = TranslationTargetLanguage(rawValue: translationTarget) ?? .japanese

        if transcriptionEngine == "openai", trimmedOpenAIKey.isEmpty == false {
            speechTranscriber = OpenAIWhisperAPISpeechTranscriber(apiKey: trimmedOpenAIKey)
        } else if transcriptionEngine == "openai" {
            speechTranscriber = MissingAPIKeySpeechTranscriber(serviceName: "OpenAI")
        } else if transcriptionEngine == "assemblyai", trimmedAssemblyAIKey.isEmpty == false {
            speechTranscriber = AssemblyAISpeechTranscriber(apiKey: trimmedAssemblyAIKey)
        } else if transcriptionEngine == "assemblyai" {
            speechTranscriber = MissingAPIKeySpeechTranscriber(serviceName: "AssemblyAI")
        } else {
            speechTranscriber = WhisperKitSpeechTranscriber(model: whisperModel)
        }

        if translationEngine == "ios" {
            translationService = AppleTranslationService(targetLanguage: targetLanguage)
        } else if translationEngine == "google", trimmedGoogleTranslateKey.isEmpty == false {
            translationService = GoogleCloudTranslationService(apiKey: trimmedGoogleTranslateKey, targetLanguage: targetLanguage)
        } else if translationEngine == "google" {
            translationService = MissingAPIKeyTranslationService(serviceName: "Google Cloud Translation")
        } else if translationEngine == "azure", trimmedAzureTranslateKey.isEmpty == false, trimmedAzureTranslateRegion.isEmpty == false {
            translationService = AzureTranslatorService(
                apiKey: trimmedAzureTranslateKey,
                region: trimmedAzureTranslateRegion,
                targetLanguage: targetLanguage
            )
        } else if translationEngine == "azure" {
            translationService = MissingAPIKeyTranslationService(serviceName: "Azure AI Translator")
        } else if translationEngine == "deepl", trimmedKey.isEmpty {
            translationService = MissingAPIKeyTranslationService(serviceName: "DeepL")
        } else if translationEngine == "deepl" {
            translationService = DeepLTranslationService(apiKey: trimmedKey, targetLanguage: targetLanguage)
        } else if trimmedKey.isEmpty {
            translationService = DisabledTranslationService()
        } else {
            translationService = DeepLTranslationService(apiKey: trimmedKey, targetLanguage: targetLanguage)
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            phase = .importing
            errorMessage = nil
            translationWarningMessage = nil
            selectedVideoURL = url
            selectedVideoName = url.lastPathComponent
            segments = []
            activeSessionID = nil
            initialPlaybackTime = nil
            isTextOnlySession = false
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func importAndProcess(_ result: Result<[URL], Error>) async {
        do {
            guard let url = try result.get().first else { return }
            phase = .importing
            errorMessage = nil
            translationWarningMessage = nil
            selectedVideoURL = url
            selectedVideoName = url.lastPathComponent
            segments = []
            activeSessionID = nil
            initialPlaybackTime = nil
            isTextOnlySession = false
            await Task.yield()
            selectedVideoURL = try FileImporter.copyToDocuments(url: url)
            selectedVideoName = selectedVideoURL?.lastPathComponent
            phase = .idle
            await processSelectedVideo()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func importPhotoVideo(data: Data) async {
        do {
            phase = .importing
            errorMessage = nil
            translationWarningMessage = nil
            let fileName = "photo-\(UUID().uuidString).mov"
            selectedVideoURL = try FileImporter.copyVideoDataToDocuments(data, fileName: fileName)
            selectedVideoName = selectedVideoURL?.lastPathComponent
            segments = []
            activeSessionID = nil
            initialPlaybackTime = nil
            isTextOnlySession = false
            phase = .idle
            await processSelectedVideo()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func prepareImportingPlaceholder(name: String) {
        phase = .importing
        errorMessage = nil
        translationWarningMessage = nil
        selectedVideoName = name
        segments = []
        activeSessionID = nil
        initialPlaybackTime = nil
        isTextOnlySession = false
    }

    func importVideo(fromLink link: String) async {
        do {
            guard let url = Self.normalizedLinkURL(from: link) else {
                throw AppError.linkVideoNotFound
            }
            guard Self.isYouTubeURL(url) == false else {
                throw AppError.youtubeLinkUnsupported
            }

            phase = .importing
            errorMessage = nil
            translationWarningMessage = nil
            selectedVideoName = "XiaoHongShu"
            selectedVideoURL = nil
            segments = []
            activeSessionID = nil
            initialPlaybackTime = nil
            isTextOnlySession = false
            await Task.yield()
            let data = try await LinkVideoImporter.downloadVideo(from: url)
            let fileName = "xiaohongshu-\(UUID().uuidString).mp4"
            selectedVideoURL = try FileImporter.copyVideoDataToDocuments(data, fileName: fileName)
            selectedVideoName = "XiaoHongShu"
            phase = .idle
            await processSelectedVideo()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func showHome() {
        selectedVideoURL = nil
        selectedVideoName = nil
        segments = []
        errorMessage = nil
        translationWarningMessage = nil
        phase = .idle
        activeSessionID = nil
        initialPlaybackTime = nil
        isTextOnlySession = false
    }

    func loadSession(_ session: TranscriptSession, startTime: TimeInterval? = nil) {
        guard session.mediaFileExists else {
            selectedVideoURL = nil
            selectedVideoName = session.videoName
            segments = session.segments
            errorMessage = "保存済みの動画ファイルが見つかりません。開発ビルドからApp Store版へ入れ替えた場合や、アプリを削除して再インストールした場合、動画本体はiOSにより削除されることがあります。"
            translationWarningMessage = nil
            phase = .finished
            activeSessionID = session.id
            initialPlaybackTime = nil
            isTextOnlySession = false
            return
        }

        selectedVideoURL = session.isTextOnly ? nil : session.videoURL
        selectedVideoName = session.videoName
        segments = session.segments
        errorMessage = nil
        translationWarningMessage = nil
        phase = .finished
        activeSessionID = session.id
        initialPlaybackTime = startTime
        isTextOnlySession = session.isTextOnly
    }

    func importText(_ text: String) async {
        let cleanedText = TranscriptTextCleaner.cleanChinese(text)
        guard cleanedText.isEmpty == false else { return }

        errorMessage = nil
        translationWarningMessage = nil
        selectedVideoURL = nil
        selectedVideoName = "テキスト"
        activeSessionID = nil
        initialPlaybackTime = nil
        isTextOnlySession = true
        segments = []

        phase = .annotating
        var textSegments = Self.splitTextIntoSegments(cleanedText).enumerated().map { offset, sentence in
            TranscriptSegment(
                sourceText: sentence,
                pinyinTokens: pinyinAnnotator.tokens(for: sentence),
                japaneseTranslation: "",
                startTime: TimeInterval(offset),
                endTime: TimeInterval(offset + 1)
            )
        }

        phase = .translating
        do {
            let translations = try await translationService.translate(textSegments.map(\.sourceText))
            for index in textSegments.indices {
                guard translations.indices.contains(index) else { continue }
                textSegments[index].japaneseTranslation = TranscriptTextCleaner.clean(translations[index])
            }
        } catch {
            translationWarningMessage = translationWarning(for: error)
        }

        segments = textSegments
        saveCurrentTextSession()
        phase = .finished
    }

    func deleteSession(_ session: TranscriptSession) {
        history.removeAll { $0.id == session.id }
        Self.saveHistory(history)
        if session.isTextOnly == false {
            try? FileManager.default.removeItem(at: session.videoURL)
        }
        if activeSessionID == session.id {
            showHome()
        }
    }

    func updateSegment(id: TranscriptSegment.ID, sourceText: String, japaneseTranslation: String) {
        let cleanedSource = TranscriptTextCleaner.cleanChinese(sourceText)
        let cleanedTranslation = TranscriptTextCleaner.clean(japaneseTranslation)

        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        segments[index].sourceText = cleanedSource
        segments[index].pinyinTokens = pinyinAnnotator.tokens(for: cleanedSource)
        segments[index].japaneseTranslation = cleanedTranslation

        guard let activeSessionID,
              let historyIndex = history.firstIndex(where: { $0.id == activeSessionID }),
              let segmentIndex = history[historyIndex].segments.firstIndex(where: { $0.id == id }) else {
            return
        }
        history[historyIndex].segments[segmentIndex] = segments[index]
        Self.saveHistory(history)
    }

    func toggleFavorite(segmentID: TranscriptSegment.ID) {
        guard let index = segments.firstIndex(where: { $0.id == segmentID }) else { return }
        segments[index].isFavorite.toggle()

        guard let activeSessionID,
              let historyIndex = history.firstIndex(where: { $0.id == activeSessionID }),
              let segmentIndex = history[historyIndex].segments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }
        history[historyIndex].segments[segmentIndex].isFavorite = segments[index].isFavorite
        Self.saveHistory(history)
    }

    func toggleFavorite(sessionID: TranscriptSession.ID, segmentID: TranscriptSegment.ID) {
        guard let historyIndex = history.firstIndex(where: { $0.id == sessionID }),
              let segmentIndex = history[historyIndex].segments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }

        let isFavorite = history[historyIndex].segments[segmentIndex].isFavorite == false
        history[historyIndex].segments[segmentIndex].isFavorite = isFavorite

        if activeSessionID == sessionID,
           let activeIndex = segments.firstIndex(where: { $0.id == segmentID }) {
            segments[activeIndex].isFavorite = isFavorite
        }

        Self.saveHistory(history)
    }

    func translateDraft(_ sourceText: String) async -> String {
        do {
            let source = TranscriptTextCleaner.cleanChinese(sourceText)
            guard source.isEmpty == false else { return "" }
            return TranscriptTextCleaner.clean(try await translationService.translate(source))
        } catch {
            return ""
        }
    }

    func processSelectedVideo() async {
        guard let selectedVideoURL else { return }
        beginBackgroundTask()
        defer {
            endBackgroundTask()
        }

        do {
            errorMessage = nil
            translationWarningMessage = nil
            segments = []

            phase = .extractingAudio
            let audioURL = try await audioExtractor.extractAudio(from: selectedVideoURL)

            phase = .requestingSpeechPermission
            try await speechTranscriber.requestAuthorization()

            phase = .transcribing
            let transcriptSegments = try await speechTranscriber.transcribeAudio(at: audioURL)
                .map {
                    RawTranscriptSegment(
                        text: TranscriptTextCleaner.cleanChinese($0.text),
                        startTime: $0.startTime,
                        endTime: $0.endTime
                    )
                }
                .filter { $0.text.isEmpty == false }

            phase = .annotating
            var annotatedSegments = transcriptSegments.map { segment in
                TranscriptSegment(
                    sourceText: segment.text,
                    pinyinTokens: pinyinAnnotator.tokens(for: segment.text),
                    japaneseTranslation: "",
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            }

            phase = .translating
            let translationInputs = annotatedSegments.map {
                TranscriptTextCleaner.cleanChinese($0.sourceText)
            }
            do {
                let translations = try await translationService.translate(translationInputs)
                for index in annotatedSegments.indices {
                    guard translations.indices.contains(index) else { continue }
                    annotatedSegments[index].japaneseTranslation = TranscriptTextCleaner.clean(translations[index])
                }
            } catch {
                translationWarningMessage = translationWarning(for: error)
            }

            segments = annotatedSegments
            saveCurrentSession()
            phase = .finished
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    private func translationWarning(for error: Error) -> String {
        let message = error.localizedDescription
        if message.isEmpty {
            return "翻訳を作成できませんでした。翻訳ツールの設定、端末の翻訳言語データ、ネットワーク接続を確認してください。"
        }
        return message
    }

    private func saveCurrentSession() {
        guard let selectedVideoURL, let selectedVideoName, segments.isEmpty == false else { return }

        let session = TranscriptSession(
            videoName: selectedVideoName,
            videoPath: FileImporter.storagePath(for: selectedVideoURL),
            createdAt: Date(),
            duration: segments.map(\.endTime).max(),
            segments: segments
        )

        history.removeAll { $0.videoPath == selectedVideoURL.path }
        history.insert(session, at: 0)
        activeSessionID = session.id
        Self.saveHistory(history)
    }

    private func saveCurrentTextSession() {
        guard let selectedVideoName, segments.isEmpty == false else { return }

        let session = TranscriptSession(
            videoName: selectedVideoName,
            videoPath: "",
            createdAt: Date(),
            duration: nil,
            segments: segments
        )

        history.insert(session, at: 0)
        activeSessionID = session.id
        Self.saveHistory(history)
    }

    private static func loadHistory() -> [TranscriptSession] {
        do {
            let data = try Data(contentsOf: historyURL)
            return try JSONDecoder().decode([TranscriptSession].self, from: data)
        } catch {
            return []
        }
    }

    private static func saveHistory(_ history: [TranscriptSession]) {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save transcript history: \(error)")
        }
    }

    private static var historyURL: URL {
        return (try! FileImporter.documentsURL).appendingPathComponent("TranscriptHistory.json")
    }

    private static func normalizedLinkURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            return url
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return detector.firstMatch(in: trimmed, range: range)?.url
    }

    private static func isYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return host == "youtu.be" || host.hasSuffix("youtube.com")
    }

    private static func splitTextIntoSegments(_ text: String) -> [String] {
        let parts = text
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?；;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return parts.isEmpty ? [text] : parts
    }

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "TranscribeMedia") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

extension TranscriptionViewModel {
    static var preview: TranscriptionViewModel {
        let model = TranscriptionViewModel(
            audioExtractor: PreviewAudioExtractor(),
            speechTranscriber: PreviewSpeechTranscriber(),
            pinyinAnnotator: MandarinPinyinAnnotator(),
            translationService: PreviewTranslationService()
        )
        model.selectedVideoName = "lesson.mov"
        model.segments = [
            TranscriptSegment(
                sourceText: "今天我们学习中文。",
                pinyinTokens: MandarinPinyinAnnotator().tokens(for: "今天我们学习中文。"),
                japaneseTranslation: "今日は中国語を勉強します。",
                startTime: 0,
                endTime: 3.8
            )
        ]
        model.phase = .finished
        return model
    }
}
