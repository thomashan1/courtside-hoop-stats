import SwiftUI

// The scoreboard's fixed colours, in `CourtsideShared/` because both the app's
// scoreboard banner and the Live Activity (#260) draw with them. The rest of
// the palette is in the app's `DesignSystem.swift`.

extension Color {
    /// Fixed deep navy (#0C2C5E) used *only* for the scoreboard banner — an
    /// intentionally-dark, always-high-contrast element — and the Live
    /// Activity, which is the same banner on the Lock Screen.
    static let scoreboardBackground = Color(red: 0.047, green: 0.173, blue: 0.369)
    /// The bright blue (#5B9CF5) used on the always-dark scoreboard, regardless
    /// of the system appearance. Not `teamAccent`'s light-mode #1E5FCF: on
    /// navy that's 2.3:1, against 4.9:1 for this.
    static let scoreboardAccent = Color(red: 0.357, green: 0.612, blue: 0.961)
}
