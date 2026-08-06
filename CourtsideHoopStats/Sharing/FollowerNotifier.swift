import Foundation
import UserNotifications

/// Posts the alerts `FollowerAlertBuilder` decides on (#57).
///
/// CloudKit's own pushes can't carry our content — they only say "something in
/// the shared database changed". So the app is woken silently, fetches, works
/// out what actually happened, and posts a **local** notification with a real
/// score in it. That round trip is why the wording lives in the app rather than
/// in the push payload.
@MainActor
final class FollowerNotifier {
    static let shared = FollowerNotifier()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Ask once, and only when it means something — a follower who has just
    /// accepted a share understands why the app wants to notify them, which is
    /// not true of a permission prompt on first launch.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    var isAuthorized: Bool {
        get async {
            let status = await center.notificationSettings().authorizationStatus
            return status == .authorized || status == .provisional
        }
    }

    func post(_ alerts: [FollowerAlert]) async {
        guard !alerts.isEmpty, await isAuthorized else { return }

        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default

            // Identified by the event rather than a fresh UUID, so a repeated
            // fetch replaces its own notification instead of stacking a second
            // copy of the same period end.
            let request = UNNotificationRequest(identifier: alert.id,
                                                content: content,
                                                trigger: nil)
            try? await center.add(request)
        }
    }
}
