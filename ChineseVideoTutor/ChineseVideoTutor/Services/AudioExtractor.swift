import AVFoundation
import Foundation

protocol AudioExtracting: Sendable {
    func extractAudio(from mediaURL: URL) async throws -> URL
}

struct AVAssetAudioExtractor: AudioExtracting {
    func extractAudio(from mediaURL: URL) async throws -> URL {
        if mediaURL.isStandaloneAudioFile {
            return mediaURL
        }

        let asset = AVURLAsset(url: mediaURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppError.audioExtractionUnavailable
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.metadata = []

        await exporter.export()

        if exporter.status == .completed {
            return outputURL
        }

        throw exporter.error ?? AppError.audioExtractionFailed
    }
}

struct PreviewAudioExtractor: AudioExtracting {
    func extractAudio(from mediaURL: URL) async throws -> URL {
        mediaURL
    }
}
