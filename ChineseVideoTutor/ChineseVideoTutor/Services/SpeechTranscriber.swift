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

struct OpenAIWhisperAPISpeechTranscriber: SpeechTranscribing {
    let apiKey: String

    func requestAuthorization() async throws {}

    func transcribeAudio(at audioURL: URL) async throws -> [RawTranscriptSegment] {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeMultipartBody(audioURL: audioURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw AppError.transcriptionFailed("OpenAI Whisper API の文字起こしに失敗しました。APIキーと通信状況を確認してください。")
        }

        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
        let segments = decoded.segments.map {
            RawTranscriptSegment(
                text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: $0.start,
                endTime: max($0.end, $0.start + 0.4)
            )
        }
        .filter { $0.text.isEmpty == false }

        if segments.isEmpty == false {
            return segments
        }

        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            throw AppError.transcriptionFailed("OpenAI Whisper API で文字起こし結果を取得できませんでした。")
        }
        return [RawTranscriptSegment(text: text, startTime: 0, endTime: 0.4)]
    }

    private func makeMultipartBody(audioURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let filename = audioURL.lastPathComponent.isEmpty ? "audio.m4a" : audioURL.lastPathComponent
        let fileData = try Data(contentsOf: audioURL)

        body.appendMultipartField(name: "model", value: "whisper-1", boundary: boundary)
        body.appendMultipartField(name: "language", value: "zh", boundary: boundary)
        body.appendMultipartField(name: "response_format", value: "verbose_json", boundary: boundary)
        body.appendMultipartField(name: "timestamp_granularities[]", value: "segment", boundary: boundary)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType(for: audioURL))\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp3": "audio/mpeg"
        case "wav": "audio/wav"
        case "mp4", "m4a": "audio/mp4"
        default: "application/octet-stream"
        }
    }
}

private struct OpenAITranscriptionResponse: Decodable {
    var text: String
    var segments: [Segment]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        segments = try container.decodeIfPresent([Segment].self, forKey: .segments) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case text
        case segments
    }

    struct Segment: Decodable {
        var text: String
        var start: TimeInterval
        var end: TimeInterval
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
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
