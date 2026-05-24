import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let bounds = CGRect(origin: .zero, size: size)
NSColor(red: 0.55, green: 0.02, blue: 0.05, alpha: 1).setFill()
NSBezierPath(rect: bounds).fill()

let gradient = NSGradient(colors: [
    NSColor(red: 0.90, green: 0.13, blue: 0.13, alpha: 1),
    NSColor(red: 0.42, green: 0.02, blue: 0.08, alpha: 1)
])!
gradient.draw(in: NSBezierPath(rect: bounds), angle: -35)

NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: CGRect(x: 610, y: 610, width: 360, height: 360)).fill()
NSBezierPath(ovalIn: CGRect(x: -120, y: -90, width: 430, height: 430)).fill()

let cardRect = CGRect(x: 178, y: 172, width: 668, height: 260)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 54, yRadius: 54)
NSColor.white.withAlphaComponent(0.92).setFill()
cardPath.fill()

NSColor(red: 0.55, green: 0.02, blue: 0.05, alpha: 0.26).setFill()
NSBezierPath(roundedRect: CGRect(x: 260, y: 244, width: 210, height: 24), xRadius: 12, yRadius: 12).fill()
NSBezierPath(roundedRect: CGRect(x: 508, y: 244, width: 260, height: 24), xRadius: 12, yRadius: 12).fill()
NSBezierPath(roundedRect: CGRect(x: 260, y: 310, width: 360, height: 26), xRadius: 13, yRadius: 13).fill()

let toneAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 104, weight: .bold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.92)
]
let tone = "pīn"
let toneSize = tone.size(withAttributes: toneAttributes)
tone.draw(
    at: CGPoint(x: (1024 - toneSize.width) / 2, y: 720),
    withAttributes: toneAttributes
)

let hanziAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 410, weight: .black),
    .foregroundColor: NSColor.white
]
let hanzi = "拼"
let hanziSize = hanzi.size(withAttributes: hanziAttributes)
hanzi.draw(
    at: CGPoint(x: (1024 - hanziSize.width) / 2, y: 350),
    withAttributes: hanziAttributes
)

NSColor.white.withAlphaComponent(0.96).setFill()
let playPath = NSBezierPath()
playPath.move(to: CGPoint(x: 728, y: 506))
playPath.line(to: CGPoint(x: 728, y: 616))
playPath.line(to: CGPoint(x: 828, y: 561))
playPath.close()
playPath.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render app icon")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
