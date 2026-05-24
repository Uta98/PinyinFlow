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
    @AppStorage("whisperkit.model") private var whisperModel = "base"
    @AppStorage("translation.engine") private var translationEngine = "deepl"
    @AppStorage("translation.targetLanguage") private var translationTarget = TranslationTargetLanguage.japanese.rawValue
    @AppStorage("transcription.engine") private var transcriptionEngine = "whisperkit"
    @AppStorage("transcript.textScale") private var textScale = 1.0
    @AppStorage("player.playbackRate") private var playbackRate = 1.0
    @State private var isShowingSettings = false
    @State private var isImportingVideo = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Group {
            if viewModel.shouldShowWorkspace == false {
                NavigationStack {
                    ImportHomeView(
                        history: viewModel.history,
                        importFromFiles: { isImportingVideo = true },
                        selectedPhotoItem: $selectedPhotoItem,
                        importFromLink: { link in
                            Task {
                                viewModel.prepareImportingPlaceholder(name: "XiaoHongShu")
                                await viewModel.importVideo(fromLink: link)
                            }
                        },
                        importText: { text in
                            Task {
                                await viewModel.importText(text)
                            }
                        },
                        openSession: { session, startTime in
                            viewModel.loadSession(session, startTime: startTime)
                        },
                        deleteSession: viewModel.deleteSession,
                        toggleFavorite: viewModel.toggleFavorite(sessionID:segmentID:)
                    )
                    .navigationTitle("PinyinFlow")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                apiKey: $apiKey,
                whisperModel: $whisperModel,
                translationEngine: $translationEngine,
                transcriptionEngine: $transcriptionEngine,
                translationTarget: $translationTarget,
                textScale: $textScale
            )
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
        whisperModel: String? = nil,
        translationEngine: String? = nil,
        transcriptionEngine: String? = nil,
        translationTarget: String? = nil
    ) {
        viewModel.configureServices(
            apiKey: apiKey ?? self.apiKey,
            whisperModel: whisperModel ?? self.whisperModel,
            translationEngine: translationEngine ?? self.translationEngine,
            transcriptionEngine: transcriptionEngine ?? self.transcriptionEngine,
            translationTarget: translationTarget ?? self.translationTarget
        )
    }
}

private struct ImportHomeView: View {
    let history: [TranscriptSession]
    let importFromFiles: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let importFromLink: (String) -> Void
    let importText: (String) -> Void
    let openSession: (TranscriptSession, TimeInterval?) -> Void
    let deleteSession: (TranscriptSession) -> Void
    let toggleFavorite: (TranscriptSession.ID, TranscriptSegment.ID) -> Void
    @State private var searchText = ""
    @State private var linkText = ""
    @State private var inputText = ""
    @State private var isShowingLinkSheet = false
    @State private var isShowingTextSheet = false
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
                ImportActions(
                    importFromFiles: importFromFiles,
                    selectedPhotoItem: $selectedPhotoItem,
                    showLinkInput: { isShowingLinkSheet = true },
                    showTextInput: { isShowingTextSheet = true }
                )

                Picker("メニュー", selection: $selectedMenu) {
                    ForEach(MainMenu.allCases) { menu in
                        Text(menu.rawValue).tag(menu)
                    }
                }
                .pickerStyle(.segmented)

                if selectedMenu == .favorites {
                    FavoriteSubtitleList(results: favoriteResults) { result in
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
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "中国語・拼音・翻訳を検索")
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isShowingLinkSheet) {
            LinkImportSheet(linkText: $linkText) { link in
                importFromLink(link)
                linkText = ""
            }
        }
        .sheet(isPresented: $isShowingTextSheet) {
            TextImportSheet(inputText: $inputText) { text in
                importText(text)
                inputText = ""
            }
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
}

private struct ImportActions: View {
    let importFromFiles: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let showLinkInput: () -> Void
    let showTextInput: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ImportActionButton(title: "ファイル", systemImage: "folder") {
                importFromFiles()
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                ImportActionLabel(title: "写真", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.plain)

            ImportActionButton(title: "リンク", systemImage: "link") {
                showLinkInput()
            }

            ImportActionButton(title: "テキスト", systemImage: "text.quote") {
                showTextInput()
            }
        }
    }
}

private struct ImportActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ImportActionLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

private struct ImportActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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

private struct LinkImportSheet: View {
    @Binding var linkText: String
    let importLink: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var canImport: Bool {
        linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("XiaoHongShuリンク") {
                    TextField("共有リンクまたは動画URL", text: $linkText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3...6)

                    Button {
                        linkText = UIPasteboard.general.string ?? linkText
                    } label: {
                        Label("貼り付け", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .navigationTitle("リンクから取り込み")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("取り込む") {
                        importLink(linkText)
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
                    FavoriteSubtitleRow(result: result) {
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
                    PinyinFlow(tokens: result.segment.pinyinTokens, textScale: 0.78)
                    if result.segment.japaneseTranslation.isEmpty == false {
                        Text(TranscriptTextCleaner.clean(result.segment.japaneseTranslation))
                            .font(.subheadline)
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
            HistoryPreview(session: session)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(AppTheme.textCardSurface)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                if session.durationText != "0:00" {
                    Text(session.durationText)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(5)
                }
            }
        } else {
            VideoThumbnailView(url: session.videoURL, durationText: session.durationText)
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
    let durationText: String
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                Image(systemName: "movie")
                    .foregroundStyle(.secondary)
            }

            if durationText != "0:00" {
                Text(durationText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(5)
            }
        }
        .task(id: url) {
            image = await makeThumbnail(url: url)
        }
        .clipped()
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
