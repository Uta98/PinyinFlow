import Foundation

extension URL {
    var isStandaloneAudioFile: Bool {
        ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf"].contains(pathExtension.lowercased())
    }
}

enum FileImporter {
    static func copyToDocuments(url: URL) throws -> URL {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let videosURL = documentsURL.appendingPathComponent("ImportedVideos", isDirectory: true)
        try FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)

        let destinationURL = videosURL.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: url, to: destinationURL)
        return destinationURL
    }

    static func copyVideoDataToDocuments(_ data: Data, fileName: String) throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let videosURL = documentsURL.appendingPathComponent("ImportedVideos", isDirectory: true)
        try FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)

        let destinationURL = videosURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }
}
