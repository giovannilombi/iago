import Foundation
import IAGOStore
import Observation
import Sparkle
import os

/// Updates from GitHub Releases through Sparkle (ADR-0056): a check once a day, signed with EdDSA. The user decides the
/// kind of every release (ADR-0100), written in the feed by `scripts/release.sh`:
/// - optional: install, later, skip;
/// - no-skip: critical for Sparkle, which then offers no "skip", plus `<iago:update>no-skip</iago:update>`, so IAGO
///   blocks nothing;
/// - mandatory: critical; after `graceDays` from when IAGO first saw it, IAGO starts no new recording, transcription,
///   summary or proposal until it is installed. A recording going on is never interrupted; the archive stays readable.
@MainActor
@Observable
final class UpdateService: NSObject, SPUUpdaterDelegate {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    private let archive: Archive
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "update")
    /// A mandatory update is waiting: its version.
    private(set) var mandatoryVersion: String? {
        didSet { if let mandatoryVersion { noteFirstSeen(mandatoryVersion) } }
    }
    /// Days of margin to install a mandatory update.
    static let graceDays = 2
    static let firstSeenKey = "update.mandatoryFirstSeen"
    /// The newest version found, if newer than this one.
    private(set) var availableVersion: String?
    private(set) var lastCheck: Date?

    init(archive: Archive) {
        self.archive = archive
        super.init()
        // A copy built from source (developers) is updated with git: Sparkle would replace it with the published
        // build, signed by someone else, and macOS would ask for every permission again (ADR-0059, amended).
        guard Self.isDistributed else {
            logger.notice("Built from source: no update checks")
            return
        }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    /// The build published with `scripts/release.sh` (installed from the DMG).
    static var isDistributed: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "IAGODistribution") as? String) == "YES"
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var automaticChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// When the margin of the mandatory update ends.
    var mandatoryDeadline: Date? {
        guard let mandatoryVersion,
            let seen = (UserDefaults.standard.dictionary(forKey: Self.firstSeenKey)?[mandatoryVersion] as? Date)
        else { return nil }
        return Calendar.current.date(byAdding: .day, value: Self.graceDays, to: seen)
    }

    /// The margin is over: no new recordings or jobs until the update is installed.
    var mandatoryOverdue: Bool { mandatoryDeadline.map { Date() >= $0 } ?? false }

    private func noteFirstSeen(_ version: String) {
        var seen = UserDefaults.standard.dictionary(forKey: Self.firstSeenKey) ?? [:]
        guard seen[version] == nil else { return }
        seen[version] = Date()
        UserDefaults.standard.set(seen, forKey: Self.firstSeenKey)
    }

    /// "Controlla aggiornamenti…": Sparkle's own window, also when there is nothing new.
    func checkNow() { controller?.checkForUpdates(nil) }

    // MARK: SPUUpdaterDelegate

    nonisolated func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        Task { @MainActor in
            lastCheck = Date()
            try? archive.audit(.update, action: "check", detail: "\(appcast.items.count) versions")
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let mandatory = Self.isMandatory(
            critical: item.isCriticalUpdate, kind: item.propertiesDictionary[Self.kindElement] as? String)
        Task { @MainActor in
            availableVersion = version
            mandatoryVersion = mandatory ? version : nil
            logger.notice("Update \(version, privacy: .public) found, mandatory: \(mandatory)")
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            availableVersion = nil
            mandatoryVersion = nil
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in try? archive.audit(.update, action: "install", detail: version) }
    }

    /// The feed element that says the kind of a critical update (ADR-0100).
    nonisolated static let kindElement = "iago:update"

    /// Critical without `no-skip`: mandatory. Critical with `no-skip`: only without "skip". The version number alone
    /// never makes an update mandatory (ADR-0100): the user decides it for every release.
    nonisolated static func isMandatory(critical: Bool, kind: String?) -> Bool {
        critical && kind?.trimmingCharacters(in: .whitespacesAndNewlines) != "no-skip"
    }
}
