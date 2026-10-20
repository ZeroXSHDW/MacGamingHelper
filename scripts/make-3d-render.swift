import AppKit
import Foundation

/// Renders a 3D-style (tilted, shaded, shadowed) mockup of the Mac Gaming
/// Helper controller desk for the README. Not a trademark replica — abstract
/// UI + silhouette art only.
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

let navy = rgba(0.045, 0.10, 0.22)
let deep = rgba(0.07, 0.16, 0.34)
let blue = rgba(0.10, 0.48, 0.95)
let cyan = rgba(0.20, 0.75, 0.95)
let glow = rgba(0.30, 0.85, 1.0)
let good = rgba(0.20, 0.75, 0.40)
let warn = rgba(0.95, 0.70, 0.20)
let mute = rgba(0.68, 0.76, 0.88)
let card = rgba(0.14, 0.22, 0.40)
let darkPad = rgba(0.12, 0.14, 0.18)
let midPad = rgba(0.20, 0.24, 0.32)

func roundedFill(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: CGRect, align: NSTextAlignment = .left) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let style = NSMutableParagraphStyle()
    style.alignment = align
    style.lineBreakMode = .byTruncatingTail
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    (s as NSString).draw(in: rect, withAttributes: attrs)
}

func pill(_ rect: CGRect, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
}

func circle(_ center: CGPoint, r: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)).fill()
}

/// Abstract dual-stick pad silhouette.
func drawPad(in bounds: CGRect, lit: Bool) {
    let w = bounds.width
    let h = bounds.height
    let body = CGRect(x: bounds.minX + w * 0.14, y: bounds.minY + h * 0.30, width: w * 0.72, height: h * 0.46)
    roundedFill(body.offsetBy(dx: 0, dy: -h * 0.02), radius: h * 0.18, color: rgba(0, 0, 0, 0.30))
    roundedFill(body, radius: h * 0.18, color: lit ? midPad : darkPad)
    roundedFill(CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height * 0.5), radius: h * 0.12, color: rgba(1, 1, 1, lit ? 0.08 : 0.04))
    let gripL = CGRect(x: bounds.minX + w * 0.10, y: bounds.minY + h * 0.20, width: w * 0.22, height: h * 0.42)
    let gripR = CGRect(x: bounds.minX + w * 0.68, y: bounds.minY + h * 0.20, width: w * 0.22, height: h * 0.42)
    roundedFill(gripL, radius: w * 0.08, color: lit ? midPad : darkPad)
    roundedFill(gripR, radius: w * 0.08, color: lit ? midPad : darkPad)
    let tp = CGRect(x: bounds.minX + w * 0.32, y: bounds.minY + h * 0.52, width: w * 0.36, height: h * 0.16)
    roundedFill(tp, radius: 6, color: lit ? rgba(0.25, 0.45, 0.70, 0.9) : rgba(0.20, 0.25, 0.32, 0.9))
    let bar = CGRect(x: bounds.minX + w * 0.28, y: bounds.minY + h * 0.70, width: w * 0.44, height: h * 0.05)
    roundedFill(bar, radius: 4, color: lit ? glow : rgba(0.3, 0.35, 0.45, 0.6))
    // Sticks
    let lx = bounds.minX + w * 0.34
    let rx = bounds.minX + w * 0.66
    let sy = bounds.minY + h * 0.62
    strokeStick(center: CGPoint(x: lx, y: sy), r: w * 0.075)
    strokeStick(center: CGPoint(x: rx, y: sy), r: w * 0.075)
}

func strokeStick(center: CGPoint, r: CGFloat) {
    let p = NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    p.lineWidth = 2
    rgba(0.5, 0.6, 0.75, 0.7).setStroke()
    p.stroke()
    let inner = NSBezierPath(ovalIn: CGRect(x: center.x - r * 0.4, y: center.y - r * 0.4, width: r * 0.8, height: r * 0.8))
    rgba(0.5, 0.6, 0.75, 0.5).setFill()
    inner.fill()
}

func makeImage(_ w: Int, _ h: Int, _ draw: (CGRect) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    draw(CGRect(x: 0, y: 0, width: w, height: h))
    img.unlockFocus()
    return img
}

func writePNG(_ image: NSImage, name: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("failed \(name)\n", stderr)
        return
    }
    try? png.write(to: outDir.appendingPathComponent(name))
    print("wrote \(outDir.appendingPathComponent(name).path)")
}

func cgImage(_ image: NSImage) -> CGImage? {
    var r = CGRect(origin: .zero, size: image.size)
    return image.cgImage(forProposedRect: &r, context: nil, hints: nil)
}

// MARK: - Flat "screenshot" of the app (Controller page)

let shotW: CGFloat = 1180
let shotH: CGFloat = 780

