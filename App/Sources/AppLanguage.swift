import AppKit
import IAGOCore
import IAGOStore

/// The app's language (ADR-0077): Italian or English, chosen on first launch and in Impostazioni › Generale. macOS
/// applies it at launch, so a change restarts IAGO. What IAGO writes (summaries, proposals) follows it.
enum AppLanguage: String, CaseIterable, Identifiable {
    case it, en

    var id: String { rawValue }

    /// The language the app is running in.
    static var current: AppLanguage {
        Bundle.main.preferredLocalizations.first.flatMap { AppLanguage(rawValue: String($0.prefix(2))) } ?? .it
    }

    /// Set once the user picked a language (the first-launch step is shown until then).
    static let chosenKey = "IAGOLanguageChosen"

    static var wasChosen: Bool { UserDefaults.standard.bool(forKey: chosenKey) }

    /// The name in its own language, as language pickers show it.
    var name: String {
        switch self {
        case .it: "Italiano"
        case .en: "English"
        }
    }

    /// Saved for the next launch; the engine's language follows at once.
    func choose() {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.set(rawValue, forKey: ContentLanguage.defaultsKey)
        UserDefaults.standard.set(true, forKey: Self.chosenKey)
    }

    /// At launch: the engine writes in the app's language, and the names IAGO gave by itself (starter example,
    /// built-in categories) follow it.
    static func applyAtLaunch(archive: Archive) {
        UserDefaults.standard.set(current.rawValue, forKey: ContentLanguage.defaultsKey)
        try? archive.relabelDefaults(to: current.rawValue)
    }

    /// Opens a new IAGO and quits this one, so the new language applies.
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        let arguments = ProcessInfo.processInfo.arguments.dropFirst()
        configuration.arguments = Array(arguments)
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// The families of categories (ADR-0054) are stored by their Italian name: shown in the app's language.
enum CategoryFamilyName {
    static func display(_ family: String) -> String {
        switch family {
        case "Agile": String(localized: "Agile")
        case "Direzione": String(localized: "Direzione")
        case "Persone": String(localized: "Persone")
        case "Operazioni": String(localized: "Operazioni")
        default: family
        }
    }
}

/// The user's own voice in transcripts when no name is set: «Io» in Italian, "Me" in English. Both always mean the
/// user, whatever the language the transcript was made in.
enum MeLabel {
    static var defaultName: String { AppLanguage.current == .en ? "Me" : "Io" }
    static let aliases = ["Io", "Me"]

    static func isMe(_ name: String) -> Bool {
        aliases.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
}
