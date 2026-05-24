import Foundation

enum LinkVideoImporter {
    static func downloadVideo(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request(for: url))

        if isVideo(response: response, url: url) {
            return data
        }

        guard let html = String(data: data, encoding: .utf8),
              let videoURL = firstVideoURL(in: html, baseURL: url) else {
            throw AppError.linkVideoNotFound
        }

        let (videoData, videoResponse) = try await URLSession.shared.data(for: request(for: videoURL))
        guard isVideo(response: videoResponse, url: videoURL) else {
            throw AppError.linkVideoNotFound
        }
        return videoData
    }

    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,video/mp4,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("https://www.xiaohongshu.com/", forHTTPHeaderField: "Referer")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private static func isVideo(response: URLResponse, url: URL) -> Bool {
        if let mimeType = response.mimeType?.lowercased(), mimeType.hasPrefix("video/") {
            return true
        }
        return ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    private static func firstVideoURL(in html: String, baseURL: URL) -> URL? {
        let decoded = html
            .replacingOccurrences(of: #"\/"#, with: "/")
            .replacingOccurrences(of: #"\u002F"#, with: "/")
            .replacingOccurrences(of: #"\u0026"#, with: "&")
            .replacingOccurrences(of: "&amp;", with: "&")

        let patterns = [
            #"<meta\s+property=["']og:video(?::url)?["']\s+content=["']([^"']+)["']"#,
            #"<meta\s+content=["']([^"']+)["']\s+property=["']og:video(?::url)?["']"#,
            #""(?:masterUrl|backupUrl|mainUrl|videoUrl|playUrl|url)"\s*:\s*"([^"]+)""#,
            #"https?:[^"'<>\s]+?\.(?:mp4|mov|m4v)(?:\?[^"'<>\s]*)?"#,
            #"https?:\\?/\\?/[^"'<>\s]+?\.(?:mp4|mov|m4v)(?:\?[^"'<>\s]*)?"#,
            #"//[^"'<>\s]+?\.(?:mp4|mov|m4v)(?:\?[^"'<>\s]*)?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
            guard let match = regex.firstMatch(in: decoded, range: range) else { continue }
            let matchRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard let swiftRange = Range(matchRange, in: decoded) else { continue }
            let raw = String(decoded[swiftRange])
                .replacingOccurrences(of: #"\/"#, with: "/")
                .replacingOccurrences(of: "\\", with: "")
                .removingPercentEncoding ?? String(decoded[swiftRange])
            if let absoluteURL = URL(string: raw), absoluteURL.scheme?.hasPrefix("http") == true {
                return absoluteURL
            }
            if raw.hasPrefix("//"), let schemeRelativeURL = URL(string: "https:\(raw)") {
                return schemeRelativeURL
            }
            if let relativeURL = URL(string: raw, relativeTo: baseURL)?.absoluteURL {
                return relativeURL
            }
        }

        return nil
    }
}