let shot = makeImage(Int(shotW), Int(shotH)) { rect in
    // Window background
    let bg = NSGradient(colors: [navy, deep])!
    bg.draw(in: rect, angle: 90)

    // Title bar
    roundedFill(CGRect(x: 0, y: shotH - 46, width: shotW, height: 46), radius: 0, color: rgba(0.03, 0.06, 0.14, 0.6))
    circle(CGPoint(x: 26, y: shotH - 23), r: 7, color: rgba(0.95, 0.32, 0.32, 0.9))
    circle(CGPoint(x: 46, y: shotH - 23), r: 7, color: rgba(0.95, 0.78, 0.25, 0.9))
    circle(CGPoint(x: 66, y: shotH - 23), r: 7, color: rgba(0.30, 0.80, 0.40, 0.9))
    text("Mac Gaming Helper — PlayStation Controller Desk", size: 14, weight: .medium, color: rgba(1, 1, 1, 0.8), in: CGRect(x: 0, y: shotH - 42, width: shotW, height: 38), align: .center)

    // Sidebar
    let side = CGRect(x: 0, y: 0, width: 232, height: shotH - 46)
    rgba(0.04, 0.08, 0.18).setFill()
    NSBezierPath(rect: side).fill()
    let items = ["Play", "Controller", "Input Test", "Mapping", "Launchers", "Pairing", "Settings", "Help"]
    for (i, name) in items.enumerated() {
        let y = shotH - 92 - CGFloat(i) * 56
        let row = CGRect(x: 12, y: y, width: 208, height: 42)
        if name == "Controller" {
            roundedFill(row, radius: 10, color: rgba(0.10, 0.48, 0.95, 0.30))
        }
        circle(CGPoint(x: 34, y: y + 21), r: 9, color: name == "Controller" ? blue : rgba(0.55, 0.65, 0.82))
        text(name, size: 15, weight: .medium, color: name == "Controller" ? rgba(1, 1, 1, 1) : rgba(0.75, 0.83, 0.95), in: CGRect(x: 54, y: y + 9, width: 150, height: 24))
    }
    // Sidebar bottom status
    roundedFill(CGRect(x: 12, y: 12, width: 208, height: 46), radius: 10, color: card)
    circle(CGPoint(x: 30, y: 35), r: 6, color: good)
    text("DualSense · Bluetooth", size: 12, weight: .semibold, color: mute, in: CGRect(x: 44, y: 23, width: 160, height: 24))

    // Content
    let cx: CGFloat = 264
    let cw = shotW - cx - 28
    text("PlayStation Controller Desk", size: 30, weight: .bold, color: .white, in: CGRect(x: cx, y: shotH - 96, width: cw, height: 40))
    text("DualSense connected · Bluetooth · Player 1", size: 14, weight: .regular, color: mute, in: CGRect(x: cx, y: shotH - 128, width: cw, height: 24))

    // Status chips
    var chipX = cx
    let chips: [(String, NSColor)] = [("Bluetooth", blue), ("P1", blue), ("Adaptive", good), ("Motion", good)]
    for (label, col) in chips {
        let w: CGFloat = label == "Adaptive" ? 76 : (label == "Bluetooth" ? 82 : 46)
        pill(CGRect(x: chipX, y: shotH - 158, width: w, height: 24), color: col.withAlphaComponent(0.22))
        text(label, size: 12, weight: .bold, color: col, in: CGRect(x: chipX, y: shotH - 155, width: w, height: 18), align: .center)
        chipX += w + 8
    }

    // Hero pad
    let padRect = CGRect(x: cx + cw * 0.16, y: shotH - 470, width: cw * 0.68, height: 300)
    drawPad(in: padRect, lit: true)

    // Cards
    let cardY = shotH - 660
    let cardW = cw * 0.44
    roundedFill(CGRect(x: cx, y: cardY, width: cardW, height: 120), radius: 14, color: card)
    text("Wireless readiness", size: 15, weight: .semibold, color: .white, in: CGRect(x: cx + 16, y: cardY + 88, width: cardW - 32, height: 22))
    pill(CGRect(x: cx + 16, y: cardY + 56, width: 92, height: 22), color: good.withAlphaComponent(0.20))
    text("Bluetooth On", size: 11, weight: .bold, color: good, in: CGRect(x: cx + 16, y: cardY + 59, width: 92, height: 16), align: .center)
    pill(CGRect(x: cx + 116, y: cardY + 56, width: 62, height: 22), color: good.withAlphaComponent(0.20))
    text("Paired", size: 11, weight: .bold, color: good, in: CGRect(x: cx + 116, y: cardY + 59, width: 62, height: 16), align: .center)

    roundedFill(CGRect(x: cx + cardW + 24, y: cardY, width: cardW, height: 120), radius: 14, color: card)
    text("Pad Check", size: 15, weight: .semibold, color: .white, in: CGRect(x: cx + cardW + 40, y: cardY + 88, width: cardW - 32, height: 22))
    pill(CGRect(x: cx + cardW + 40, y: cardY + 56, width: 108, height: 22), color: blue.withAlphaComponent(0.24))
    text("19/19 verified", size: 11, weight: .bold, color: cyan, in: CGRect(x: cx + cardW + 40, y: cardY + 59, width: 108, height: 16), align: .center)

    // Metric capsules (the game bar)
    let metricY = cardY - 58
    let metrics: [(String, NSColor)] = [("CPU 34%", good), ("MEM 48%", good), ("GPU 61%", warn), ("Thermal NOM", good), ("Ping 12ms", cyan)]
    var mx = cx
    for (label, col) in metrics {
        let w = CGFloat(label.count) * 9.5 + 16
        pill(CGRect(x: mx, y: metricY, width: w, height: 26), color: rgba(0.5, 0.6, 0.75, 0.14))
        text(label, size: 12, weight: .bold, color: col, in: CGRect(x: mx, y: metricY + 4, width: w, height: 18), align: .center)
        mx += w + 8
    }
}

