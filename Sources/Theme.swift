import SwiftUI

enum Theme {
    static let name = "Mac Gaming Helper"
    static let version = "2.1.0"
    static let accent = Color(red: 0.18, green: 0.55, blue: 0.95)
    static let ds4Blue = Color(red: 0.00, green: 0.45, blue: 0.85)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let mute = Color.secondary
    static let good = Color(red: 0.20, green: 0.75, blue: 0.40)
    static let warn = Color(red: 0.95, green: 0.70, blue: 0.20)
    static let bad = Color(red: 0.90, green: 0.30, blue: 0.30)

    /// Relates this app to the earlier Game Bay project.
    static let relationNote = """
    Successor to Game Bay (~/Projects/game-bay). Game Bay remains installed and unchanged. \
    Mac Gaming Helper keeps the launcher hub and adds a DualShock 4–first controller desk \
    with live readouts, multi-pad selection, light-bar tint, and optional keyboard/mouse mapping.
    """
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PillButton: View {
    let title: String
    var primary: Bool = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    primary ? Theme.accent : Color(nsColor: .separatorColor).opacity(0.35),
                    in: Capsule()
                )
                .foregroundStyle(primary ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
