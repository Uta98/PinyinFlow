import AppKit

struct ScreenshotSpec {
    let index: Int
    let title: String
    let subtitle: String
    let scene: Scene
}

enum Scene {
    case videoNote
    case syncedSubtitles
    case pinyinTranslation
    case favorites
    case inputPrivacy
}

let outputDirectory = URL(fileURLWithPath: "marketing/screenshots", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let canvasSize = CGSize(width: 1290, height: 2796)
let specs = [
    ScreenshotSpec(
        index: 1,
        title: "中国語動画を、学習ノートに",
        subtitle: "文字起こし・拼音・翻訳を自動で表示",
        scene: .videoNote
    ),
    ScreenshotSpec(
        index: 2,
        title: "動画を見ながら、字幕で学ぶ",
        subtitle: "再生位置に合わせて中国語テキストを追従",
        scene: .syncedSubtitles
    ),
    ScreenshotSpec(
        index: 3,
        title: "拼音も翻訳も、ひとつの画面で",
        subtitle: "聞く・読む・意味を確認するをスムーズに",
        scene: .pinyinTranslation
    ),
    ScreenshotSpec(
        index: 4,
        title: "気になるフレーズを保存",
        subtitle: "お気に入りで中国語表現をあとから復習",
        scene: .favorites
    ),
    ScreenshotSpec(
        index: 5,
        title: "動画・音声・テキストに対応",
        subtitle: "オンデバイス文字起こしで安心して学習",
        scene: .inputPrivacy
    )
]

let background = NSColor(calibratedRed: 1.0, green: 0.948, blue: 0.948, alpha: 1)
let deepRed = NSColor(calibratedRed: 0.48, green: 0.015, blue: 0.04, alpha: 1)
let accent = NSColor(calibratedRed: 0.74, green: 0.05, blue: 0.08, alpha: 1)
let softRed = NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.82, alpha: 1)
let card = NSColor.white
let text = NSColor(calibratedRed: 0.13, green: 0.05, blue: 0.06, alpha: 1)
let muted = NSColor(calibratedRed: 0.47, green: 0.32, blue: 0.34, alpha: 1)
let blue = NSColor(calibratedRed: 0.0, green: 0.48, blue: 0.94, alpha: 1)

func flip(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: canvasSize.height - rect.minY - rect.height, width: rect.width, height: rect.height)
}

func font(_ size: CGFloat, weight: NSFont.Weight, rounded: Bool = false) -> NSFont {
    let descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
    if rounded, let roundedDescriptor = descriptor.withDesign(.rounded) {
        return NSFont(descriptor: roundedDescriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
    return NSFont.systemFont(ofSize: size, weight: weight)
}

func paragraph(alignment: NSTextAlignment = .left, lineHeight: CGFloat? = nil) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byWordWrapping
    if let lineHeight {
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
    }
    return style
}

func drawText(_ string: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .left, rounded: Bool = false, lineHeight: CGFloat? = nil) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight, rounded: rounded),
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment: alignment, lineHeight: lineHeight)
    ]
    string.draw(in: flip(rect), withAttributes: attrs)
}

func rounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: flip(rect), xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: flip(rect), xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

func drawCircle(_ rect: CGRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: flip(rect)).fill()
}

func drawPill(_ rect: CGRect, color: NSColor) {
    rounded(rect, radius: rect.height / 2, color: color)
}

func drawShadowedPhone(in rect: CGRect, content: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = CGSize(width: 0, height: -18)
    shadow.set()
    rounded(rect, radius: 74, color: NSColor.black)
    NSGraphicsContext.restoreGraphicsState()
    rounded(rect.insetBy(dx: 8, dy: 8), radius: 66, color: NSColor(calibratedWhite: 0.03, alpha: 1))

    let screen = rect.insetBy(dx: 26, dy: 26)
    rounded(screen, radius: 52, color: NSColor(calibratedRed: 1.0, green: 0.955, blue: 0.955, alpha: 1))
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: flip(screen), xRadius: 52, yRadius: 52).addClip()
    content()
    NSGraphicsContext.restoreGraphicsState()
}

