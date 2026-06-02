import AppKit
import Foundation

struct Shot {
    let filename: String
    let headline: String
    let subhead: String
    let kind: Kind

    enum Kind {
        case home
        case player
        case favorites
    }
}

let outputURL = URL(fileURLWithPath: "ChineseVideoTutor/AppStoreScreenshots", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let shots = [
    Shot(
        filename: "01-home-history.png",
        headline: "中国語動画を、学習ノートに。",
        subhead: "動画・音声・テキストを取り込むだけで、拼音と翻訳つきの履歴を保存。",
        kind: .home
    ),
    Shot(
        filename: "02-synced-subtitles.png",
        headline: "動画と字幕が、ぴったり同期。",
        subhead: "再生位置に合わせて中国語・拼音・翻訳を確認。字幕タップでその場面へ移動。",
        kind: .player
    ),
    Shot(
        filename: "03-favorites-search.png",
        headline: "覚えたい表現を、すぐ復習。",
        subhead: "お気に入りと検索で、気になった一文をあとから見返せます。",
        kind: .favorites
    )
]

let size = NSSize(width: 1290, height: 2796)

for shot in shots {
    let image = NSImage(size: size)
    image.lockFocus()
    drawBackground(size: size)
    drawChrome(size: size)
    drawHeader(shot: shot, size: size)
    switch shot.kind {
    case .home:
        drawHome(size: size)
    case .player:
        drawPlayer(size: size)
    case .favorites:
        drawFavorites(size: size)
    }
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(shot.filename)")
    }
    try png.write(to: outputURL.appendingPathComponent(shot.filename))
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: size.height - y - h, width: w, height: h)
}

func drawBackground(size: NSSize) {
    color(255, 242, 242).setFill()
    NSRect(origin: .zero, size: size).fill()
}

func drawChrome(size: NSSize) {
    color(255, 255, 255, 0.72).setFill()
    rounded(rect(54, 54, size.width - 108, size.height - 108), radius: 64).fill()
}

func drawHeader(shot: Shot, size: NSSize) {
    drawText("PinyinFlow", x: 110, y: 138, width: 560, font: roundedFont(size: 68, weight: .bold), color: color(114, 0, 14))
    drawPillIcon(symbol: "+", x: 1044, y: 126)
    drawPillIcon(symbol: "⚙", x: 1140, y: 126)
    drawText(shot.headline, x: 110, y: 308, width: 1040, font: roundedFont(size: 70, weight: .bold), color: color(74, 0, 10))
    drawText(shot.subhead, x: 110, y: 430, width: 1000, font: .systemFont(ofSize: 35, weight: .medium), color: color(127, 69, 76))
}

func drawHome(size: NSSize) {
    drawSearchBar(y: 590, text: "中国語・拼音・翻訳を検索")
    let items: [(String, String, NSColor)] = [
        ("1:07", "问界M9停车补电", color(208, 66, 42)),
        ("0:45", "虽然他们来自不同国家…", color(160, 24, 36)),
        ("TEXT", "这段采访很适合练习听力。", color(255, 255, 255)),
        ("2:18", "小红书热门短视频", color(227, 94, 74)),
        ("AUDIO", "今天的播客片段", color(255, 255, 255)),
        ("0:38", "上海街头采访", color(178, 43, 50))
    ]
    let cardW: CGFloat = 340
    let cardH: CGFloat = 505
    let gap: CGFloat = 36
    for index in 0..<items.count {
        let col = index % 3
        let row = index / 3
        let x = CGFloat(110 + col * Int(cardW + gap))
        let y = CGFloat(760 + row * Int(cardH + 44))
        drawHistoryCard(x: x, y: y, width: cardW, height: cardH, badge: items[index].0, title: items[index].1, tint: items[index].2)
    }
}

func drawPlayer(size: NSSize) {
    rounded(rect(96, 580, 1098, 830), radius: 38).fill(color(23, 14, 16))
    let videoRect = rect(260, 628, 770, 730)
    verticalGradient(in: videoRect, top: color(228, 70, 58), bottom: color(38, 22, 24))
    drawText("哥哥现在就到了吗", x: 340, y: 1220, width: 650, font: .systemFont(ofSize: 48, weight: .heavy), color: .white, alignment: .center)
    drawText("0.75×", x: 970, y: 1330, width: 92, font: .systemFont(ofSize: 25, weight: .bold), color: .white, alignment: .center)
    drawSubtitleCard(y: 1490, active: true, chinese: "哥哥现在就到了吗", pinyin: "gē ge xiàn zài jiù dào le ma", translation: "お兄さんはもう着きましたか？")
    drawSubtitleCard(y: 1812, active: false, chinese: "我们先打开车门看看", pinyin: "wǒ men xiān dǎ kāi chē mén kàn kan", translation: "まず車のドアを開けて見てみましょう。")
    drawSubtitleCard(y: 2134, active: false, chinese: "这个表达很常用", pinyin: "zhè ge biǎo dá hěn cháng yòng", translation: "この表現はとてもよく使われます。")
}

