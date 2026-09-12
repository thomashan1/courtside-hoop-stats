import SwiftUI
import UIKit

/// Date + time picker whose minutes step in 5s.
///
/// SwiftUI's `DatePicker` has no minute-interval option, so this wraps
/// `UIDatePicker` — the same control SwiftUI itself uses — purely to set
/// `minuteInterval`. Spinning through sixty positions to land on one of a
/// dozen useful values is wasted effort at the gym door.
///
/// **Five, not ten.** This stepped in 10s on the theory that games tip off on
/// the hour or the half hour. They don't: a real fixture list had a 2:45
/// start, which 10s can't reach at all — the picker rounded it away to 2:40.
/// Five is a strict superset of ten, so nothing that used to be reachable
/// stopped being, and it also covers a tournament running 2:45 / 2:55 / 3:05.
/// One is the iOS default and brings back the spinning this exists to avoid,
/// to buy times like 2:47 that no league schedules.
struct GameDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var minuteInterval: Int = 5

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = minuteInterval
        picker.addTarget(context.coordinator,
                         action: #selector(Coordinator.changed(_:)),
                         for: .valueChanged)
        // Hug the trailing edge like a stock Form row rather than stretching.
        picker.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        picker.setContentCompressionResistancePriority(.required, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        // UIDatePicker silently rounds a date that doesn't sit on the interval,
        // which would leave the binding and the wheel disagreeing. Round first
        // so both start from the same value.
        let rounded = Self.rounded(selection, toMinuteInterval: minuteInterval)
        if picker.date != rounded { picker.date = rounded }
        if selection != rounded { DispatchQueue.main.async { selection = rounded } }
    }

    /// Without this SwiftUI hands the picker whatever the `Form` row proposes and
    /// the compact pills render clipped. Answer with the control's own compressed
    /// size so the row grows to fit it instead.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView picker: UIDatePicker,
                      context: Context) -> CGSize? {
        picker.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    }

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    final class Coordinator: NSObject {
        var selection: Binding<Date>
        init(selection: Binding<Date>) { self.selection = selection }

        @objc func changed(_ sender: UIDatePicker) {
            selection.wrappedValue = sender.date
        }
    }

    /// Nearest multiple of `interval` minutes, seconds discarded.
    static func rounded(_ date: Date, toMinuteInterval interval: Int) -> Date {
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = parts.minute else { return date }
        parts.minute = Int((Double(minute) / Double(interval)).rounded()) * interval
        parts.second = 0
        return calendar.date(from: parts) ?? date
    }
}