func drawHeader(spec: ScreenshotSpec) {
    drawText(
        spec.title,
        in: CGRect(x: 92, y: 220, width: canvasSize.width - 184, height: 170),
        size: 74,
        weight: .heavy,
        color: deepRed,
        rounded: true,
        lineHeight: 86
    )
    drawText(
        spec.subtitle,
        in: CGRect(x: 96, y: 392, width: canvasSize.width - 192, height: 100),
        size: 34,
        weight: .semibold,
        color: muted,
        lineHeight: 46
    )
}

func drawBrandFooter() {
    drawText("PinyinFlow", in: CGRect(x: 92, y: 2564, width: 520, height: 70), size: 42, weight: .heavy, color: deepRed, rounded: true)
    drawPill(CGRect(x: 900, y: 2570, width: 296, height: 54), color: softRed)
    drawText("中国語学習をもっと自然に", in: CGRect(x: 922, y: 2583, width: 254, height: 30), size: 22, weight: .bold, color: deepRed, alignment: .center)
}

func drawVideoThumbnail(_ rect: CGRect, label: String = "视频") {
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.58, green: 0.05, blue: 0.07, alpha: 1),
        NSColor(calibratedRed: 0.95, green: 0.46, blue: 0.38, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.52, alpha: 1)
    ])!
    let path = NSBezierPath(roundedRect: flip(rect), xRadius: 34, yRadius: 34)
    gradient.draw(in: path, angle: 45)

    rounded(CGRect(x: rect.minX + 42, y: rect.minY + 80, width: rect.width - 84, height: 120), radius: 28, color: NSColor.white.withAlphaComponent(0.20))
    rounded(CGRect(x: rect.minX + 80, y: rect.minY + 250, width: rect.width - 160, height: 320), radius: 36, color: NSColor.white.withAlphaComponent(0.28))
    drawText(label, in: CGRect(x: rect.minX + 44, y: rect.maxY - 118, width: rect.width - 88, height: 56), size: 44, weight: .heavy, color: .white, alignment: .center, rounded: true)
    drawPill(CGRect(x: rect.maxX - 170, y: rect.maxY - 86, width: 116, height: 46), color: NSColor.black.withAlphaComponent(0.45))
    drawText("1:07", in: CGRect(x: rect.maxX - 146, y: rect.maxY - 76, width: 68, height: 26), size: 24, weight: .bold, color: .white, alignment: .center)
}

func drawSubtitleCard(_ rect: CGRect, chinese: String, pinyin: String, translation: String, active: Bool = false) {
    rounded(rect, radius: 28, color: active ? softRed : card)
    drawText(pinyin, in: CGRect(x: rect.minX + 34, y: rect.minY + 26, width: rect.width - 68, height: 36), size: 25, weight: .semibold, color: blue)
    drawText(chinese, in: CGRect(x: rect.minX + 34, y: rect.minY + 68, width: rect.width - 68, height: 58), size: 39, weight: .heavy, color: text)
    drawText(translation, in: CGRect(x: rect.minX + 34, y: rect.minY + 132, width: rect.width - 68, height: 54), size: 28, weight: .medium, color: muted)
}

