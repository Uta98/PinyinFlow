import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppTheme {
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.39, blue: 0.35, alpha: 1)
            : UIColor(red: 0.70, green: 0.08, blue: 0.10, alpha: 1)
    })
    static let accentSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.39, blue: 0.35, alpha: 0.18)
            : UIColor(red: 0.70, green: 0.08, blue: 0.10, alpha: 0.10)
    })
    static let accentStroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.39, blue: 0.35, alpha: 0.46)
            : UIColor(red: 0.70, green: 0.08, blue: 0.10, alpha: 0.34)
    })
    static let textCardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.08, blue: 0.08, alpha: 1)
            : UIColor(red: 0.99, green: 0.92, blue: 0.90, alpha: 1)
    })
}

struct AppView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @AppStorage("deepl.apiKey") private var apiKey = ""
    @AppStorage("googleTranslate.apiKey") private var googleTranslateAPIKey = ""
    @AppStorage("azureTranslate.apiKey") private var azureTranslateAPIKey = ""
    @AppStorage("azureTranslate.region") private var azureTranslateRegion = ""
    @AppStorage("openai.apiKey") private var openAIAPIKey = ""
    @AppStorage("assemblyAI.apiKey") private var assemblyAIAPIKey = ""
    @AppStorage("whisperkit.model") private var whisperModel = "base"
    @AppStorage("translation.engine") private var translationEngine = "deepl"
    @AppStorage("translation.targetLanguage") private var translationTarget = TranslationTargetLanguage.japanese.rawValue
    @AppStorage("transcription.engine") private var transcriptionEngine = "whisperkit"
    @AppStorage("transcript.textScale") private var textScale = 1.0
    @AppStorage("player.playbackRate") private var playbackRate = 1.0
    @AppStorage("onboarding.privacyAccepted") private var privacyAccepted = false
    @State private var isShowingSettings = false
    @State private var isShowingTextSheet = false
    @State private var isShowingPhotoPicker = false
    @State private var isImportingVideo = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var inputText = ""
    @State private var homeSearchText = ""

    var body: some View {
        Group {
            if viewModel.shouldShowWorkspace == false {
                NavigationStack {
                    ImportHomeView(
                        history: viewModel.history,
                        textScale: textScale,
                        searchText: $homeSearchText,
                        openSession: { session, startTime in
                            viewModel.loadSession(session, startTime: startTime)
                        },
                        deleteSession: viewModel.deleteSession,
                        toggleFavorite: viewModel.toggleFavorite(sessionID:segmentID:)
                    )
                    .navigationTitle("PinyinFlow")
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    isImportingVideo = true
                                } label: {
                                    Label("ファイル", systemImage: "folder")
                                }

                                Button {
                                    isShowingPhotoPicker = true
                                } label: {
                                    Label("写真", systemImage: "photo.on.rectangle")
                                }

                                Button {
                                    isShowingTextSheet = true
                                } label: {
                                    Label("テキスト", systemImage: "text.quote")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("取り込み")

                            Button {
                                isShowingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("設定")
                        }
                    }
                }
            } else {
                TranscriptWorkspaceView(
                    viewModel: viewModel,
                    textScale: textScale,
                    playbackRate: $playbackRate
                )
            }
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
            matching: .videos
        )
        .sheet(isPresented: $isShowingSettings) {
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
                textScale: $textScale
            )
        }
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
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .audio],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.importAndProcess(result)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                viewModel.prepareImportingPlaceholder(name: "写真の動画")
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.importPhotoVideo(data: data)
                } else {
                    viewModel.showHome()
                }
                selectedPhotoItem = nil
            }
        }
        .onAppear {
            configurePlaybackAudioSession()
            configureViewModelServices()
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
        viewModel.configureServices(
            apiKey: apiKey ?? self.apiKey,
            googleTranslateAPIKey: googleTranslateAPIKey ?? self.googleTranslateAPIKey,
            azureTranslateAPIKey: azureTranslateAPIKey ?? self.azureTranslateAPIKey,
            azureTranslateRegion: azureTranslateRegion ?? self.azureTranslateRegion,
            openAIAPIKey: openAIAPIKey ?? self.openAIAPIKey,
            assemblyAIAPIKey: assemblyAIAPIKey ?? self.assemblyAIAPIKey,
            whisperModel: whisperModel ?? self.whisperModel,
            translationEngine: translationEngine ?? self.translationEngine,
            transcriptionEngine: transcriptionEngine ?? self.transcriptionEngine,
            translationTarget: translationTarget ?? self.translationTarget
        )
    }
}

