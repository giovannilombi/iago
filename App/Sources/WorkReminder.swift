import Foundation
import IAGOStore
import UserNotifications
import os

/// «Notifica del mattino» (ADR-0074): on workdays, at the chosen time, one local notification with what is due today,
/// late, and the waits past their date. A click opens «Da fare». Computed on the Mac when it is time, no network. Off
/// by default in «Traccia», on in «Gestisci», unless the user chose.
@MainActor
final class WorkReminder {
    static let enabledKey = "work.morning"
    static let timeKey = "work.morning.time"
    /// The day the last notification was posted (yyyy-MM-dd), so it comes once a day.
    static let lastKey = "work.morning.last"
    static let category = "iago.morning"
    static let defaultTime = (hour: 8, minute: 30)

    private let archive: Archive
    private var loop: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "work")

    init(archive: Archive) {
        self.archive = archive
    }

    /// Off until the user turns it on (Impostazioni › Generale).
    static func isEnabled(_ archive: Archive) -> Bool {
        ((try? archive.setting(enabledKey)) ?? nil) == "1"
    }

    static func time(_ archive: Archive) -> (hour: Int, minute: Int) {
        guard let value = (try? archive.setting(timeKey)) ?? nil else { return defaultTime }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return defaultTime }
        return (parts[0], parts[1])
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.check()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// Posts today's notification once the time has come (also later in the day, after a sleep).
    func check(now: Date = Date()) {
        let calendar = Calendar.current
        guard Self.isEnabled(archive), !calendar.isDateInWeekend(now) else { return }
        let time = Self.time(archive)
        // Up to four hours late (the Mac was asleep), never in the evening for a morning that went by.
        guard let due = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now), now >= due,
            now < due.addingTimeInterval(4 * 3600)
        else { return }
        // The local day, not UTC: a reminder just after midnight belongs to today.
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let today = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        guard ((try? archive.setting(Self.lastKey)) ?? nil) != today else { return }
        try? archive.setSetting(Self.lastKey, today)
        guard let body = Self.message(archive, now: now) else { return }
        post(body)
    }

    /// «3 in scadenza oggi, 2 in ritardo, 1 attesa scaduta»; nil when there is nothing to say.
    static func message(_ archive: Archive, now: Date = Date()) -> String? {
        let open =
            (try? archive.decisions(
                DecisionQuery(scope: .all, statuses: DecisionQuery.current, kinds: Set(Decision.Kind.work)))) ?? []
        let label = ((try? archive.setting(TranscriptionService.meLabelKey)) ?? nil) ?? "Io"
        let names = Set([TagNormalizer.normalize(label), TagNormalizer.normalize("Io")])
        let me = Set(((try? archive.people()) ?? []).filter { names.contains($0.normalized) }.map(\.id))
        let counts = OpenWork.counts(open.map(\.decision), me: me, now: now)
        guard !counts.isEmpty else { return nil }
        var parts: [String] = []
        if counts.today > 0 { parts.append(String(localized: "\(counts.today) in scadenza oggi")) }
        if counts.overdue > 0 { parts.append(String(localized: "\(counts.overdue) in ritardo")) }
        if counts.waitingLate > 0 {
            parts.append(
                counts.waitingLate == 1
                    ? String(localized: "1 attesa scaduta") : String(localized: "\(counts.waitingLate) attese scadute"))
        }
        return parts.joined(separator: ", ")
    }

    private func post(_ body: String) {
        let logger = self.logger
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized, settings.alertSetting == .enabled else {
                logger.notice("Morning notification not shown: notifications are off")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Da fare oggi")
            content.body = body
            content.categoryIdentifier = Self.category
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
