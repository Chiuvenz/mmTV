import SwiftUI
import Contracts

public enum TVTheme {
    public static let background = Color(red: 0.035, green: 0.052, blue: 0.076)
    public static let panel = Color(red: 0.075, green: 0.096, blue: 0.125)
    public static let ink = Color(red: 0.94, green: 0.94, blue: 0.91)
    public static let muted = Color(red: 0.57, green: 0.64, blue: 0.70)
    public static let mint = Color(red: 0.67, green: 0.87, blue: 0.75)
    public static let amber = Color(red: 0.94, green: 0.74, blue: 0.43)
    public static let video = Color(red: 0.55, green: 0.73, blue: 0.92)
    public static let music = Color(red: 0.92, green: 0.57, blue: 0.60)
    public static let photos = Color(red: 0.76, green: 0.67, blue: 0.92)

    public static func accent(for module: ModuleID) -> Color {
        switch module {
        case .games: amber
        case .video: video
        case .music: music
        case .photos: photos
        default: mint
        }
    }
}

public extension View {
    func remoteSelected(_ selected: Bool) -> some View {
        padding(5)
            .background(
                selected ? TVTheme.mint.opacity(0.16) : .clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? TVTheme.mint : .clear, lineWidth: 2)
            }
    }
}

public struct TVCard<Content: View>: View {
    private let selected: Bool
    private let action: () -> Void
    private let content: Content
    public init(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.selected = selected; self.action = action; self.content = content()
    }
    public var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(selected ? TVTheme.mint.opacity(0.12) : TVTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? TVTheme.mint : .white.opacity(0.06), lineWidth: selected ? 2.5 : 1))
                .shadow(color: selected ? TVTheme.mint.opacity(0.08) : .clear, radius: 24)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .scaleEffect(selected ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

public struct StatusPill: View {
    public let title: String
    public let ready: Bool
    public init(_ title: String, ready: Bool = false) { self.title = title; self.ready = ready }
    public var body: some View {
        Text(title).font(.system(size: 11, weight: .medium))
            .foregroundStyle(ready ? TVTheme.mint : TVTheme.muted)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background((ready ? TVTheme.mint : TVTheme.muted).opacity(0.09), in: Capsule())
    }
}