func drawFavorites(size: NSSize) {
    drawText("お気に入り", x: 110, y: 590, width: 640, font: roundedFont(size: 66, weight: .bold), color: color(114, 0, 14))
    drawSearchBar(y: 715, text: "お気に入りを検索")
    drawFavorite(y: 890, chinese: "这个表达很常用", pinyin: "zhè ge biǎo dá hěn cháng yòng", translation: "この表現はとてもよく使われます。")
    drawFavorite(y: 1196, chinese: "虽然他们来自不同的国家", pinyin: "suī rán tā men lái zì bù tóng de guó jiā", translation: "彼らは違う国から来ていますが。")
    drawFavorite(y: 1502, chinese: "我们先打开看看", pinyin: "wǒ men xiān dǎ kāi kàn kan", translation: "まず開いて見てみましょう。")
    drawFavorite(y: 1808, chinese: "今天的内容很适合练习", pinyin: "jīn tiān de nèi róng hěn shì hé liàn xí", translation: "今日の内容は練習にぴったりです。")
}

func drawPillIcon(symbol: String, x: CGFloat, y: CGFloat) {
    rounded(rect(x, y, 72, 72), radius: 36).fill(color(114, 0, 14))
    drawText(symbol, x: x, y: y + 9, width: 72, font: .systemFont(ofSize: 38, weight: .bold), color: color(255, 250, 250), alignment: .center)
}

func drawSearchBar(y: CGFloat, text: String) {
    rounded(rect(110, y, 1070, 92), radius: 38).fill(.white)
    drawText("⌕", x: 148, y: y + 15, width: 70, font: .systemFont(ofSize: 48, weight: .medium), color: color(126, 72, 80))
    drawText(text, x: 230, y: y + 26, width: 860, font: .systemFont(ofSize: 34, weight: .semibold), color: color(148, 95, 102))
}

func drawHistoryCard(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, badge: String, title: String, tint: NSColor) {
    rounded(rect(x, y, width, height), radius: 24).fill(.white)
    let media = rect(x + 18, y + 18, width - 36, height - 36)
    if tint == .white {
        color(255, 246, 246).setFill()
        rounded(media, radius: 18).fill()
        drawText(title, x: x + 42, y: y + 96, width: width - 84, font: .systemFont(ofSize: 36, weight: .heavy), color: color(89, 20, 28))
        drawText("≡", x: x + 44, y: y + height - 92, width: 56, font: .systemFont(ofSize: 40, weight: .bold), color: color(139, 89, 96))
    } else {
        verticalGradient(in: media, top: tint, bottom: color(68, 15, 23))
        drawText(title, x: x + 38, y: y + height - 148, width: width - 76, font: .systemFont(ofSize: 36, weight: .heavy), color: .white)
    }
    rounded(rect(x + width - 112, y + height - 86, 86, 48), radius: 24).fill(color(0, 0, 0, 0.48))
    drawText(badge, x: x + width - 108, y: y + height - 76, width: 78, font: .systemFont(ofSize: 25, weight: .bold), color: .white, alignment: .center)
}

func drawSubtitleCard(y: CGFloat, active: Bool, chinese: String, pinyin: String, translation: String) {
    rounded(rect(110, y, 1070, 260), radius: 26).fill(active ? color(255, 222, 222) : .white)
    drawText(pinyin, x: 170, y: y + 36, width: 860, font: .systemFont(ofSize: 30, weight: .semibold), color: color(208, 24, 36))
    drawText(chinese, x: 170, y: y + 88, width: 860, font: .systemFont(ofSize: 52, weight: .heavy), color: color(33, 15, 18))
    drawText(translation, x: 170, y: y + 172, width: 860, font: .systemFont(ofSize: 35, weight: .semibold), color: color(121, 83, 88))
    drawText("☆", x: 1030, y: y + 34, width: 80, font: .systemFont(ofSize: 34, weight: .regular), color: color(197, 40, 48), alignment: .center)
}

func drawFavorite(y: CGFloat, chinese: String, pinyin: String, translation: String) {
    rounded(rect(110, y, 1070, 246), radius: 26).fill(.white)
    drawText("★", x: 160, y: y + 40, width: 50, font: .systemFont(ofSize: 30, weight: .semibold), color: color(197, 40, 48), alignment: .center)
    drawText(pinyin, x: 232, y: y + 34, width: 870, font: .systemFont(ofSize: 30, weight: .semibold), color: color(208, 24, 36))
    drawText(chinese, x: 232, y: y + 82, width: 880, font: .systemFont(ofSize: 47, weight: .heavy), color: color(33, 15, 18))
    drawText(translation, x: 232, y: y + 162, width: 880, font: .systemFont(ofSize: 33, weight: .semibold), color: color(121, 83, 88))
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    NSString(string: text).draw(with: rect(x, y, width, 220), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}

func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard
        let descriptor = base.fontDescriptor.withDesign(.rounded),
        let font = NSFont(descriptor: descriptor, size: size)
    else {
        return base
    }
    return font
}

func rounded(_ r: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func verticalGradient(in r: NSRect, top: NSColor, bottom: NSColor) {
    let gradient = NSGradient(starting: top, ending: bottom)
    gradient?.draw(in: rounded(r, radius: 18), angle: -90)
}

extension NSBezierPath {
    func fill(_ color: NSColor) {
        color.setFill()
        fill()
    }
}
