import AVKit
import SwiftUI

struct TranscriptWorkspaceView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let textScale: Double
    @Binding var playbackRate: Double
    @Binding var showPinyin: Bool
    @Binding var showChinese: Bool
    @Binding var showTranslation: Bool
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var currentTime: TimeInterval = 0
    @State private var pendingInitialSeek: TimeInterval?
    @State private var editingSegment: TranscriptSegment?

    private var playerRate: Float {
        Float(playbackRate)
    }

    var body: some View {
        VStack(spacing: 0) {
            VideoPane(
                player: player,
                mediaURL: viewModel.selectedVideoURL,
                isTextOnly: viewModel.isTextOnlySession,
                phase: viewModel.phase
            )
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .background(.black)
                .overlay(alignment: .topLeading) {
                    Button {
                        viewModel.showHome()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 52)
                    .padding(.leading, 16)
                    .accessibilityLabel("履歴に戻る")
                }
                .overlay(alignment: .topTrailing) {
                    SubtitleDisplayMenu(
                        showPinyin: $showPinyin,
                        showChinese: $showChinese,
                        showTranslation: $showTranslation
                    )
                    .padding(.top, 52)
                    .padding(.trailing, 16)
                }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.red.opacity(0.08))
            }

            TranscriptTimelineView(
                segments: viewModel.segments,
                currentTime: currentTime,
                textScale: textScale,
                phase: viewModel.phase,
                showPinyin: showPinyin,
                showChinese: showChinese,
                showTranslation: showTranslation,
                seek: seek(to:),
                toggleFavorite: { segment in
                    viewModel.toggleFavorite(segmentID: segment.id)
                }
            ) { segment in
                editingSegment = segment
            }
        }
        .sheet(item: $editingSegment) { segment in
            SubtitleEditView(
                segment: segment,
                translate: { text in
                    await viewModel.translateDraft(text)
                }
            ) { sourceText, japaneseTranslation in
                viewModel.updateSegment(
                    id: segment.id,
                    sourceText: sourceText,
                    japaneseTranslation: japaneseTranslation
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .tint(AppTheme.accent)
        .overlay(alignment: .bottom) {
            if viewModel.phase.isBusy {
                WaitingAdSlotView(style: .light)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            pendingInitialSeek = viewModel.initialPlaybackTime
            configurePlayer(for: viewModel.selectedVideoURL)
        }
        .onChange(of: viewModel.selectedVideoURL) { _, url in
            configurePlayer(for: url)
        }
        .onChange(of: viewModel.phase) { _, _ in
            configurePlayer(for: viewModel.selectedVideoURL)
        }
        .onChange(of: playbackRate) { _, newValue in
            player?.defaultRate = Float(newValue)
            if player?.timeControlStatus == .playing {
                player?.rate = Float(newValue)
            }
        }
        .onDisappear {
            removeTimeObserver()
        }
    }

    private func configurePlayer(for url: URL?) {
        removeTimeObserver()
        currentTime = 0

        guard viewModel.phase.isBusy == false else {
            player = nil
            return
        }

        guard let url else {
            player = nil
            return
        }

        let nextPlayer = AVPlayer(url: url)
        nextPlayer.defaultRate = playerRate
        player = nextPlayer
        timeObserver = nextPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
            queue: .main
        ) { time in
            currentTime = time.seconds
        }
        if let pendingInitialSeek {
            nextPlayer.seek(
                to: CMTime(seconds: pendingInitialSeek, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            self.pendingInitialSeek = nil
        }
        nextPlayer.playImmediately(atRate: playerRate)
    }

    private func seek(to segment: TranscriptSegment) {
        player?.seek(
            to: CMTime(seconds: segment.startTime, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        player?.playImmediately(atRate: player?.defaultRate ?? playerRate)
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
}

private struct SubtitleDisplayMenu: View {
    @Binding var showPinyin: Bool
    @Binding var showChinese: Bool
    @Binding var showTranslation: Bool
    @State private var isShowingPanel = false

    var body: some View {
        Button {
            isShowingPanel = true
        } label: {
            Image(systemName: "textformat")
                .font(.headline)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("字幕表示")
        .popover(isPresented: $isShowingPanel, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 14) {
                Text("字幕表示")
                    .font(.headline)

                Toggle("拼音", isOn: $showPinyin)
                Toggle("中国語", isOn: $showChinese)
                Toggle("日本語訳", isOn: $showTranslation)

                Button {
                    isShowingPanel = false
                } label: {
                    Text("完了")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.settingsAccent)
                .padding(.top, 4)
            }
            .padding(16)
            .frame(width: 220)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct VideoPane: View {
    let player: AVPlayer?
    let mediaURL: URL?
    let isTextOnly: Bool
    let phase: ProcessingPhase

    var body: some View {
        Group {
            if phase.isBusy {
                ProcessingMediaPane(phase: phase)
            } else if isTextOnly {
                MediaIconPane(systemName: "text.quote")
            } else if mediaURL?.isStandaloneAudioFile == true {
                MediaIconPane(systemName: "waveform.circle.fill")
            } else if let player {
                SystemVideoPlayer(player: player)
            } else {
                MediaIconPane(systemName: "movie.badge.waveform")
            }
        }
    }
}

private struct ProcessingMediaPane: View {
    let phase: ProcessingPhase

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.accent)

            VStack(spacing: 10) {
                Text("処理中")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    ProgressView(value: phase.progressValue)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.accent)
                        .frame(maxWidth: 320)
                    Text(phase.statusText)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProcessingProgressBar: View {
    let phase: ProcessingPhase
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phase.statusText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int((phase.progressValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(isDark ? .white.opacity(0.82) : .secondary)

            ProgressView(value: phase.progressValue)
                .progressViewStyle(.linear)
                .tint(AppTheme.accent)
        }
    }
}

private struct MediaIconPane: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 46, weight: .semibold))
            .foregroundStyle(.white.opacity(0.86))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = false
        controller.speeds = [
            AVPlaybackSpeed(rate: 0.5, localizedName: "0.5x"),
            AVPlaybackSpeed(rate: 0.75, localizedName: "0.75x"),
            AVPlaybackSpeed(rate: 1.0, localizedName: "1x"),
            AVPlaybackSpeed(rate: 1.25, localizedName: "1.25x"),
            AVPlaybackSpeed(rate: 1.5, localizedName: "1.5x"),
            AVPlaybackSpeed(rate: 2.0, localizedName: "2x")
        ]
        controller.player = player
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}

private struct TranscriptTimelineView: View {
    let segments: [TranscriptSegment]
    let currentTime: TimeInterval
    let textScale: Double
    let phase: ProcessingPhase
    let showPinyin: Bool
    let showChinese: Bool
    let showTranslation: Bool
    let seek: (TranscriptSegment) -> Void
    let toggleFavorite: (TranscriptSegment) -> Void
    let edit: (TranscriptSegment) -> Void

    private var activeSegmentID: TranscriptSegment.ID? {
        segments.first { $0.contains(time: currentTime) }?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if segments.isEmpty {
                        ProcessingSkeletonView(phase: phase)
                        .padding(.top, 48)
                    } else {
                        ForEach(segments) { segment in
                            TranscriptSegmentRow(
                                segment: segment,
                                isActive: segment.id == activeSegmentID,
                                textScale: textScale,
                                showPinyin: showPinyin,
                                showChinese: showChinese,
                                showTranslation: showTranslation,
                                seek: { seek(segment) },
                                toggleFavorite: { toggleFavorite(segment) },
                                edit: { edit(segment) }
                            )
                            .id(segment.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: activeSegmentID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}

private struct ProcessingSkeletonView: View {
    let phase: ProcessingPhase
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<5, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(width: index.isMultiple(of: 2) ? 210 : 150, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(width: index.isMultiple(of: 2) ? 260 : 220, height: 12)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(pulse ? 0.45 : 1)
        .onAppear {
            guard phase.isBusy else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct WaitingAdSlotView: View {
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/2435281174"
    #else
    private let adUnitID = "ca-app-pub-2083362073572230/5681513186"
    #endif

    enum Style {
        case light
        case dark
    }

    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("広告")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(style == .dark ? .white.opacity(0.62) : .secondary)
            RoundedRectangle(cornerRadius: 8)
                .fill(style == .dark ? Color.white.opacity(0.08) : AppTheme.accentSoft)
                .overlay {
                    AdBannerView(adUnitID: adUnitID)
                        .frame(width: 300, height: 250)
                }
                .frame(height: style == .dark ? 250 : 250)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style == .dark ? Color.white.opacity(0.14) : AppTheme.accentStroke, lineWidth: 1)
                }
        }
        .padding(.top, 4)
    }
}

private struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment
    let isActive: Bool
    let textScale: Double
    let showPinyin: Bool
    let showChinese: Bool
    let showTranslation: Bool
    let seek: () -> Void
    let toggleFavorite: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: segment.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(segment.isFavorite ? .yellow : .secondary)
                    .frame(width: 18, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(segment.isFavorite ? "お気に入りを解除" : "お気に入りに追加")

            Button {
                seek()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    if showPinyin || showChinese {
                        HStack {
                            PinyinFlow(
                                tokens: segment.pinyinTokens,
                                textScale: textScale,
                                showsPinyin: showPinyin,
                                showsChinese: showChinese
                            )
                            Spacer(minLength: 0)
                        }
                    }

                    if showTranslation && segment.japaneseTranslation.isEmpty == false {
                        Text(TranscriptTextCleaner.clean(segment.japaneseTranslation))
                            .font(.system(size: 16 * textScale))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(isActive ? AppTheme.accentSoft : Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? AppTheme.accentStroke : Color.clear, lineWidth: 1)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    edit()
                }
        )
    }
}

struct PinyinFlow: View {
    let tokens: [PinyinToken]
    let textScale: Double
    var showsPinyin = true
    var showsChinese = true

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(tokens) { token in
                VStack(spacing: 2) {
                    if showsPinyin {
                        Text(token.pinyin.isEmpty ? " " : token.pinyin)
                            .font(.system(size: 12 * textScale))
                            .foregroundStyle(AppTheme.accent)
                    }
                    if showsChinese {
                        Text(token.character)
                            .font(.system(size: 20 * textScale, weight: .bold))
                    }
                }
                .frame(minWidth: 24)
            }
        }
    }
}

private struct SubtitleEditView: View {
    let segment: TranscriptSegment
    let translate: (String) async -> String
    let save: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sourceText: String
    @State private var japaneseTranslation: String
    @State private var isAutoTranslating = false

    init(
        segment: TranscriptSegment,
        translate: @escaping (String) async -> String,
        save: @escaping (String, String) -> Void
    ) {
        self.segment = segment
        self.translate = translate
        self.save = save
        _sourceText = State(initialValue: segment.sourceText)
        _japaneseTranslation = State(initialValue: TranscriptTextCleaner.clean(segment.japaneseTranslation))
    }

    private var livePinyinTokens: [PinyinToken] {
        MandarinPinyinAnnotator().tokens(for: TranscriptTextCleaner.cleanChinese(sourceText))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("中国語") {
                    PinyinFlow(tokens: livePinyinTokens, textScale: 0.9)
                        .padding(.vertical, 6)
                    TextEditor(text: $sourceText)
                        .frame(minHeight: 96)
                }

                Section("翻訳") {
                    TextEditor(text: $japaneseTranslation)
                        .frame(minHeight: 96)
                    if isAutoTranslating {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("字幕を編集")
            .task(id: sourceText) {
                let source = TranscriptTextCleaner.cleanChinese(sourceText)
                guard source.isEmpty == false else { return }
                try? await Task.sleep(for: .milliseconds(700))
                guard Task.isCancelled == false else { return }
                isAutoTranslating = true
                let translated = await translate(source)
                if Task.isCancelled == false, translated.isEmpty == false {
                    japaneseTranslation = translated
                }
                isAutoTranslating = false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save(sourceText, japaneseTranslation)
                        dismiss()
                    }
                }
            }
        }
    }
}
