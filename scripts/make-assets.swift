import AppKit
import Foundation

/// Generates stylized (abstract) PNG assets for Mac Gaming Helper.
/// Not photo-realistic trademark replicas — silhouette / iconographic art only.

let outDir: URL = {
    if CommandLine.arguments.count >= 2 {
        return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Resources", isDirectory: true)
}()

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

let navy = rgba(0.05, 0.12, 0.28)
let deep = rgba(0.08, 0.18, 0.38)
let blue = rgba(0.10, 0.48, 0.95)
let cyan = rgba(0.20, 0.75, 0.95)
let glow = rgba(0.30, 0.85, 1.0)
let soft = rgba(0.75, 0.85, 0.98)
let darkPad = rgba(0.12, 0.14, 0.18)
let midPad = rgba(0.18, 0.22, 0.30)

func makeImage(width: Int, height: Int, draw: (NSGraphicsContext, CGRect) -> Void) -> NSImage {
    let size = NSSize(width: width, height: height)
    let image = NSImage(size: size)
    image.lockFocus()
    if let ctx = NSGraphicsContext.current {
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true
        draw(ctx, CGRect(origin: .zero, size: size))
    }
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, name: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("failed \(name)\n", stderr)
        return
    }
    let url = outDir.appendingPathComponent(name)
    try? png.write(to: url)
    print("wrote \(url.path)")
}

func roundedFill(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func oval(_ rect: CGRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func strokeOval(_ rect: CGRect, color: NSColor, width: CGFloat) {
    let p = NSBezierPath(ovalIn: rect)
    p.lineWidth = width
    color.setStroke()
    p.stroke()
}

func line(_ a: CGPoint, _ b: CGPoint, color: NSColor, width: CGFloat) {
    let p = NSBezierPath()
    p.move(to: a)
    p.line(to: b)
    p.lineWidth = width
    p.lineCapStyle = .round
    color.setStroke()
    p.stroke()
}

/// Abstract dual-stick pad silhouette (not a brand replica).
func drawPad(in bounds: CGRect, lit: Bool, lightHue: CGFloat = 0.55) {
    let w = bounds.width
    let h = bounds.height
    let body = CGRect(
        x: bounds.minX + w * 0.12,
        y: bounds.minY + h * 0.28,
        width: w * 0.76,
        height: h * 0.48
    )
    // Soft shadow
    roundedFill(body.offsetBy(dx: 0, dy: -h * 0.02).insetBy(dx: -2, dy: -2), radius: h * 0.18, color: rgba(0, 0, 0, 0.25))
    // Body
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: h * 0.18, yRadius: h * 0.18)
    (lit ? midPad : darkPad).setFill()
    bodyPath.fill()
    // Gradient overlay via lighter top strip
    roundedFill(
        CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height * 0.5),
        radius: h * 0.12,
        color: rgba(1, 1, 1, lit ? 0.08 : 0.04)
    )
    // Grips
    let gripL = CGRect(x: bounds.minX + w * 0.08, y: bounds.minY + h * 0.18, width: w * 0.22, height: h * 0.42)
    let gripR = CGRect(x: bounds.minX + w * 0.70, y: bounds.minY + h * 0.18, width: w * 0.22, height: h * 0.42)
    roundedFill(gripL, radius: w * 0.08, color: lit ? midPad : darkPad)
    roundedFill(gripR, radius: w * 0.08, color: lit ? midPad : darkPad)

    // Touchpad slab
    let tp = CGRect(x: bounds.minX + w * 0.32, y: bounds.minY + h * 0.52, width: w * 0.36, height: h * 0.16)
    roundedFill(tp, radius: 6, color: lit ? rgba(0.25, 0.45, 0.70, 0.9) : rgba(0.2, 0.25, 0.32, 0.9))

    // Light bar
    let bar = CGRect(x: bounds.minX + w * 0.28, y: bounds.minY + h * 0.70, width: w * 0.44, height: h * 0.05)
    let light = lit
        ? NSColor(calibratedHue: lightHue, saturation: 0.85, brightness: 1.0, alpha: 1)
        : rgba(0.3, 0.35, 0.45, 0.6)
    roundedFill(bar, radius: 4, color: light)
    if lit {
        roundedFill(bar.insetBy(dx: -6, dy: -4), radius: 8, color: light.withAlphaComponent(0.25))
    }

    // Sticks
    let stickR: CGFloat = w * 0.07
    oval(CGRect(x: bounds.minX + w * 0.28 - stickR, y: bounds.minY + h * 0.34 - stickR, width: stickR * 2, height: stickR * 2),
         color: rgba(0.08, 0.10, 0.14))
    oval(CGRect(x: bounds.minX + w * 0.72 - stickR, y: bounds.minY + h * 0.34 - stickR, width: stickR * 2, height: stickR * 2),
         color: rgba(0.08, 0.10, 0.14))
    let knob: CGFloat = stickR * 0.55
    oval(CGRect(x: bounds.minX + w * 0.28 - knob, y: bounds.minY + h * 0.34 - knob, width: knob * 2, height: knob * 2),
         color: lit ? cyan.withAlphaComponent(0.85) : soft.withAlphaComponent(0.35))
    oval(CGRect(x: bounds.minX + w * 0.72 - knob, y: bounds.minY + h * 0.34 - knob, width: knob * 2, height: knob * 2),
         color: lit ? cyan.withAlphaComponent(0.85) : soft.withAlphaComponent(0.35))

    // Face diamonds (abstract)
    let fx = bounds.minX + w * 0.72
    let fy = bounds.minY + h * 0.55
    let d: CGFloat = w * 0.035
    func diamond(_ cx: CGFloat, _ cy: CGFloat, on: Bool) {
        let p = NSBezierPath()
        p.move(to: CGPoint(x: cx, y: cy + d))
        p.line(to: CGPoint(x: cx + d, y: cy))
        p.line(to: CGPoint(x: cx, y: cy - d))
        p.line(to: CGPoint(x: cx - d, y: cy))
        p.close()
        (on && lit ? glow : soft.withAlphaComponent(0.4)).setFill()
        p.fill()
    }
    diamond(fx, fy + d * 2.2, on: lit)
    diamond(fx + d * 2.2, fy, on: lit)
    diamond(fx, fy - d * 2.2, on: lit)
    diamond(fx - d * 2.2, fy, on: lit)

    // D-pad cross
    let dx = bounds.minX + w * 0.28
    let dy = bounds.minY + h * 0.55
    let arm: CGFloat = w * 0.045
    roundedFill(CGRect(x: dx - arm * 0.4, y: dy - arm * 1.4, width: arm * 0.8, height: arm * 2.8), radius: 3, color: soft.withAlphaComponent(lit ? 0.55 : 0.3))
    roundedFill(CGRect(x: dx - arm * 1.4, y: dy - arm * 0.4, width: arm * 2.8, height: arm * 0.8), radius: 3, color: soft.withAlphaComponent(lit ? 0.55 : 0.3))
}

