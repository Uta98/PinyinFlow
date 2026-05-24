import SwiftUI

struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var whisperModel: String
    @Binding var translationEngine: String
    @Binding var transcriptionEngine: String
    @Binding var translationTarget: String
    @Binding var textScale: Double
    @Environment(\.dismiss) private var dismiss

    private let whisperModels = [
        "tiny",
        "base",
        "small",
        "medium",
        "large-v3-v20240930_626MB"
    ]

    private let textSizes: [(label: String, value: Double)] = [
        ("小", 0.92),
        ("中", 1.0),
        ("大", 1.2)
    ]
    private let translationEngines = [
        ("deepl", "DeepL"),
        ("ios", "iOS純正")
    ]
    private let transcriptionEngines = [
        ("whisperkit", "WhisperKit"),
        ("ios", "iOS純正")
    ]

    private var textSizeSelection: Binding<Double> {
        Binding(
            get: {
                textSizes.min(by: { abs($0.value - textScale) < abs($1.value - textScale) })?.value ?? 1.0
            },
            set: { textScale = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("翻訳ツール") {
                    Picker("翻訳", selection: $translationEngine) {
                        ForEach(translationEngines, id: \.0) { engine in
                            Text(engine.1).tag(engine.0)
                        }
                    }

                    Picker("翻訳先", selection: $translationTarget) {
                        ForEach(TranslationTargetLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }

                    if translationEngine == "deepl" {
                        NavigationLink("DeepL APIキー") {
                            DeepLAPIKeySettingsView(apiKey: $apiKey)
                        }
                    }
                }

                Section {
                    SettingsDescriptionText("DeepLはAPIキーを使って翻訳します。iOS純正翻訳は端末の対応状況と言語モデルに依存します。")
                }

                Section("文字起こしツール") {
                    Picker("文字起こし", selection: $transcriptionEngine) {
                        ForEach(transcriptionEngines, id: \.0) { engine in
                            Text(engine.1).tag(engine.0)
                        }
                    }

                    if transcriptionEngine == "whisperkit" {
                        Picker("WhisperKit モデル", selection: $whisperModel) {
                            ForEach(whisperModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                }

                Section {
                    SettingsDescriptionText("WhisperKitは端末内で文字起こしします。iOS純正はSpeechフレームワークを使うため、音声認識の許可と端末/言語の対応状況に依存します。")
                }

                Section("表示") {
                    Picker("文字サイズ", selection: textSizeSelection) {
                        ForEach(textSizes, id: \.value) { size in
                            Text(size.label).tag(size.value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("App Store公開準備") {
                    NavigationLink("プライバシーとデータ利用") {
                        PrivacyInfoView()
                    }
                    Link("App Store Review Guidelines", destination: URL(string: "https://developer.apple.com/app-store/review/guidelines/")!)
                    Link("App Privacy Details", destination: URL(string: "https://developer.apple.com/app-store/app-privacy-details/")!)
                }

                Section("アプリ情報") {
                    LabeledContent("バージョン", value: appVersionText)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct SettingsDescriptionText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color(.systemGroupedBackground))
    }
}

private struct DeepLAPIKeySettingsView: View {
    @Binding var apiKey: String

    var body: some View {
        Form {
            Section("DeepL APIキー") {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Text("DeepLを使う場合のみ設定します。iOS純正翻訳を使う場合、このキーは不要です。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("DeepL APIキー")
    }
}

private struct PrivacyInfoView: View {
    var body: some View {
        List {
            Section("端末内に保存するデータ") {
                Text("取り込んだ動画・音声、入力した中国語テキスト、文字起こし、拼音、翻訳、お気に入り状態をアプリ内のDocuments領域に保存します。")
            }

            Section("外部サービス") {
                Text("DeepLを選択した場合、中国語テキストをDeepL APIへ送信して翻訳を作成します。iOS純正翻訳を選択した場合はAppleの翻訳機能を使用します。")
            }

            Section("権限") {
                Text("iOS純正の音声認識を使う場合、音声認識の許可が必要です。写真から動画を選ぶ場合は写真ライブラリの選択UIを使用します。")
            }
        }
        .navigationTitle("プライバシー")
    }
}
