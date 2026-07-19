import SwiftUI
import MapKit

/// Location/Gym field with two tiers of suggestions (issue #13):
///
/// 1. **Prior values** you've already used (from `store.knownLocations`), shown
///    with a history icon — the existing behavior.
/// 2. **Live place search** via MapKit `MKLocalSearchCompleter` — real gyms,
///    schools, and addresses as you type, shown with a map-pin icon.
///
/// This first pass intentionally does **not** request location permission, so
/// results aren't biased to the user's region yet. Adding `CLLocationManager` +
/// `NSLocationWhenInUseUsageDescription` later would narrow results (via the
/// completer's `region`) without changing this view's shape.
struct LocationField: View {
    let title: String
    @Binding var text: String
    /// The picked place's street address, shown as a smaller-font FYI under the
    /// field once a MapKit suggestion is chosen. Cleared when the field is emptied.
    @Binding var address: String
    let priorValues: [String]

    @FocusState private var focused: Bool
    @StateObject private var search = LocationSearchModel()

    /// Previously-used values matching what's typed (excluding an exact match).
    private var priorMatches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return priorValues.filter { value in
            value.caseInsensitiveCompare(query) != .orderedSame
                && (query.isEmpty || value.localizedCaseInsensitiveContains(query))
        }
        .prefix(4)
        .map { $0 }
    }

    var body: some View {
        Group {
            TextField(title, text: $text)
                .focused($focused)
                .textInputAutocapitalization(.words)
                .onChange(of: text) { _, newValue in
                    search.update(query: newValue)
                    if newValue.isEmpty { address = "" }
                }

            // FYI address of the picked place (not while actively choosing).
            if !focused, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if focused {
                ForEach(priorMatches, id: \.self) { value in
                    suggestionButton(value, systemImage: "clock.arrow.circlepath", detail: nil)
                }
                ForEach(search.results) { result in
                    suggestionButton(result.title,
                                     systemImage: "mappin.and.ellipse",
                                     detail: result.subtitle.isEmpty ? nil : result.subtitle)
                }
            }
        }
    }

    private func suggestionButton(_ value: String, systemImage: String, detail: String?) -> some View {
        Button {
            text = value
            address = detail ?? ""   // keep the address as FYI (empty for prior values)
            focused = false
            search.clear()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value).foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

/// A single place suggestion, flattened to `Sendable` value types so results can
/// cross from the completer delegate to the main actor cleanly.
struct LocationSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
}

/// Wraps `MKLocalSearchCompleter` for SwiftUI: debounced query updates and
/// published results delivered via the completer's delegate (which MapKit calls
/// on the main thread).
@MainActor
final class LocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [LocationSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var debounce: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        // Gyms, schools, and arenas (points of interest) plus street addresses.
        completer.resultTypes = [.pointOfInterest, .address]
    }

    /// Debounced query update — avoids a search request on every keystroke, and
    /// skips very short fragments that would only return noise.
    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        debounce?.cancel()
        guard trimmed.count >= 3 else {
            results = []
            return
        }
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.completer.queryFragment = trimmed
        }
    }

    func clear() {
        debounce?.cancel()
        results = []
        completer.queryFragment = ""
    }

    // MARK: MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Flatten to Sendable values on the (main-thread) delegate callback,
        // then publish on the main actor.
        let items = completer.results.prefix(5).map {
            LocationSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor [weak self] in
            self?.results = items
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.results = []
        }
    }
}