// MARK: - Assets

// Hero pad (empty / waiting) — dim
writePNG(makeImage(width: 720, height: 420) { _, rect in
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 28, yRadius: 28)
    navy.setFill(); bg.fill()
    // subtle rings
    for i in 1...3 {
        let inset = CGFloat(i) * 28
        strokeOval(rect.insetBy(dx: inset + 40, dy: inset + 20), color: blue.withAlphaComponent(0.12), width: 2)
    }
    drawPad(in: rect.insetBy(dx: 40, dy: 10), lit: false)
}, name: "hero-pad.png")

// Hero pad lit (connected vibe)
writePNG(makeImage(width: 720, height: 420) { _, rect in
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 28, yRadius: 28)
    deep.setFill(); bg.fill()
    for i in 1...4 {
        let inset = CGFloat(i) * 22
        strokeOval(rect.insetBy(dx: inset + 30, dy: inset + 10), color: cyan.withAlphaComponent(0.18), width: 2)
    }
    drawPad(in: rect.insetBy(dx: 40, dy: 10), lit: true, lightHue: 0.55)
}, name: "hero-pad-lit.png")

// Coach: USB cable
writePNG(makeImage(width: 320, height: 200) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 20, color: navy)
    // Mac side port
    roundedFill(CGRect(x: 36, y: 70, width: 50, height: 60), radius: 8, color: midPad)
    roundedFill(CGRect(x: 46, y: 88, width: 30, height: 24), radius: 4, color: rgba(0.05, 0.08, 0.12))
    // Cable
    let cable = NSBezierPath()
    cable.move(to: CGPoint(x: 86, y: 100))
    cable.curve(to: CGPoint(x: 200, y: 100),
                controlPoint1: CGPoint(x: 130, y: 40),
                controlPoint2: CGPoint(x: 160, y: 160))
    cable.lineWidth = 8
    cyan.setStroke()
    cable.stroke()
    // Pad plug end
    roundedFill(CGRect(x: 200, y: 78, width: 70, height: 44), radius: 10, color: darkPad)
    roundedFill(CGRect(x: 210, y: 90, width: 36, height: 20), radius: 3, color: soft.withAlphaComponent(0.5))
    // USB label hint
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .foregroundColor: soft
    ]
    ("USB-first" as NSString).draw(at: CGPoint(x: 110, y: 22), withAttributes: attrs)
}, name: "coach-usb.png")

