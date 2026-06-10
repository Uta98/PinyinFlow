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
        ("小", 0.86),
        ("中", 0.92),
        ("大", 1.2)
    ]
    private let translationEngines = [
        ("ios", "iOS純正"),
        ("deepl", "DeepL")
    ]
    private let transcriptionEngines = [
        ("whisperkit", "WhisperKit")
    ]

    private var textSizeSelection: Binding<Double> {
        Binding(
            get: {
                textSizes.min(by: { abs($0.value - textScale) < abs($1.value - textScale) })?.value ?? 1.0
            },
            set: { textScale = $0 }
        )
    }

    private var translationCredentialWarning: String? {
        switch translationEngine {
        case "deepl" where apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return "DeepLを使うにはAPIキーの設定が必要です。"
        default:
            return nil
        }
    }

    private var transcriptionCredentialWarning: String? {
        nil
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
                    }

                    if let translationCredentialWarning {
                        SettingsWarningText(translationCredentialWarning)
                    }
                } header: {
                    Text("翻訳ツール")
                } footer: {
                    SettingsDescriptionText("iOS純正は端末の翻訳機能と言語データを利用します。このアプリの現在の実装ではiOS 26以降が必要で、言語データの準備に失敗すると翻訳できない場合があります。DeepLを選ぶ場合は、中国語テキストをDeepL APIへ送信して翻訳します。")
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
                    }

                    if let transcriptionCredentialWarning {
                        SettingsWarningText(transcriptionCredentialWarning)
                    }
                } header: {
                    Text("文字起こしツール")
                } footer: {
                    SettingsDescriptionText("現在はWhisperKitのみ利用できます。無料で利用でき、音声データを外部APIへ送らず端末内で文字起こしを処理するため、プライバシーとセキュリティ面でも安心して使えます。")
                }
                .listRowBackground(AppTheme.settingsRowBackground)

                Section("表示") {
                    Picker("文字サイズ", selection: textSizeSelection) {
                        ForEach(textSizes, id: \.value) { size in
                            Text(size.label).tag(size.value)
                        }
                    }
                    .pickerStyle(.segmented)
                    SettingsDescriptionText("字幕とお気に入りに表示される中国語・拼音・翻訳の文字サイズに反映されます。")
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
                    NavigationLink("ライセンス") {
                        ThirdPartyLicensesView()
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

private struct SettingsWarningText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.settingsAccent)
            .padding(.vertical, 2)
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

private struct PrivacyInfoView: View {
    var body: some View {
        SettingsTextPage {
            SettingsTextBlock(
                title: "端末内に保存するデータ",
                text: "取り込んだ動画・音声、入力した中国語テキスト、文字起こし、拼音、翻訳、お気に入り状態をアプリ内のDocuments領域に保存します。"
            )
            SettingsTextBlock(
                title: "外部サービス",
                text: "DeepLを選択した場合、中国語テキストをDeepL APIへ送信して翻訳を作成します。iOS純正翻訳は端末の対応状況に応じてAppleのシステム機能を利用します。WhisperKitは音声データを外部APIへ送らず端末内で文字起こしします。"
            )
            SettingsTextBlock(
                title: "広告",
                text: "Google Mobile Ads SDKを使って広告を表示します。広告配信に関するデータの扱いは、GoogleおよびAdMobの設定に従います。"
            )
            SettingsTextBlock(
                title: "権限",
                text: "写真から動画を選ぶ場合は写真ライブラリの選択UIを使用します。ファイルを取り込む場合は、ユーザーが選択したファイルのみ読み込みます。"
            )
        }
        .navigationTitle("プライバシー")
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        SettingsTextPage {
            SettingsTextBlock(
                title: "概要",
                text: "PinyinFlowは、中国語の動画、音声、テキストに文字起こし、拼音、翻訳を付与し、学習を補助するアプリです。本ポリシーでは、本アプリにおける情報の取り扱いについて説明します。"
            )
            SettingsTextBlock(
                title: "1. アプリ内に保存される情報",
                text: "本アプリは、ユーザーが取り込んだ動画・音声ファイル、入力した中国語テキスト、文字起こし結果、拼音、翻訳、お気に入り状態、履歴情報、アプリ設定を端末内に保存します。これらの情報は、履歴表示、再生、字幕表示、お気に入り表示、設定の維持のために使用されます。"
            )
            SettingsTextBlock(
                title: "2. 外部サービスへの送信",
                text: "本アプリでは、設定により翻訳ツールや文字起こしツールを選択できます。WhisperKitを利用する場合、文字起こしは端末内で処理され、音声データを外部APIへ送信しません。iOS純正翻訳を利用する場合、処理は端末の対応状況に応じてAppleのシステム機能により行われます。DeepLを選択した場合、翻訳に必要な中国語テキストがDeepL APIへ送信されます。外部サービスを利用する場合、各サービスの利用規約およびプライバシーポリシーが適用されます。"
            )
            SettingsTextBlock(
                title: "3. APIキーの取り扱い",
                text: "ユーザーが入力した外部サービスのAPIキーは、端末内に保存され、選択した翻訳または文字起こし機能を実行するために使用されます。本アプリは、APIキーを開発者のサーバーへ送信しません。"
            )
            SettingsTextBlock(
                title: "4. 広告",
                text: "本アプリは、Google Mobile Ads SDKを利用して広告を表示する場合があります。広告配信に伴い、Googleまたは広告配信パートナーが広告識別子、端末情報、広告表示や操作に関する情報などを取り扱う場合があります。広告に関する情報の取り扱いは、Googleのポリシーおよびユーザーの同意設定に従います。"
            )
            SettingsTextBlock(
                title: "5. アクセス権限",
                text: "本アプリは、ユーザーが選択した機能を提供するために、ファイル、写真ライブラリ、音声認識などへのアクセス許可を求める場合があります。これらの権限は、ユーザーが該当機能を利用する時にのみ使用されます。"
            )
            SettingsTextBlock(
                title: "6. データの削除",
                text: "履歴の長押し削除により、保存済みの動画・音声・字幕データを削除できます。アプリを削除すると端末内に保存されたデータも削除されます。"
            )
            SettingsTextBlock(
                title: "7. 免責",
                text: "文字起こし、拼音、翻訳の結果は、利用するツールや入力内容により誤りが含まれる場合があります。本アプリは、学習補助を目的としたものであり、翻訳結果や文字起こし結果の完全性、正確性を保証するものではありません。"
            )
            SettingsTextBlock(
                title: "8. ポリシーの変更",
                text: "本ポリシーは、必要に応じて変更される場合があります。重要な変更がある場合は、本ページまたはアプリ内でお知らせします。"
            )
            SettingsTextBlock(
                title: "9. お問い合わせ",
                text: "本ポリシーに関するお問い合わせは、アプリ内のお問い合わせ機能からご連絡ください。"
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
                text: "DeepLなど外部APIを利用する場合、各サービスの利用規約、料金、制限が適用されます。APIキーの管理はユーザー自身の責任で行ってください。"
            )
        }
        .navigationTitle("利用規約")
    }
}

private struct ThirdPartyLicensesView: View {
    var body: some View {
        SettingsTextPage {
            SettingsTextBlock(
                title: "WhisperKit / argmax-oss-swift",
                text: "PinyinFlowは、文字起こし機能の一部にWhisperKitを利用しています。WhisperKitはMIT Licenseで提供されており、以下に著作権表示およびライセンス全文を記載します。"
            )

            Text(Self.whisperKitLicenseText)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineSpacing(3)
        }
        .navigationTitle("ライセンス")
    }

    private static let whisperKitLicenseText = """
    MIT License

    Copyright (c) 2024 argmax, inc.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}

private struct ContactInfoView: View {
    private let formURL = URL(string: "https://forms.gle/c68wDA8eACeB888u7")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    UIApplication.shared.open(formURL)
                } label: {
                    Label("フォームで問い合わせる", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.settingsAccent)

                Text("Google Formsを開きます。端末、iOSバージョン、アプリバージョン、発生している内容を添えて送信してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.appBackground)
        .navigationTitle("お問い合わせ")
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
        .background(Color(.systemBackground))
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
