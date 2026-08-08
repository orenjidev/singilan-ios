import SwiftUI

enum SingilanTheme {
    static let green = Color(red: 22 / 255, green: 134 / 255, blue: 79 / 255)
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 17 / 255, green: 23 / 255, blue: 20 / 255, alpha: 1)
            : UIColor(red: 246 / 255, green: 248 / 255, blue: 246 / 255, alpha: 1)
    })
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let border = Color.primary.opacity(0.09)
    static let muted = Color.secondary
}

struct SingilanCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(SingilanTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SingilanTheme.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 7, y: 3)
    }
}

struct SingilanSectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct ParticipantAvatar: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let value = parts.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "?" : value.uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.31, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(SingilanTheme.green, in: Circle())
    }
}

struct SingilanDivider: View {
    var body: some View { Divider().padding(.leading, 14) }
}

extension View {
    func singilanCanvas() -> some View {
        background(SingilanTheme.canvas.ignoresSafeArea()).tint(SingilanTheme.green)
    }

    func singilanField() -> some View {
        padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(SingilanTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SingilanTheme.border, lineWidth: 1)
            }
    }
}