// Coach: Bluetooth waves
writePNG(makeImage(width: 320, height: 200) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 20, color: navy)
    let cx: CGFloat = 110
    let cy: CGFloat = 100
    // Rune-like BT mark (abstract, not official logo)
    let rune = NSBezierPath()
    rune.move(to: CGPoint(x: cx, y: cy + 42))
    rune.line(to: CGPoint(x: cx, y: cy - 42))
    rune.move(to: CGPoint(x: cx - 18, y: cy + 18))
    rune.line(to: CGPoint(x: cx + 22, y: cy - 18))
    rune.line(to: CGPoint(x: cx, y: cy))
    rune.line(to: CGPoint(x: cx + 22, y: cy + 18))
    rune.line(to: CGPoint(x: cx - 18, y: cy - 18))
    rune.lineWidth = 5
    rune.lineCapStyle = .round
    rune.lineJoinStyle = .round
    cyan.setStroke()
    rune.stroke()
    // Waves toward pad silhouette
    for i in 1...3 {
        let r = CGFloat(30 + i * 22)
        let arc = NSBezierPath()
        arc.appendArc(withCenter: CGPoint(x: cx, y: cy), radius: r, startAngle: -50, endAngle: 50)
        arc.lineWidth = 3
        blue.withAlphaComponent(1.0 - CGFloat(i) * 0.22).setStroke()
        arc.stroke()
    }
    // Mini pad
    drawPad(in: CGRect(x: 190, y: 40, width: 110, height: 120), lit: true, lightHue: 0.58)
}, name: "coach-bluetooth.png")

// Coach: Reset pin
writePNG(makeImage(width: 320, height: 200) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 20, color: navy)
    // Pad back abstract
    roundedFill(CGRect(x: 70, y: 40, width: 180, height: 120), radius: 36, color: darkPad)
    // Pinhole
    oval(CGRect(x: 148, y: 88, width: 16, height: 16), color: rgba(0.02, 0.04, 0.08))
    strokeOval(CGRect(x: 140, y: 80, width: 32, height: 32), color: rgba(0.95, 0.55, 0.2), width: 3)
    // Paperclip
    let clip = NSBezierPath()
    clip.move(to: CGPoint(x: 230, y: 160))
    clip.line(to: CGPoint(x: 230, y: 70))
    clip.appendArc(withCenter: CGPoint(x: 215, y: 70), radius: 15, startAngle: 0, endAngle: 180, clockwise: false)
    clip.line(to: CGPoint(x: 200, y: 130))
    clip.lineWidth = 4
    soft.setStroke()
    clip.stroke()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: rgba(0.95, 0.70, 0.30)
    ]
    ("Reset pinhole" as NSString).draw(at: CGPoint(x: 100, y: 18), withAttributes: attrs)
}, name: "coach-reset.png")

// Coach: Share + PS
writePNG(makeImage(width: 320, height: 200) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 20, color: navy)
    drawPad(in: CGRect(x: 40, y: 20, width: 240, height: 160), lit: true, lightHue: 0.62)
    // Flash rays on light bar area
    let flash = NSBezierPath()
    for angle in stride(from: 20, through: 160, by: 20) {
        let rad = CGFloat(angle) * .pi / 180
        flash.move(to: CGPoint(x: 160, y: 145))
        flash.line(to: CGPoint(x: 160 + cos(rad) * 70, y: 145 + sin(rad) * 28))
    }
    flash.lineWidth = 2
    glow.withAlphaComponent(0.7).setStroke()
    flash.stroke()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: soft
    ]
    ("Share + PS" as NSString).draw(at: CGPoint(x: 118, y: 14), withAttributes: attrs)
}, name: "coach-share-ps.png")