func drawWorkspace(phone: CGRect, mode: Scene) {
    drawShadowedPhone(in: phone) {
        let screen = phone.insetBy(dx: 26, dy: 26)
        rounded(screen, radius: 52, color: background)
        let video = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: 640)
        rounded(video, radius: 52, color: NSColor.black)
        drawVideoThumbnail(video.insetBy(dx: 150, dy: 100), label: "中文")
        drawCircle(CGRect(x: video.midX - 58, y: video.midY - 58, width: 116, height: 116), color: NSColor.white.withAlphaComponent(0.86))
        drawText("▶", in: CGRect(x: video.midX - 22, y: video.midY - 34, width: 56, height: 70), size: 48, weight: .bold, color: deepRed, alignment: .center)

        let timeline = CGRect(x: screen.minX + 42, y: video.maxY + 48, width: screen.width - 84, height: screen.height - video.height - 120)
        switch mode {
        case .videoNote, .syncedSubtitles:
            drawSubtitleCard(CGRect(x: timeline.minX, y: timeline.minY, width: timeline.width, height: 210), chinese: "这句话很有用", pinyin: "zhè jù huà hěn yǒu yòng", translation: "この一文はとても役に立ちます。", active: mode == .syncedSubtitles)
            drawSubtitleCard(CGRect(x: timeline.minX, y: timeline.minY + 236, width: timeline.width, height: 210), chinese: "我们再听一遍", pinyin: "wǒ men zài tīng yí biàn", translation: "もう一度聞いてみましょう。")
            drawSubtitleCard(CGRect(x: timeline.minX, y: timeline.minY + 472, width: timeline.width, height: 210), chinese: "慢慢就会听懂", pinyin: "màn màn jiù huì tīng dǒng", translation: "少しずつ聞き取れるようになります。")
        case .pinyinTranslation:
            drawSubtitleCard(CGRect(x: timeline.minX, y: timeline.minY, width: timeline.width, height: 232), chinese: "今天我们学习中文", pinyin: "jīn tiān wǒ men xué xí zhōng wén", translation: "今日は中国語を学びます。", active: true)
            drawSubtitleCard(CGRect(x: timeline.minX, y: timeline.minY + 260, width: timeline.width, height: 232), chinese: "发音和意思一起看", pinyin: "fā yīn hé yì si yì qǐ kàn", translation: "発音と意味を一緒に確認します。")
        default:
            break
        }
    }
}

func drawHome(phone: CGRect, favorites: Bool = false) {
    drawShadowedPhone(in: phone) {
        let screen = phone.insetBy(dx: 26, dy: 26)
        rounded(screen, radius: 52, color: background)
        drawText(favorites ? "お気に入り" : "PinyinFlow", in: CGRect(x: screen.minX + 54, y: screen.minY + 92, width: screen.width - 108, height: 72), size: 52, weight: .heavy, color: deepRed, rounded: true)
        drawPill(CGRect(x: screen.minX + 54, y: screen.minY + 202, width: screen.width - 108, height: 74), color: card)
        drawText("中国語・拼音・翻訳を検索", in: CGRect(x: screen.minX + 112, y: screen.minY + 222, width: screen.width - 220, height: 34), size: 25, weight: .semibold, color: muted)

        if favorites {
            let rows = [
                ("★", "没关系，我们慢慢来", "méi guān xi, wǒ men màn màn lái", "大丈夫、ゆっくり進めましょう。"),
                ("★", "这个表达很自然", "zhè ge biǎo dá hěn zì rán", "この表現はとても自然です。"),
                ("★", "下次可以这样说", "xià cì kě yǐ zhè yàng shuō", "次はこう言えます。")
            ]
            for (i, row) in rows.enumerated() {
                let y = screen.minY + 330 + CGFloat(i) * 234
                rounded(CGRect(x: screen.minX + 54, y: y, width: screen.width - 108, height: 198), radius: 28, color: card)
                drawText(row.0, in: CGRect(x: screen.minX + 86, y: y + 38, width: 40, height: 42), size: 30, weight: .bold, color: accent)
                drawText(row.2, in: CGRect(x: screen.minX + 140, y: y + 32, width: screen.width - 220, height: 34), size: 24, weight: .semibold, color: blue)
                drawText(row.1, in: CGRect(x: screen.minX + 140, y: y + 78, width: screen.width - 220, height: 46), size: 34, weight: .heavy, color: text)
                drawText(row.3, in: CGRect(x: screen.minX + 140, y: y + 134, width: screen.width - 220, height: 34), size: 25, weight: .medium, color: muted)
            }
        } else {
            for row in 0..<2 {
                for col in 0..<3 {
                    let x = screen.minX + 54 + CGFloat(col) * ((screen.width - 132) / 3)
                    let y = screen.minY + 326 + CGFloat(row) * 318
                    drawVideoThumbnail(CGRect(x: x, y: y, width: 196, height: 294), label: row == 0 && col == 2 ? "文" : "中")
                }
            }
        }
    }
}

