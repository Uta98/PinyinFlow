import Foundation
import Speech
import WhisperKit

protocol SpeechTranscribing: Sendable {
    func requestAuthorization() async throws
    func transcribeAudio(at audioURL: URL) async throws -> [RawTranscriptSegment]
}

struct SpeechSpeechTranscriber: SpeechTranscribing {
    let localeIdentifier: String

    func requestAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else {
            throw AppError.speechPermissionDenied
        }
    }

    func transcribeAudio(at audioURL: URL) async throws -> [RawTranscriptSegment] {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            throw AppError.speechRecognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error, didResume == false {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal, didResume == false else { return }
                didResume = true
                continuation.resume(returning: Self.makeSegments(from: result.bestTranscription.segments))
            }
        }
    }

    private static func makeSegments(from segments: [SFTranscriptionSegment]) -> [RawTranscriptSegment] {
        var output: [RawTranscriptSegment] = []
        var currentText = ""
        var currentStart: TimeInterval?
        var currentEnd: TimeInterval = 0

        for segment in segments {
            let text = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else { continue }

            if currentStart == nil {
                currentStart = segment.timestamp
            }

            currentText += text
            currentEnd = segment.timestamp + segment.duration

            let shouldBreak = text.range(of: #"[。！？!?]"#, options: .regularExpression) != nil
                || currentEnd - (currentStart ?? 0) > 8

            if shouldBreak, let start = currentStart {
                output.append(RawTranscriptSegment(text: currentText, startTime: start, endTime: max(currentEnd, start + 0.4)))
                currentText = ""
                currentStart = nil
            }
        }

        if currentText.isEmpty == false, let start = currentStart {
            output.append(RawTranscriptSegment(text: currentText, startTime: start, endTime: max(currentEnd, start + 0.4)))
        }

        return output
    }
}

struct FallbackSpeechTranscriber: SpeechTranscribing {
    let primary: SpeechTranscribing
    let fallback: SpeechTranscribing

    func requestAuthorization() async throws {
        do {
            try await primary.requestAuthorization()
        } catch {
            try await fallback.requestAuthorization()
        }
    }

    func transcribeAudio(at audioURL: URL) async throws -> [RawTranscriptSegment] {
        do {
            return try await primary.transcribeAudio(at: audioURL)
        } catch {
            try? await fallback.requestAuthorization()
            return try await fallback.transcribeAudio(at: audioURL)
        }
    }
}

actor WhisperKitSpeechTranscriber: SpeechTranscribing {
    let model: String
    private var whisperKit: WhisperKit?

    init(model: String) {
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "base" : model
    }

    func requestAuthorization() async throws {}

    func transcribeAudio(at audioURL: URL) async throws -> [RawTranscriptSegment] {
        let pipe = try await loadWhisperKit()
        let options = DecodingOptions(
            task: .transcribe,
            language: "zh",
            temperature: 0.0
        )
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)
        let segments = results
            .flatMap(\.segments)
            .map {
                RawTranscriptSegment(
                    text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: TimeInterval($0.start),
                    endTime: TimeInterval(max($0.end, $0.start + 0.4))
                )
            }
            .filter { $0.text.isEmpty == false }

        guard segments.isEmpty == false else {
            throw AppError.transcriptionFailed("WhisperKit で文字起こし結果を取得できませんでした。")
        }
        return segments
    }

    private func loadWhisperKit() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }

        let config = WhisperKitConfig(model: model)
        let whisperKit = try await WhisperKit(config)
        self.whisperKit = whisperKit
        return whisperKit
    }
}

struct PreviewSpeechTranscriber: SpeechTranscribing {
    func requestAuthorization() async throws {}

    func transcribeAudio(at audioURL: URL) async throws -> [RawTranscriptSegment] {
        [
            RawTranscriptSegment(text: "今天我们学习中文。", startTime: 0, endTime: 3.8),
            RawTranscriptSegment(text: "这个视频很有意思。", startTime: 4.2, endTime: 7.1)
        ]
    }
}
