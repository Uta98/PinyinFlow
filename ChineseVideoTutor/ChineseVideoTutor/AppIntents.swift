import AppIntents
import Foundation
import UniformTypeIdentifiers

struct ReadScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "スクリーンショットを読み取る"
    static let description = IntentDescription("スクリーンショット画像をPinyinFlowで開き、中国語テキストを抽出して拼音と翻訳を表示します。")
    static let openAppWhenRun = true

    @Parameter(
        title: "画像",
        description: "読み取りたいスクリーンショットや画像",
        supportedTypeIdentifiers: ["public.image"]
    )
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("画像 \(\.$image) を読み取る")
    }

    func perform() async throws -> some IntentResult {
        try PendingScreenshotImportStore.save(image: image)
        return .result()
    }
}

struct PinyinFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadScreenshotIntent(),
            phrases: [
                "\(.applicationName)でスクリーンショットを読み取る",
                "\(.applicationName)で中国語を読み取る",
                "\(.applicationName)で画像を読み取る"
            ],
            shortTitle: "スクショ読取",
            systemImageName: "text.viewfinder"
        )
    }
}

enum PendingScreenshotImportStore {
    private static let defaultsKey = "appIntent.pendingScreenshotPath"

    static func save(image: IntentFile) throws {
        let fileName = normalizedFileName(from: image.filename)
        let url = try FileImporter.copyImageDataToDocuments(image.data, fileName: fileName)
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
    }

    @MainActor
    static func consumePendingURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: defaultsKey), path.isEmpty == false else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        return URL(fileURLWithPath: path)
    }

    private static func normalizedFileName(from filename: String) -> String {
        let originalURL = URL(fileURLWithPath: filename)
        let fileExtension = originalURL.pathExtension.isEmpty ? "png" : originalURL.pathExtension
        return "shortcut-\(UUID().uuidString).\(fileExtension)"
    }
}
