import Foundation
import IAGOStore
import Observation
import Sparkle
import os

/// Updates from GitHub Releases through Sparkle (ADR-0056): a check once a day, signed with EdDSA. Minor versions are
/// offered (install, later, skip); a new major version is mandatory: it is marked critical in the feed, Sparkle offers
/// no "skip", and IAGO starts no new recording until it is installed. A recording going on is never interrupted.
@MainActor
@Observable
final class UpdateService: NSObject, SPUUpdaterDelegate {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    private let archive: Archive
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "update")
    /// A mandatory update is waiting: its version.
    private(set) var mandatoryVersion: String?
    /// The newest version found, if newer than this one.
    private(set) var availableVersion: String?
    private(set) var lastCheck: Date?

    init(archive: Archive) {
        self.archive = archive
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var automaticChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
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
        let critical = item.isCriticalUpdate || Self.isMajor(version, over: Self.currentVersionNonisolated)
        Task { @MainActor in
            availableVersion = version
            if critical { mandatoryVersion = version }
            logger.notice("Update \(version, privacy: .public) found, mandatory: \(critical)")
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

    nonisolated static var currentVersionNonisolated: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// 2.0.0 over 1.4.3: a new major version, mandatory.
    nonisolated static func isMajor(_ new: String, over current: String) -> Bool {
        let a = Int(new.split(separator: ".").first ?? "") ?? 0
        let b = Int(current.split(separator: ".").first ?? "") ?? 0
        return a > b
    }
}