// Mapping badge
writePNG(makeImage(width: 280, height: 160) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 18, color: navy)
    // Keyboard keys
    let keys = ["W", "A", "S", "D"]
    let positions: [(CGFloat, CGFloat)] = [(110, 95), (78, 60), (110, 60), (142, 60)]
    for (i, k) in keys.enumerated() {
        let r = CGRect(x: positions[i].0, y: positions[i].1, width: 28, height: 28)
        roundedFill(r, radius: 6, color: midPad)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: soft
        ]
        (k as NSString).draw(at: CGPoint(x: r.minX + 8, y: r.minY + 6), withAttributes: attrs)
    }
    // Arrow from stick
    oval(CGRect(x: 36, y: 68, width: 28, height: 28), color: cyan.withAlphaComponent(0.8))
    line(CGPoint(x: 66, y: 82), CGPoint(x: 100, y: 82), color: blue, width: 3)
    // Mouse
    roundedFill(CGRect(x: 196, y: 55, width: 44, height: 64), radius: 14, color: midPad)
    line(CGPoint(x: 218, y: 95), CGPoint(x: 218, y: 110), color: soft.withAlphaComponent(0.5), width: 2)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: soft
    ]
    ("Pad → Keys" as NSString).draw(at: CGPoint(x: 100, y: 20), withAttributes: attrs)
}, name: "badge-mapping.png")

// Launcher badge
writePNG(makeImage(width: 280, height: 160) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 18, color: navy)
    let titles = ["Steam", "Heroic", "GFN"]
    let colors = [blue, rgba(0.45, 0.55, 0.95), rgba(0.2, 0.85, 0.45)]
    for (i, title) in titles.enumerated() {
        let x = 28 + CGFloat(i) * 80
        roundedFill(CGRect(x: x, y: 55, width: 68, height: 68), radius: 16, color: colors[i].withAlphaComponent(0.35))
        strokeOval(CGRect(x: x + 14, y: 70, width: 40, height: 40), color: colors[i], width: 3)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: soft
        ]
        (title as NSString).draw(at: CGPoint(x: x + 12, y: 30), withAttributes: attrs)
    }
}, name: "badge-launchers.png")

// Help / about badge
writePNG(makeImage(width: 280, height: 160) { _, rect in
    roundedFill(rect.insetBy(dx: 4, dy: 4), radius: 18, color: navy)
    strokeOval(CGRect(x: 110, y: 55, width: 60, height: 60), color: cyan, width: 5)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 36, weight: .bold),
        .foregroundColor: soft
    ]
    ("?" as NSString).draw(at: CGPoint(x: 130, y: 65), withAttributes: attrs)
    let t: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: soft
    ]
    ("Setup & Help" as NSString).draw(at: CGPoint(x: 100, y: 24), withAttributes: t)
}, name: "badge-help.png")

// README banner
writePNG(makeImage(width: 1280, height: 640) { _, rect in
    navy.setFill(); NSBezierPath(rect: rect).fill()
    // Diagonal glow
    for i in 0..<8 {
        let y = CGFloat(i) * 80
        roundedFill(CGRect(x: -40, y: y, width: 1400, height: 40), radius: 0, color: blue.withAlphaComponent(0.04))
    }
    drawPad(in: CGRect(x: 640, y: 80, width: 560, height: 420), lit: true, lightHue: 0.55)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 52, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    ("Mac Gaming Helper" as NSString).draw(at: CGPoint(x: 64, y: 360), withAttributes: titleAttrs)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .medium),
        .foregroundColor: soft
    ]
    ("DualShock 4 desk for macOS — pair, map, play" as NSString)
        .draw(at: CGPoint(x: 64, y: 310), withAttributes: subAttrs)
    let chip = CGRect(x: 64, y: 240, width: 160, height: 36)
    roundedFill(chip, radius: 18, color: blue)
    let chipAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    ("v2.2 · macOS 14+" as NSString).draw(at: CGPoint(x: 84, y: 248), withAttributes: chipAttrs)
}, name: "banner.png")

// Also copy banner into docs later via shell; write app iconset sizes into build via separate path
// Richer app icon source (1024) for iconutil
let iconMaster = makeImage(width: 1024, height: 1024) { _, rect in
    let inset = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
    let path = NSBezierPath(roundedRect: inset, xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
    // Deep blue fill
    rgba(0.04, 0.18, 0.48).setFill()
    path.fill()
    // Inner glow circle
    oval(rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18), color: rgba(0.08, 0.35, 0.75, 0.45))
    drawPad(in: rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.14), lit: true, lightHue: 0.55)
}
writePNG(iconMaster, name: "AppIcon-1024.png")

print("assets ready in \(outDir.path)")