func drawInputPrivacy(phone: CGRect) {
    drawShadowedPhone(in: phone) {
        let screen = phone.insetBy(dx: 26, dy: 26)
        rounded(screen, radius: 52, color: background)
        drawText("PinyinFlow", in: CGRect(x: screen.minX + 54, y: screen.minY + 92, width: screen.width - 108, height: 72), size: 52, weight: .heavy, color: deepRed, rounded: true)
        let items = [("書類", "ファイル"), ("写真", "写真"), ("音声", "音声"), ("文字", "テキスト")]
        for (i, item) in items.enumerated() {
            let y = screen.minY + 230 + CGFloat(i) * 132
            rounded(CGRect(x: screen.minX + 54, y: y, width: screen.width - 108, height: 104), radius: 26, color: card)
            drawCircle(CGRect(x: screen.minX + 82, y: y + 22, width: 60, height: 60), color: softRed)
            drawText(item.0, in: CGRect(x: screen.minX + 80, y: y + 40, width: 64, height: 24), size: 16, weight: .bold, color: deepRed, alignment: .center)
            drawText(item.1, in: CGRect(x: screen.minX + 386, y: y + 28, width: 240, height: 44), size: 32, weight: .heavy, color: text)
        }
        rounded(CGRect(x: screen.minX + 54, y: screen.minY + 810, width: screen.width - 108, height: 210), radius: 30, color: softRed)
        drawText("WhisperKit", in: CGRect(x: screen.minX + 92, y: screen.minY + 850, width: screen.width - 184, height: 44), size: 36, weight: .heavy, color: deepRed, rounded: true)
        drawText("音声を外部APIへ送らず、端末内で文字起こし", in: CGRect(x: screen.minX + 92, y: screen.minY + 906, width: screen.width - 184, height: 82), size: 27, weight: .semibold, color: text, lineHeight: 38)
    }
}

func render(_ spec: ScreenshotSpec) {
    let image = NSImage(size: canvasSize)
    image.lockFocus()
    background.setFill()
    CGRect(origin: .zero, size: canvasSize).fill()
    let blob = NSGradient(colors: [softRed.withAlphaComponent(0.9), background.withAlphaComponent(0.0)])!
    blob.draw(in: NSBezierPath(ovalIn: flip(CGRect(x: 700, y: 70, width: 720, height: 720))), angle: 0)
    blob.draw(in: NSBezierPath(ovalIn: flip(CGRect(x: -190, y: 1790, width: 620, height: 620))), angle: 0)
    drawHeader(spec: spec)
    let phone = CGRect(x: 206, y: 650, width: 878, height: 1772)
    switch spec.scene {
    case .videoNote, .syncedSubtitles, .pinyinTranslation:
        drawWorkspace(phone: phone, mode: spec.scene)
    case .favorites:
        drawHome(phone: phone, favorites: true)
    case .inputPrivacy:
        drawInputPrivacy(phone: phone)
    }
    drawBrandFooter()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render PNG")
    }
    let fileName = String(format: "PinyinFlow_AppStore_%02d.png", spec.index)
    try! data.write(to: outputDirectory.appendingPathComponent(fileName))
}

for spec in specs {
    render(spec)
}

print("Generated \(specs.count) screenshots in \(outputDirectory.path)")
