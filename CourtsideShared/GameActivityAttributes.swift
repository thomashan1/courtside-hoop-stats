import ActivityKit
import Foundation

/// The game being scored, as a Live Activity on the Lock Screen and in the
/// Dynamic Island (#260).
///
/// Compiled into **both** the app and the `CourtsideLiveActivity` extension
/// (it's in `CourtsideShared/`): the app starts, updates and ends the
/// activity, the extension draws it, and ActivityKit carries `ContentState`
/// from one to the other.
///
/// Nothing here is ever saved — not to UserDefaults, the iCloud backup or the
/// follower wire — so none of `Game`'s backward-compatibility rules apply. It
/// lives exactly as long as the activity does, and the app and extension that
/// read it always come from the same build.
struct GameActivityAttributes: ActivityAttributes {
    /// Which game this is. The app finds an activity again by this, rather
    /// than storing an activity ID on `Game` (which would be a schema change).
    var gameID: UUID

    /// What the activity shows: what Live Scoring's scoreboard shows, no more
    /// current. Built from a `Game` by `init(game:team:)` in the app.
    struct ContentState: Codable, Hashable {
        var ourName: String
        var opponentName: String
        var ourScore: Int
        /// The opponent's total **as of the last period break** — it's typed
        /// at End Period, so between breaks it's behind. See `opponentThrough`.
        var opponentScore: Int
        /// The period being played — `Q3`, `H2`, `OT`, `2OT` — or nil for a
        /// pickup game, which has none. On a finished game, the overtime it
        /// ended in (`OT`), or nil if it ended in regulation.
        var periodLabel: String?
        /// The break the opponent's total was last entered at (`Q2`), while
        /// the game is live — so the Lock Screen can say the number is that
        /// old. Nil before the first break and once the game is over.
        var opponentThrough: String?
        /// The latest made basket, `Jake +3`, in Live Scoring's first-name
        /// style. Shown only in the expanded Dynamic Island, never on the Lock
        /// Screen, which anyone near the phone can read.
        var lastBasket: String?
        /// Set once the game is over.
        var outcome: Outcome?

        var isFinal: Bool { outcome != nil }

        /// `Q3` while live; `Final` or `Final/OT` once it's over; empty for a
        /// pickup game in progress.
        var status: String {
            guard isFinal else { return periodLabel ?? "" }
            return periodLabel.map { "Final/\($0)" } ?? "Final"
        }
    }

    enum Outcome: String, Codable, Hashable {
        case win, loss, tie

        var letter: String {
            switch self {
            case .win:  return "W"
            case .loss: return "L"
            case .tie:  return "T"
            }
        }
    }
}

/// The URL a tap on the Live Activity opens: that game, in the app.
///
/// `courtsidehoopstats://game/<id>`. The scheme is registered in the app's
/// Info.plist so the link also works from `simctl openurl` and a UI test, not
/// only from the activity itself.
enum GameLink {
    static let scheme = "courtsidehoopstats"

    static func url(for gameID: UUID) -> URL {
        URL(string: "\(scheme)://game/\(gameID.uuidString)")!
    }

    /// The game a link names, or nil for anything else.
    static func gameID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == "game" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
