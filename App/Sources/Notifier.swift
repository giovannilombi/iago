import AppKit
import UserNotifications
import os

/// Local notifications. Permission is requested at the first useful notification (spec 15). When
/// notifications are off, important messages fall back to a window, so the user still sees them.
final class Notifier: Sendable {
    func post(title: String, body: String, fallbackToAlert: Bool = false) {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized, settings.alertSetting == .enabled else {
                Logger(subsystem: "com.giovannilombi.iago", category: "app").notice(
                    "Notifications not shown (disabled)")
                if fallbackToAlert { await Self.alert(title: title, body: body) }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    @MainActor
    private static func alert(title: String, body: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }
}
