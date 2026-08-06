import SwiftUI
import UIKit

/// Date + time picker whose minutes step in 10s.
///
/// SwiftUI's `DatePicker` has no minute-interval option, so this wraps
/// `UIDatePicker` — the same control SwiftUI itself uses — purely to set
/// `minuteInterval`. Games tip off on the hour or the half hour; spinning past
/// sixty minutes to land on one of six useful values is wasted effort at the
/// gym door.
struct GameDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var minuteInterval: Int = 10

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
