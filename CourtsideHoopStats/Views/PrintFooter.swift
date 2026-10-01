import SwiftUI

/// The furniture at the foot of every exported page: wordmark, the tappable
/// App Store line, and either the page number or the date it was made — with
/// the app version alongside.
///
/// One view, because there are now three kinds of page (box score, score log,
/// season) and the footer had already been copied once. A printed page travels
/// on its own — forwarded, saved, quoted back weeks later — so a page that
/// can't say what made it or where to get the app is a dead end.
///
/// The App Store line is drawn as **ordinary text**: `ImageRenderer` emits
/// glyphs rather than annotations, so the real hyperlink is attached over this
/// area after rendering (`GameSummaryPDF.addAppStoreLink`).
struct PrintFooter: View {
    /// Shown on the right. A multi-page document numbers its pages; a
    /// single-page one says when it was made instead, which is more use on a
    /// sheet someone finds in a folder months later.
    enum Trailing {
        case page(number: Int, of: Int)
        case madeOn(Date)
    }

    var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Courtside Hoop Stats")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Get the app on the App Store ↗")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.teamAccent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                switch trailing {
                case let .page(number, total):
                    Text("Page \(number) of \(total)")
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                case let .madeOn(date):
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                // Which build produced this sheet. When someone reports a
                // number looking wrong weeks later, this is the only way to
                // know what was actually running.
                Text("v\(BuildInfo.version) (\(BuildInfo.build))")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }
}
