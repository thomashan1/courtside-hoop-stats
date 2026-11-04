import SwiftUI
import AppIntents

/// Settings ▸ Siri & Shortcuts (#255): what you can ask, word for word.
/// Siri only answers these with the app's name in them, so the page says so
/// rather than letting a bare "What was the score?" fail with no clue why.
struct SiriHelpView: View {
    @EnvironmentObject var store: AppStore

    private var teamName: String { store.team.name }

    var body: some View {
        List {
            Section {
                phrase("Last game score in Courtside")
                phrase("How did \(teamName) do in Courtside?")
            } header: {
                Text("Last Game Score")
            } footer: {
                Text("The final score of the most recent finished game.")
            }

            Section {
                phrase("What's our record in Courtside?")
                phrase("Courtside record")
            } header: {
                Text("Team Record")
            } footer: {
                Text("Wins and losses across every finished game.")
            }

            Section {
                // Not `ShortcutsLink`: it names the app by its bundle name,
                // "CourtsideHoopStats".
                Link(destination: URL(string: "shortcuts://")!) {
                    Label("Open Shortcuts", systemImage: "square.stack.3d.up")
                }
            } footer: {
                Text("Say \u{201C}Courtside\u{201D} in each question. Without a team's name, Siri answers for the team you have open. Each team also has its own shortcut in the Shortcuts app.")
            }
        }
        .readableWidth()
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func phrase(_ text: String) -> some View {
        Label("\u{201C}\(text)\u{201D}", systemImage: "mic")
    }
}

/// Apple's own "Try saying…" tip, above Final Scores once there's a final
/// score to ask about. Closing it hides it for good.
struct SiriTipRow: View {
    @AppStorage("chs.siriTipDismissed") private var dismissed = false

    /// The screenshot harness keeps its captures unchanged unless it asks.
    private var suppressed: Bool {
        let args = ProcessInfo.processInfo.arguments
        return (args.contains("-uiTestSeedDemo") || args.contains("-uiTestFreshInstall"))
            && !args.contains("-uiTestShowSiriTip")
    }

    var body: some View {
        if !dismissed && !suppressed {
            Section {
                SiriTipView(intent: LastGameScoreIntent(), isVisible: Binding(
                    get: { !dismissed }, set: { dismissed = !$0 }))
                    .siriTipViewStyle(.automatic)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }
}
