import SwiftUI
import UIKit

struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var googleTranslateAPIKey: String
    @Binding var azureTranslateAPIKey: String
    @Binding var azureTranslateRegion: String
    @Binding var openAIAPIKey: String
    @Binding var assemblyAIAPIKey: String
    @Binding var whisperModel: String
    @Binding var translationEngine: String
    @Binding var transcriptionEngine: String
    @Binding var translationTarget: String
    @Binding var textScale: Double
    var showsDoneButton = true
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
        ("openai", "OpenAI Whisper API"),
        ("assemblyai", "AssemblyAI")
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
                .listRowBackground(AppTheme.settingsRowBackground)

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
                    } else if transcriptionEngine == "assemblyai" {
                        NavigationLink("AssemblyAI APIキー") {
                            APIKeySettingsView(
                                title: "AssemblyAI APIキー",
                                apiKey: $assemblyAIAPIKey,
                                note: "AssemblyAIを使う場合のみ設定します。音声データをAssemblyAIへ送信して文字起こしします。"
                            )
                        }
                    }
                } header: {
                    Text("文字起こしツール")
                } footer: {
                    SettingsDescriptionText("WhisperKitは端末内で処理します。iOS純正はSpeechフレームワーク、OpenAI Whisper APIとAssemblyAIはクラウド文字起こしを使います。")
                }
                .listRowBackground(AppTheme.settingsRowBackground)

                Section("表示") {
                    Picker("文字サイズ", selection: textSizeSelection) {
                        ForEach(textSizes, id: \.value) { size in
                            Text(size.label).tag(size.value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(AppTheme.settingsRowBackground)

                Section("サポートと情報") {
                    NavigationLink("プライバシーとデータ利用") {
                        PrivacyInfoView()
                    }
                    NavigationLink("プライバシーポリシー") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("利用規約") {
                        TermsOfUseView()
                    }
                    NavigationLink("お問い合わせ") {
                        ContactInfoView()
                    }
                }
                .listRowBackground(AppTheme.settingsRowBackground)

                Section("アプリ情報") {
                    LabeledContent("バージョン", value: appVersionText)
                }
                .listRowBackground(AppTheme.settingsRowBackground)
            }
            .navigationTitle("設定")
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .tint(AppTheme.settingsAccent)
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
            .listRowBackground(AppTheme.settingsRowBackground)

            Section {
                Text(note)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(AppTheme.settingsRowBackground)
        }
        .navigationTitle(title)
        .scrollContentBackground(.hidden)
        .background(AppTheme.appBackground)
        .tint(AppTheme.settingsAccent)
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
            .listRowBackground(AppTheme.settingsRowBackground)

            Section {
                Text("Azure AI Translator リソースのキーとリージョンを設定します。")
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(AppTheme.settingsRowBackground)
        }
        .navigationTitle("Azure Translator API")
        .scrollContentBackground(.hidden)
        .background(AppTheme.appBackground)
        .tint(AppTheme.settingsAccent)
    }
}

private struct PrivacyInfoView: View {
    var body: some View {
        SettingsTextPage {
            SettingsTextBlock(
                title: "端末内に保存するデータ",
                text: "取り込んだ動画・音声、入力した中国語テキスト、文字起こし、拼音、翻訳、お気に入り状態をアプリ内のDocuments領域に保存します。"
            )
            SettingsTextBlock(
                title: "外部サービス",
                text: "DeepL、Google Cloud Translation、Azure AI Translatorを選択した場合、中国語テキストを各APIへ送信して翻訳を作成します。OpenAI Whisper API、AssemblyAIを選択した場合、音声データを各APIへ送信して文字起こしします。iOS純正翻訳やWhisperKitは選択した機能の範囲で端末側の処理を使います。"
            )
            SettingsTextBlock(
                title: "広告",
                text: "Google Mobile Ads SDKを使って広告を表示します。広告配信に関するデータの扱いは、GoogleおよびAdMobの設定に従います。"
            )
            SettingsTextBlock(
                title: "権限",
                text: "iOS純正の音声認識を使う場合、音声認識の許可が必要です。写真から動画を選ぶ場合は写真ライブラリの選択UIを使用します。"
            )
        }
        .navigationTitle("プライバシー")
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        SettingsTextPage {
            SettingsTextBlock(
                title: "収集・保存する情報",
                text: "PinyinFlowは、ユーザーが取り込んだ動画・音声・テキスト、文字起こし結果、拼音、翻訳、お気に入り情報を端末内に保存します。"
            )
            SettingsTextBlock(
                title: "外部送信",
                text: "設定でクラウド翻訳またはクラウド文字起こしを選択した場合、処理に必要なテキストまたは音声データを選択中の外部サービスへ送信します。APIキーは端末内に保存されます。"
            )
            SettingsTextBlock(
                title: "広告",
                text: "本アプリはGoogle Mobile Ads SDKを利用して広告を表示する場合があります。広告表示に伴うデータの扱いは、Googleのポリシーとユーザーの同意設定に従います。"
            )
            SettingsTextBlock(
                title: "削除",
                text: "履歴の長押し削除により、保存済みの動画・音声・字幕データを削除できます。アプリを削除すると端末内に保存されたデータも削除されます。"
            )
        }
        .navigationTitle("プライバシーポリシー")
    }
}

private struct TermsOfUseView: View {
    var body: some View {
        SettingsTextPage {
            SettingsTextBlock(
                title: "利用目的",
                text: "PinyinFlowは、中国語の学習補助を目的として、動画・音声・テキストに拼音と翻訳を付与するアプリです。翻訳や文字起こしの結果は完全性を保証するものではありません。"
            )
            SettingsTextBlock(
                title: "ユーザーの責任",
                text: "取り込む動画・音声・テキストは、ユーザー自身が利用権限を持つものを使用してください。第三者の権利を侵害する利用は禁止します。"
            )
            SettingsTextBlock(
                title: "外部サービス",
                text: "外部APIを利用する場合、各サービスの利用規約、料金、制限が適用されます。APIキーの管理はユーザー自身の責任で行ってください。"
            )
        }
        .navigationTitle("利用規約")
    }
}

private struct ContactInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    UIApplication.shared.open(mailURL)
                } label: {
                    Label("メールで問い合わせる", systemImage: "envelope")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.settingsAccent)

                Text("メールアプリを開きます。端末、iOSバージョン、アプリバージョン、発生している内容を添えて送信してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.appBackground)
        .navigationTitle("お問い合わせ")
    }

    private var mailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "PinyinFlow お問い合わせ"),
            URLQueryItem(name: "body", value: """
            PinyinFlow お問い合わせ

            端末:
            iOS:
            アプリバージョン:
            内容:
            """)
        ]
        return components.url!
    }
}

private struct SettingsTextPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.appBackground)
    }
}

private struct SettingsTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
    }
}
