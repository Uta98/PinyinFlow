import SwiftUI

struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var googleTranslateAPIKey: String
    @Binding var azureTranslateAPIKey: String
    @Binding var azureTranslateRegion: String
    @Binding var openAIAPIKey: String
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
        ("ios", "iOS純正"),
        ("deepl", "DeepL"),
        ("google", "Google Cloud Translation"),
        ("azure", "Azure AI Translator")
    ]
    private let transcriptionEngines = [
        ("ios", "iOS純正"),
        ("whisperkit", "WhisperKit"),
        ("openai", "OpenAI Whisper API")
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
                Section {
                    Picker("翻訳先", selection: $translationTarget) {
                        ForEach(TranslationTargetLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }

                    Picker("ツール", selection: $translationEngine) {
                        ForEach(translationEngines, id: \.0) { engine in
                            Text(engine.1).tag(engine.0)
                        }
                    }

                    if translationEngine == "deepl" {
                        NavigationLink("DeepL APIキー") {
                            APIKeySettingsView(
                                title: "DeepL APIキー",
                                apiKey: $apiKey,
                                note: "DeepLを使う場合のみ設定します。iOS純正翻訳を使う場合、このキーは不要です。"
                            )
                        }
                    } else if translationEngine == "google" {
                        NavigationLink("Google Cloud APIキー") {
                            APIKeySettingsView(
                                title: "Google Cloud APIキー",
                                apiKey: $googleTranslateAPIKey,
                                note: "Cloud Translation API を有効化したGoogle CloudプロジェクトのAPIキーを設定します。"
                            )
                        }
                    } else if translationEngine == "azure" {
                        NavigationLink("Azure Translator API") {
                            AzureTranslatorSettingsView(
                                apiKey: $azureTranslateAPIKey,
                                region: $azureTranslateRegion
                            )
                        }
                    }
                } header: {
                    Text("翻訳ツール")
                } footer: {
                    SettingsDescriptionText("iOS純正は端末の対応状況に依存します。DeepL、Google Cloud、Azureは各サービスへ中国語テキストを送信して翻訳します。")
                }

                Section {
                    Picker("ツール", selection: $transcriptionEngine) {
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
                    } else if transcriptionEngine == "openai" {
                        NavigationLink("OpenAI APIキー") {
                            APIKeySettingsView(
                                title: "OpenAI APIキー",
                                apiKey: $openAIAPIKey,
                                note: "OpenAI Whisper APIを使う場合のみ設定します。音声データをOpenAI APIへ送信して文字起こしします。"
                            )
                        }
                    }
                } header: {
                    Text("文字起こしツール")
                } footer: {
                    SettingsDescriptionText("WhisperKitは端末内で処理します。iOS純正はSpeechフレームワーク、OpenAI Whisper APIはクラウド文字起こしを使います。")
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
            .padding(.top, 2)
    }
}

private struct APIKeySettingsView: View {
    let title: String
    @Binding var apiKey: String
    let note: String

    var body: some View {
        Form {
            Section(title) {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Text(note)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
    }
}

private struct AzureTranslatorSettingsView: View {
    @Binding var apiKey: String
    @Binding var region: String

    var body: some View {
        Form {
            Section("Azure Translator API") {
                SecureField("Subscription Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Region 例: japaneast", text: $region)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Text("Azure AI Translator リソースのキーとリージョンを設定します。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Azure Translator API")
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
