import Foundation

/// The language of what IAGO writes for the user (ADR-0077): summaries, proposals, status reports, answers. It follows
/// the app's language; the app stores it under `defaultsKey` at launch and when the user changes language. Without it
/// (tests, tools) it is Italian.
public enum ContentLanguage: String, Sendable, CaseIterable {
    case it, en

    public static let defaultsKey = "IAGOContentLanguage"

    public static var current: ContentLanguage {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(ContentLanguage.init(rawValue:)) ?? .it
    }

    /// "in italiano" / "in inglese", for the engine's prompts (written in Italian).
    public var inLanguage: String {
        switch self {
        case .it: "in italiano"
        case .en: "in inglese"
        }
    }

    /// The text for this language.
    public func pick(it: String, en: String) -> String {
        self == .en ? en : it
    }

    public var locale: Locale { Locale(identifier: rawValue) }
}