// MARK: - 3D composite (tilt + shadow + reflection)

let finalW = 1400
let finalH = 1020

let final = makeImage(finalW, finalH) { rect in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    // Background
    let bg = NSGradient(colors: [rgba(0.03, 0.07, 0.16), rgba(0.06, 0.14, 0.30), rgba(0.03, 0.06, 0.14)])!
    bg.draw(in: rect, angle: 90)

    // Soft radial glow behind the window
    let glowRect = CGRect(x: 250, y: 240, width: 900, height: 600)
    let glowGrad = NSGradient(colors: [glow.withAlphaComponent(0.20), glow.withAlphaComponent(0.0)])!
    glowGrad.draw(in: glowRect, angle: 90)

    guard let shotCG = cgImage(shot) else { return }

    // Floor shadow (blurred ellipse)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: rgba(0, 0, 0, 0.6).cgColor)
    let shadow = NSBezierPath(ovalIn: CGRect(x: 330, y: 150, width: 760, height: 120))
    rgba(0, 0, 0, 0.5).setFill()
    shadow.fill()
    ctx.restoreGState()

    // Reflection (flipped, faded)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: 260)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(shotCG, in: CGRect(x: 260, y: 0, width: 880, height: 560))
    let fade = NSGradient(colors: [rgba(0.03, 0.06, 0.14, 0.0), rgba(0.03, 0.06, 0.14, 0.85)])!
    fade.draw(in: CGRect(x: 0, y: 0, width: finalW, height: 560), angle: 90)
    ctx.restoreGState()

    // Main tilted window
    ctx.saveGState()
    var t = CGAffineTransform.identity
    t = t.translatedBy(x: 700, y: 500)
    // Squash vertically + shear horizontally for a subtle 3D lean
    t = t.scaledBy(x: 0.82, y: 0.70)
    t = t.shear(x: 0.0, y: 0.0) // no-op placeholder
    t = t.translatedBy(x: -590, y: -390)
    ctx.concatenate(t)
    ctx.draw(shotCG, in: CGRect(x: 0, y: 0, width: shotW, height: shotH))
    ctx.restoreGState()

    // Top depth edge + highlight
    ctx.saveGState()
    let edge = NSBezierPath()
    edge.move(to: CGPoint(x: 700 - 590 * 0.82, y: 500 + 390 * 0.70 + 4))
    edge.line(to: CGPoint(x: 700 + 590 * 0.82, y: 500 + 390 * 0.70 + 4))
    edge.line(to: CGPoint(x: 700 + 590 * 0.82, y: 500 + 390 * 0.70 + 12))
    edge.line(to: CGPoint(x: 700 - 590 * 0.82, y: 500 + 390 * 0.70 + 12))
    edge.close()
    rgba(0.30, 0.85, 1.0, 0.5).setFill()
    edge.fill()
    ctx.restoreGState()

    // Caption
    text("Mac Gaming Helper", size: 26, weight: .bold, color: .white, in: CGRect(x: 0, y: 60, width: finalW, height: 40), align: .center)
    text("Controller desk · Pad Check · Wireless readiness · Performance Bar", size: 15, weight: .regular, color: mute, in: CGRect(x: 0, y: 34, width: finalW, height: 24), align: .center)
}

extension CGAffineTransform {
    func shear(x: CGFloat, y: CGFloat) -> CGAffineTransform {
        return self.concatenating(CGAffineTransform(a: 1, b: y, c: x, d: 1, tx: 0, ty: 0))
    }
}

writePNG(final, name: "app-3d.png")
