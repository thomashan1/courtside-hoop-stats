import SwiftUI

// MARK: - iPad width (#232)

extension View {
    /// Keeps a list, form or scroll view's rows to a readable width on iPad.
    ///
    /// An inset-grouped list stretched across a 13" iPad puts an opponent's
    /// name a foot from its score. This widens the side margins instead of
    /// framing the view, so the scroll area, the background and the swipe
    /// actions still run edge to edge — only the rows move in.
    ///
    /// Inert in a compact width: every iPhone, and an iPad app in a narrow
    /// Split View or Slide Over, lays out exactly as it did before.
    func readableWidth(_ maxWidth: CGFloat = ReadableWidth.list) -> some View {
        modifier(ReadableWidthModifier(maxWidth: maxWidth))
    }
}

enum ReadableWidth {
    /// Lists of games, players, teams and settings.
    static let list: CGFloat = 720
    /// A box score: wide enough for every stats column without scrolling.
    static let boxScore: CGFloat = 900
}

private struct ReadableWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0

    /// `nil` is the system's own margin — what every compact width gets, so
    /// an iPhone is untouched.
    private var margin: CGFloat? {
        guard sizeClass == .regular, width > maxWidth + 40 else { return nil }
        return (width - maxWidth) / 2
    }

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }
}