private struct FirstLaunchPrivacyView: View {
    let accept: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("動画・音声・テキスト、字幕、拼音、翻訳、お気に入りは端末内に保存されます。", systemImage: "iphone")
                    Label("クラウド翻訳やクラウド文字起こしを選ぶと、対象データが選択した外部サービスへ送信されます。", systemImage: "cloud")
                    Label("無料で使えるようにするため、処理中や履歴画面に広告を表示することがあります。", systemImage: "rectangle.and.text.magnifyingglass")
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
    let toggleFavorite: (TranscriptSession.ID, TranscriptSegment.ID) -> Void
    @State private var sessionPendingDeletion: TranscriptSession?
    @State private var selectedMenu: MainMenu = .history

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private enum MainMenu: String, CaseIterable, Identifiable {
        case history = "履歴"
        case favorites = "お気に入り"

        var id: String { rawValue }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [HistorySearchResult] {
        guard query.isEmpty == false else { return [] }
        return history.compactMap { session in
            if let segment = session.segments.first(where: { segment in
                TranscriptTextCleaner.clean(segment.sourceText).localizedCaseInsensitiveContains(query)
                    || TranscriptTextCleaner.clean(segment.japaneseTranslation).localizedCaseInsensitiveContains(query)
                    || segment.pinyinTokens.contains { $0.pinyin.localizedCaseInsensitiveContains(query) }
            }) {
                let source = TranscriptTextCleaner.clean(segment.sourceText)
                let japanese = TranscriptTextCleaner.clean(segment.japaneseTranslation)
                let matchText = source.localizedCaseInsensitiveContains(query)
                    ? source
                    : (japanese.localizedCaseInsensitiveContains(query) ? japanese : source)
                return HistorySearchResult(session: session, segment: segment, matchText: matchText)
            }
            return nil
        }
    }

    private var favoriteResults: [FavoriteSubtitleResult] {
        history.flatMap { session in
            session.segments
                .filter(\.isFavorite)
                .map { FavoriteSubtitleResult(session: session, segment: $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SearchField(text: $searchText)

                Picker("メニュー", selection: $selectedMenu) {
                    ForEach(MainMenu.allCases) { menu in
                        Text(menu.rawValue).tag(menu)
                    }
                }
                .pickerStyle(.segmented)

                if selectedMenu == .favorites {
                    FavoriteSubtitleList(results: favoriteResults, textScale: textScale) { result in
                        openSession(result.session, result.segment.startTime)
                    } toggleFavorite: { result in
                        toggleFavorite(result.session.id, result.segment.id)
                    }
                } else if history.isEmpty {
                    ContentUnavailableView(
                        "履歴はまだありません",
                        systemImage: "clock",
                        description: Text("取り込んだ動画と字幕はここに保存されます。")
                    )
                    .padding(.top, 40)
                } else if query.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(history) { session in
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

                if selectedMenu == .history {
                    HistoryBannerAdView()
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct HistoryBannerAdView: View {
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    #else
    private let adUnitID = "ca-app-pub-2083362073572230/5681513186"
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("広告")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
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

private struct FavoriteSubtitleList: View {
    let results: [FavoriteSubtitleResult]
    let textScale: Double
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
                ForEach(results) { result in
                    FavoriteSubtitleRow(result: result, textScale: textScale) {
                        open(result)
                    } toggleFavorite: {
                        toggleFavorite(result)
                    }
                }
            }
        }
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
        .background(Color(.secondarySystemGroupedBackground))
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
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var shouldShowDuration: Bool {
        session.isTextOnly == false && session.durationText != "0:00"
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
            .background(Color(.secondarySystemGroupedBackground))
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
