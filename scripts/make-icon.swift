import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: make-icon <iconset-dir>\n", stderr)
    exit(1)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.22, yRadius: size * 0.22)
    NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.55, alpha: 1).setFill()
    path.fill()
    let body = NSBezierPath(roundedRect: NSRect(x: size * 0.18, y: size * 0.28, width: size * 0.64, height: size * 0.40), xRadius: size * 0.18, yRadius: size * 0.18)
    NSColor(calibratedRed: 0.12, green: 0.55, blue: 0.95, alpha: 1).setFill()
    body.fill()
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.28, y: size * 0.38, width: size * 0.12, height: size * 0.12)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.60, y: size * 0.38, width: size * 0.12, height: size * 0.12)).fill()
    image.unlockFocus()
    return image
}

let named: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, px) in named {
    let img = draw(size: CGFloat(px))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: out.appendingPathComponent(name))
}
print("wrote iconset \(out.path)")
