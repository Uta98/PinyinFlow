import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppTheme {
    static let titleAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.965, blue: 0.965, alpha: 1)
            : UIColor(red: 0.48, green: 0.00, blue: 0.04, alpha: 1)
    })
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.18, blue: 0.20, alpha: 1)
            : UIColor(red: 0.78, green: 0.00, blue: 0.06, alpha: 1)
    })
    static let settingsAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.58, blue: 0.60, alpha: 1)
            : UIColor(red: 0.78, green: 0.00, blue: 0.06, alpha: 1)
    })
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.025, blue: 0.035, alpha: 1)
            : UIColor(red: 1.00, green: 0.965, blue: 0.965, alpha: 1)
    })
    static let settingsRowBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.035, blue: 0.05, alpha: 1)
            : UIColor.white
    })
    static let accentSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.18, blue: 0.20, alpha: 0.20)
            : UIColor(red: 0.78, green: 0.00, blue: 0.06, alpha: 0.11)
    })
    static let accentStroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.28, blue: 0.30, alpha: 0.50)
            : UIColor(red: 0.78, green: 0.00, blue: 0.06, alpha: 0.36)
    })
    static let textCardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.04, blue: 0.052, alpha: 1)
            : UIColor.white
    })
}

struct AppView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("deepl.apiKey") private var apiKey = ""
    @AppStorage("googleTranslate.apiKey") private var googleTranslateAPIKey = ""
    @AppStorage("azureTranslate.apiKey") private var azureTranslateAPIKey = ""
    @AppStorage("azureTranslate.region") private var azureTranslateRegion = ""
    @AppStorage("openai.apiKey") private var openAIAPIKey = ""
    @AppStorage("assemblyAI.apiKey") private var assemblyAIAPIKey = ""
    @AppStorage("whisperkit.model") private var whisperModel = "base"
    @AppStorage("translation.engine") private var translationEngine = "ios"
    @AppStorage("translation.targetLanguage") private var translationTarget = TranslationTargetLanguage.japanese.rawValue
    @AppStorage("transcription.engine") private var transcriptionEngine = "whisperkit"
    @AppStorage("transcript.textScale") private var textScale = 1.0
    @AppStorage("subtitle.showPinyin") private var showSubtitlePinyin = true
    @AppStorage("subtitle.showChinese") private var showSubtitleChinese = true
    @AppStorage("subtitle.showTranslation") private var showSubtitleTranslation = true
    @AppStorage("player.playbackRate") private var playbackRate = 1.0
    @AppStorage("player.subtitleLoopPause") private var subtitleLoopPause = 0.4
    @AppStorage("onboarding.privacyAccepted") private var privacyAccepted = false
    @State private var isShowingTextSheet = false
    @State private var isShowingPhotoPicker = false
    @State private var isImportingVideo = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var inputText = ""
    @State private var homeSearchText = ""

    var body: some View {
        Group {
            if viewModel.shouldShowWorkspace == false {
                TabView {
                    NavigationStack {
                        ImportHomeView(
                            history: viewModel.history,
                            textScale: textScale,
                            searchText: $homeSearchText,
                            openSession: { session, startTime in
                                viewModel.loadSession(session, startTime: startTime)
                            },
                            deleteSession: viewModel.deleteSession,
                            importFile: {
                                isImportingVideo = true
                            },
                            importPhoto: {
                                isShowingPhotoPicker = true
                            },
                            importText: {
                                isShowingTextSheet = true
                            }
                        )
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .tabItem {
                        Label("ホーム", systemImage: "house")
                    }

                    FavoritesHomeView(
                        history: viewModel.history,
                        textScale: textScale,
                        openSession: { session, startTime in
                            viewModel.loadSession(session, startTime: startTime)
                        },
                        toggleFavorite: viewModel.toggleFavorite(sessionID:segmentID:)
                    )
                    .tabItem {
                        Label("お気に入り", systemImage: "star")
                    }

                    SettingsView(
                        apiKey: $apiKey,
                        googleTranslateAPIKey: $googleTranslateAPIKey,
                        azureTranslateAPIKey: $azureTranslateAPIKey,
                        azureTranslateRegion: $azureTranslateRegion,
                        openAIAPIKey: $openAIAPIKey,
                        assemblyAIAPIKey: $assemblyAIAPIKey,
                        whisperModel: $whisperModel,
                        translationEngine: $translationEngine,
                        transcriptionEngine: $transcriptionEngine,
                        translationTarget: $translationTarget,
                        textScale: $textScale,
                        subtitleLoopPause: $subtitleLoopPause,
                        showsDoneButton: false
                    )
                    .tabItem {
                        Label("設定", systemImage: "gearshape")
                    }
                }
                .tint(AppTheme.settingsAccent)
            } else {
                TranscriptWorkspaceView(
                    viewModel: viewModel,
                    textScale: textScale,
                    playbackRate: $playbackRate,
                    loopPauseDuration: subtitleLoopPause,
                    showPinyin: $showSubtitlePinyin,
                    showChinese: $showSubtitleChinese,
                    showTranslation: $showSubtitleTranslation
                )
            }
        }
        .overlay {
            AppleTranslationTaskHost()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .sheet(isPresented: $isShowingTextSheet) {
            TextImportSheet(inputText: $inputText) { text in
                Task {
                    await viewModel.importText(text)
                }
                inputText = ""
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .any(of: [.videos, .images])
        )
        .sheet(isPresented: Binding(
            get: { privacyAccepted == false },
            set: { isPresented in
                if isPresented == false {
                    privacyAccepted = true
                }
            }
        )) {
            FirstLaunchPrivacyView {
                privacyAccepted = true
            }
        }
        .fileImporter(
            isPresented: $isImportingVideo,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .audio, .image],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.importAndProcess(result)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                let isImage = item.supportedContentTypes.contains { $0.conforms(to: .image) }
                viewModel.prepareImportingPlaceholder(name: isImage ? "写真の画像" : "写真の動画")
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.importPhotoMedia(data: data, isImage: isImage)
                } else {
                    viewModel.showHome()
                }
                selectedPhotoItem = nil
            }
        }
        .onAppear {
            normalizeToolSelections()
            configurePlaybackAudioSession()
            configureViewModelServices()
            processPendingIntentImageIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            processPendingIntentImageIfNeeded()
        }
        .onChange(of: apiKey) { _, newValue in
            configureViewModelServices(apiKey: newValue)
        }
        .onChange(of: googleTranslateAPIKey) { _, newValue in
            configureViewModelServices(googleTranslateAPIKey: newValue)
        }
        .onChange(of: azureTranslateAPIKey) { _, newValue in
            configureViewModelServices(azureTranslateAPIKey: newValue)
        }
        .onChange(of: azureTranslateRegion) { _, newValue in
            configureViewModelServices(azureTranslateRegion: newValue)
        }
        .onChange(of: openAIAPIKey) { _, newValue in
            configureViewModelServices(openAIAPIKey: newValue)
        }
        .onChange(of: assemblyAIAPIKey) { _, newValue in
            configureViewModelServices(assemblyAIAPIKey: newValue)
        }
        .onChange(of: whisperModel) { _, newValue in
            configureViewModelServices(whisperModel: newValue)
        }
        .onChange(of: translationEngine) { _, newValue in
            configureViewModelServices(translationEngine: newValue)
        }
        .onChange(of: translationTarget) { _, newValue in
            configureViewModelServices(translationTarget: newValue)
        }
        .onChange(of: transcriptionEngine) { _, newValue in
            configureViewModelServices(transcriptionEngine: newValue)
        }
    }

    private func configurePlaybackAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            assertionFailure("Failed to configure playback audio session: \(error)")
        }
    }

    private func normalizeToolSelections() {
        if translationEngine != "ios", translationEngine != "deepl" {
            translationEngine = "ios"
        }
        if transcriptionEngine != "whisperkit" {
            transcriptionEngine = "whisperkit"
        }
    }

    private func configureViewModelServices(
        apiKey: String? = nil,
        googleTranslateAPIKey: String? = nil,
        azureTranslateAPIKey: String? = nil,
        azureTranslateRegion: String? = nil,
        openAIAPIKey: String? = nil,
        assemblyAIAPIKey: String? = nil,
        whisperModel: String? = nil,
        translationEngine: String? = nil,
        transcriptionEngine: String? = nil,
        translationTarget: String? = nil
    ) {
        let nextTranslationEngine = translationEngine ?? self.translationEngine
        let supportedTranslationEngine = (nextTranslationEngine == "ios" || nextTranslationEngine == "deepl") ? nextTranslationEngine : "ios"
        let nextTranscriptionEngine = transcriptionEngine ?? self.transcriptionEngine
        let supportedTranscriptionEngine = nextTranscriptionEngine == "whisperkit" ? nextTranscriptionEngine : "whisperkit"

        viewModel.configureServices(
            apiKey: apiKey ?? self.apiKey,
            googleTranslateAPIKey: googleTranslateAPIKey ?? self.googleTranslateAPIKey,
            azureTranslateAPIKey: azureTranslateAPIKey ?? self.azureTranslateAPIKey,
            azureTranslateRegion: azureTranslateRegion ?? self.azureTranslateRegion,
            openAIAPIKey: openAIAPIKey ?? self.openAIAPIKey,
            assemblyAIAPIKey: assemblyAIAPIKey ?? self.assemblyAIAPIKey,
            whisperModel: whisperModel ?? self.whisperModel,
            translationEngine: supportedTranslationEngine,
            transcriptionEngine: supportedTranscriptionEngine,
            translationTarget: translationTarget ?? self.translationTarget
        )
    }

    private func processPendingIntentImageIfNeeded() {
        guard let url = PendingScreenshotImportStore.consumePendingURL() else { return }
        Task {
            await viewModel.importImageFromIntent(url: url)
        }
    }
}

