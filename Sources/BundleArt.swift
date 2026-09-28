import AppKit
import SwiftUI

/// Loads PNGs shipped in the app bundle's Resources/ (not an xcassets catalog).
enum BundleArt {
    static func nsImage(_ name: String) -> NSImage? {
        if let img = NSImage(named: name) { return img }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Dev fallback: project Resources next to Sources when running unbundled.
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(name).png")
        return NSImage(contentsOf: dev)
    }

    static func exists(_ name: String) -> Bool {
        nsImage(name) != nil
    }
}

struct BundledImage: View {
    let name: String
    var maxHeight: CGFloat? = nil
    var cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if let img = BundleArt.nsImage(name) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card)
                    .frame(height: maxHeight ?? 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(Theme.mute)
                    )
            }
        }
        .accessibilityLabel(name.replacingOccurrences(of: "-", with: " "))
    }
}

struct HeroPadArt: View {
    let connected: Bool
    var maxHeight: CGFloat = 200

    var body: some View {
        ZStack {
            BundledImage(name: connected ? "hero-pad-lit" : "hero-pad", maxHeight: maxHeight, cornerRadius: 20)
            if connected {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.ds4Blue.opacity(0.45), lineWidth: 2)
                    .frame(maxHeight: maxHeight)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: connected)
        .shadow(color: connected ? Theme.ds4Blue.opacity(0.35) : .clear, radius: connected ? 18 : 0)
    }
}

struct CoachStepArt: View {
    let imageName: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BundledImage(name: imageName, maxHeight: 110, cornerRadius: 14)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mute)
        }
    }
}
