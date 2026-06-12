import Foundation

extension URL {
    var isStandaloneAudioFile: Bool {
        ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf"].contains(pathExtension.lowercased())
    }

    var isImageFile: Bool {
        ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif"].contains(pathExtension.lowercased())
    }
}

enum FileImporter {
    static var documentsURL: URL {
        get throws {
            try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
    }

    static var importedMediaDirectory: URL {
        get throws {
            try documentsURL.appendingPathComponent("ImportedVideos", isDirectory: true)
        }
    }

    static var importedImagesDirectory: URL {
        get throws {
            try documentsURL.appendingPathComponent("ImportedImages", isDirectory: true)
        }
    }

    static func storagePath(for url: URL) -> String {
        let directory = url.isImageFile ? (try? importedImagesDirectory) : (try? importedMediaDirectory)
        guard let mediaDirectory = directory else {
            return url.path
        }

        let mediaPath = mediaDirectory.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        if filePath.hasPrefix(mediaPath) {
            return "\(url.isImageFile ? "ImportedImages" : "ImportedVideos")/" + url.lastPathComponent
        }
        return url.path
    }

    static func resolvedMediaURL(from storedPath: String) -> URL {
        guard storedPath.isEmpty == false else {
            return URL(fileURLWithPath: "")
        }

        if storedPath.hasPrefix("/") {
            let absoluteURL = URL(fileURLWithPath: storedPath)
            if FileManager.default.fileExists(atPath: absoluteURL.path) {
                return absoluteURL
            }

            if absoluteURL.isImageFile, let imagesURL = try? importedImagesDirectory {
                return imagesURL.appendingPathComponent(absoluteURL.lastPathComponent)
            }
            if let mediaURL = try? importedMediaDirectory {
                return mediaURL.appendingPathComponent(absoluteURL.lastPathComponent)
            }
            return absoluteURL
        }

        if let documentsURL = try? documentsURL {
            return documentsURL.appendingPathComponent(storedPath)
        }
        return URL(fileURLWithPath: storedPath)
    }

    static func copyToDocuments(url: URL) throws -> URL {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let mediaURL = try url.isImageFile ? importedImagesDirectory : importedMediaDirectory
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)

        let destinationURL = mediaURL.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: url, to: destinationURL)
        return destinationURL
    }

    static func copyVideoDataToDocuments(_ data: Data, fileName: String) throws -> URL {
        let videosURL = try importedMediaDirectory
        try FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)

        let destinationURL = videosURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    static func copyImageDataToDocuments(_ data: Data, fileName: String) throws -> URL {
        let imagesURL = try importedImagesDirectory
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)

        let destinationURL = imagesURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }
}