private struct FirstLaunchPrivacyView: View {
    let accept: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("動画・音声・画像・テキスト、字幕、拼音、翻訳、お気に入りは端末内に保存されます。", systemImage: "iphone")
                    Label("DeepLを選ぶと翻訳対象の中国語テキストがDeepL APIへ送信されます。WhisperKitは端末内で文字起こしします。", systemImage: "cloud")
                } header: {
                    Text("PinyinFlowのデータ利用")
                }

                Section {
                    Text("写真、ファイル、音声認識などの権限は、必要な機能を使う時だけiOSの確認画面が表示されます。設定はあとから設定アプリで変更できます。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("はじめに")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("同意して始める") {
                        accept()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct ImportHomeView: View {
    let history: [TranscriptSession]
    let textScale: Double
    @Binding var searchText: String
    let openSession: (TranscriptSession, TimeInterval?) -> Void
    let deleteSession: (TranscriptSession) -> Void
    let importFile: () -> Void
    let importPhoto: () -> Void
    let importText: () -> Void
    @State private var sessionPendingDeletion: TranscriptSession?

    private let nativeAdUnitID = AdMobAdUnits.native

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [HistorySearchResult] {
        guard query.isEmpty == false else { return [] }
        return history.flatMap { session in
            session.segments.compactMap { segment in
                guard TranscriptSearch.matches(segment, query: query) else { return nil }
                return HistorySearchResult(
                    session: session,
                    segment: segment,
                    matchText: TranscriptSearch.matchText(for: segment, query: query)
                )
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeaderView(
                        importFile: importFile,
                        importPhoto: importPhoto,
                        importText: importText
                    )

                    SearchField(text: $searchText)

                    if history.isEmpty {
                        ContentUnavailableView(
                            "履歴はまだありません",
                            systemImage: "clock",
                            description: Text("取り込んだ動画、音声、画像、テキストと字幕はここに保存されます。")
                        )
                        .padding(.top, 40)
                    } else if query.isEmpty {
                        LazyVGrid(columns: columns(for: proxy.size), spacing: 10) {
                            ForEach(Array(history.enumerated()), id: \.element.id) { index, session in
                                HistoryTile(session: session) {
                                    openSession(session, nil)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        sessionPendingDeletion = session
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }

                                if AdMobRuntime.adsDisabled == false, (index + 1).isMultiple(of: 5) {
                                    NativeAdHistoryTile(adUnitID: nativeAdUnitID)
                                }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            if searchResults.isEmpty {
                                ContentUnavailableView.search(text: query)
                                    .padding(.top, 40)
                            } else {
                                ForEach(searchResults) { result in
                                    SearchResultRow(result: result, query: query) {
                                        openSession(result.session, result.segment.startTime)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            sessionPendingDeletion = result.session
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.appBackground)
        }
        .alert("動画を削除しますか？", isPresented: Binding(
            get: { sessionPendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    sessionPendingDeletion = nil
                }
            }
        )) {
            Button("キャンセル", role: .cancel) {
                sessionPendingDeletion = nil
            }
            Button("削除", role: .destructive) {
                if let session = sessionPendingDeletion {
                    deleteSession(session)
                }
                sessionPendingDeletion = nil
            }
        } message: {
            Text("保存済みの動画と字幕を履歴から削除します。")
        }
    }

    private func columns(for size: CGSize) -> [GridItem] {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isLandscape = size.width > size.height
        let count = (isPad || isLandscape) ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }
}

private struct AppTitleView: View {
    var body: some View {
        Text("PinyinFlow")
            .font(.system(size: 42, weight: .heavy, design: .rounded))
            .foregroundStyle(AppTheme.titleAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct HomeHeaderView: View {
    let importFile: () -> Void
    let importPhoto: () -> Void
    let importText: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AppTitleView()

            Spacer(minLength: 8)

            Menu {
                Button(action: importFile) {
                    Label("ファイル", systemImage: "folder")
                }
                Button(action: importPhoto) {
                    Label("写真", systemImage: "photo.on.rectangle")
                }
                Button(action: importText) {
                    Label("テキスト", systemImage: "text.quote")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textCardSurface)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.titleAccent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("取り込み")
        }
        .padding(.top, 4)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("中国語・拼音・翻訳を検索", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.primary)

            if text.isEmpty == false {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索をクリア")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(AppTheme.textCardSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct HistoryBannerAdView: View {
    private let adUnitID = AdMobAdUnits.banner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.accentSoft)
                .overlay {
                    HorizontalAdBannerView(adUnitID: adUnitID)
                        .frame(width: 320, height: 50)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.accentStroke, lineWidth: 1)
                }
        }
    }
}

private struct NativeAdHistoryTile: View {
    let adUnitID: String

    var body: some View {
        NativeAdCardView(adUnitID: adUnitID)
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct TextImportSheet: View {
    @Binding var inputText: String
    let importText: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var canImport: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("中国語テキスト") {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 180)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        inputText = UIPasteboard.general.string ?? inputText
                    } label: {
                        Label("貼り付け", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .navigationTitle("テキストから作成")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        importText(inputText)
                        dismiss()
                    }
                    .disabled(canImport == false)
                }
            }
        }
    }
}

private struct HistorySearchResult: Identifiable {
    var id: String { "\(session.id)-\(segment.id)" }
    var session: TranscriptSession
    var segment: TranscriptSegment
    var matchText: String
}

private struct FavoriteSubtitleResult: Identifiable {
    var id: String { "\(session.id)-\(segment.id)" }
    var session: TranscriptSession
    var segment: TranscriptSegment
}

private enum TranscriptSearch {
    static func matches(_ segment: TranscriptSegment, query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return true }

        return contains(TranscriptTextCleaner.clean(segment.sourceText), query: trimmedQuery)
            || contains(TranscriptTextCleaner.clean(segment.japaneseTranslation), query: trimmedQuery)
            || contains(pinyinText(for: segment), query: trimmedQuery)
    }

    static func matchText(for segment: TranscriptSegment, query: String) -> String {
        let source = TranscriptTextCleaner.cleanChinese(segment.sourceText)
        let translation = TranscriptTextCleaner.clean(segment.japaneseTranslation)
        if contains(translation, query: query), contains(source, query: query) == false {
            return translation
        }
        return source.isEmpty ? translation : source
    }

    private static func contains(_ text: String, query: String) -> Bool {
        normalized(text).contains(normalized(query))
    }

    private static func pinyinText(for segment: TranscriptSegment) -> String {
        segment.pinyinTokens
            .map(\.pinyin)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct FavoritesHomeView: View {
    let history: [TranscriptSession]
    let textScale: Double
    let openSession: (TranscriptSession, TimeInterval?) -> Void
    let toggleFavorite: (TranscriptSession.ID, TranscriptSegment.ID) -> Void
    @State private var searchText = ""
    private let nativeAdUnitID = AdMobAdUnits.favoriteNative

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var favoriteResults: [FavoriteSubtitleResult] {
        history.flatMap { session in
            session.segments.compactMap { segment in
                guard segment.isFavorite else { return nil }
                guard query.isEmpty || TranscriptSearch.matches(segment, query: query) else { return nil }
                return FavoriteSubtitleResult(session: session, segment: segment)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("お気に入り")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.titleAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .accessibilityAddTraits(.isHeader)

                    SearchField(text: $searchText)

                    FavoriteSubtitleList(
                        results: favoriteResults,
                        textScale: textScale,
                        nativeAdUnitID: nativeAdUnitID
                    ) { result in
                        openSession(result.session, result.segment.startTime)
                    } toggleFavorite: { result in
                        toggleFavorite(result.session.id, result.segment.id)
                    }
                }
                .padding()
            }
            .background(AppTheme.appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FavoriteSubtitleList: View {
    let results: [FavoriteSubtitleResult]
    let textScale: Double
    let nativeAdUnitID: String
    let open: (FavoriteSubtitleResult) -> Void
    let toggleFavorite: (FavoriteSubtitleResult) -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            if results.isEmpty {
                ContentUnavailableView(
                    "お気に入りはまだありません",
                    systemImage: "star",
                    description: Text("字幕左の星をタップすると、ここに保存されます。")
                )
                .padding(.top, 40)
            } else {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    FavoriteSubtitleRow(result: result, textScale: textScale) {
                        open(result)
                    } toggleFavorite: {
                        toggleFavorite(result)
                    }

                    if AdMobRuntime.adsDisabled == false, (index + 1).isMultiple(of: 4) {
                        FavoriteNativeAdRow(adUnitID: nativeAdUnitID)
                    }
                }
            }
        }
    }
}

private struct FavoriteNativeAdRow: View {
    let adUnitID: String

    var body: some View {
        HorizontalNativeAdCardView(adUnitID: adUnitID)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FavoriteSubtitleRow: View {
    let result: FavoriteSubtitleResult
    let textScale: Double
    let open: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 18, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("お気に入りを解除")

            Button {
                open()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    PinyinFlow(tokens: result.segment.pinyinTokens, textScale: textScale)
                    if result.segment.japaneseTranslation.isEmpty == false {
                        Text(TranscriptTextCleaner.clean(result.segment.japaneseTranslation))
                            .font(.system(size: 16 * textScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.textCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button {
                UIPasteboard.general.string = TranscriptTextCleaner.cleanChinese(result.segment.sourceText)
            } label: {
                Label("中国語文章のみコピー", systemImage: "doc.on.doc")
            }

            Button {
                UIPasteboard.general.string = copyAllText
            } label: {
                Label("中国語文章・拼音・翻訳をコピー", systemImage: "doc.on.clipboard")
            }
        }
    }

    private var copyAllText: String {
        let source = TranscriptTextCleaner.cleanChinese(result.segment.sourceText)
        let pinyin = result.segment.pinyinTokens
            .map(\.pinyin)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        let japanese = TranscriptTextCleaner.clean(result.segment.japaneseTranslation)

        return [
            source,
            pinyin.isEmpty ? nil : pinyin,
            japanese.isEmpty ? nil : japanese
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

private struct HistoryTile: View {
    let session: TranscriptSession
    let open: () -> Void

    var body: some View {
        Button {
            open()
        } label: {
            GeometryReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    HistoryPreview(session: session)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()

                    if shouldShowDuration {
                        DurationBadge(text: session.durationText)
                    }

                    if session.isImageOnly {
                        ImageKindBadge()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .background(AppTheme.textCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var shouldShowDuration: Bool {
        session.isTextOnly == false && session.isImageOnly == false && session.durationText != "0:00"
    }
}

private struct ImageKindBadge: View {
    var body: some View {
        Image(systemName: "photo")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(.black.opacity(0.62), in: Circle())
            .padding(5)
    }
}

private struct HistoryPreview: View {
    let session: TranscriptSession

    var body: some View {
        if session.isTextOnly {
            VStack(alignment: .leading, spacing: 4) {
                Text(textPreview)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(AppTheme.textCardSurface)
        } else if session.isAudioOnly {
            ZStack {
                Rectangle()
                    .fill(AppTheme.textCardSurface)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        } else if session.isImageOnly {
            StillImageView(url: session.videoURL)
        } else {
            VideoThumbnailView(url: session.videoURL)
        }
    }

    private var textPreview: String {
        let preview = session.segments
            .prefix(2)
            .map { TranscriptTextCleaner.cleanChinese($0.sourceText) }
            .joined(separator: " ")
        return preview.isEmpty ? "テキスト" : preview
    }
}

private struct StillImageView: View {
    let url: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct SearchResultRow: View {
    let result: HistorySearchResult
    let query: String
    let open: () -> Void

    var body: some View {
        Button {
            open()
        } label: {
            HStack(spacing: 12) {
                HistoryPreview(session: result.session)
                    .frame(width: 88, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(highlightedText(result.matchText, query: query))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(AppTheme.textCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]),
              let lower = AttributedString.Index(range.lowerBound, within: attributed),
              let upper = AttributedString.Index(range.upperBound, within: attributed) else {
            return attributed
        }
        attributed[lower..<upper].font = .body.bold()
        return attributed
    }
}

private struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Rectangle()
                        .fill(Color(.tertiarySystemFill))
                    Image(systemName: "movie")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: url) {
            image = await makeThumbnail(url: url)
        }
    }

    private func makeThumbnail(url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

private struct DurationBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(.black.opacity(0.72), in: Capsule())
            .padding(5)
    }
}
