import Foundation

/// The rules of the watched folders (ADR-0050): what to leave out and where to put an email, applied in bulk without
/// asking. A pure function, so the same rules give the same result in tests and in the app.
public struct ImportRule: Sendable, Hashable, Codable, Identifiable {
    public enum Action: String, Sendable, Codable { case exclude, assign }
    public enum Field: String, Sendable, Codable, CaseIterable { case from, domain, to, subject }

    public var id: String
    public var action: Action
    public var field: Field
    /// Matched as "contains", case and accents ignored.
    public var pattern: String
    public var projectID: String?
    public var streamID: String?
    public var enabled: Bool

    public init(
        id: String, action: Action, field: Field, pattern: String, projectID: String? = nil, streamID: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.action = action
        self.field = field
        self.pattern = pattern
        self.projectID = projectID
        self.streamID = streamID
        self.enabled = enabled
    }
}

public struct BuiltInExclusions: Sendable, Hashable, Codable {
    public var meetings = true
    public var autoReplies = true
    public var newsletters = false

    public init(meetings: Bool = true, autoReplies: Bool = true, newsletters: Bool = false) {
        self.meetings = meetings
        self.autoReplies = autoReplies
        self.newsletters = newsletters
    }
}

public enum ImportVerdict: Sendable, Equatable {
    /// Left out, with the reason shown in "Scartate".
    case exclude(String)
    /// Into this project (and stream), by a rule of the user.
    case assign(projectID: String, streamID: String?)
    /// No rule: IAGO's own proposal decides, or "Da classificare".
    case none
}

public enum ImportRules {
    static let meetingSubjects = [
        "accettato:", "rifiutato:", "provvisorio:", "annullato:", "invito:", "aggiornato:", "accepted:", "declined:",
        "tentative:", "canceled:", "cancelled:", "invitation:", "updated invitation", "nuova ora proposta:",
    ]
    static let autoReplySubjects = [
        "risposta automatica", "automatic reply", "auto reply", "autoreply", "fuori sede", "out of office",
        "assente dall'ufficio",
    ]

    /// Exclusions first (built-in, then the user's), then the user's assignments in their order.
    public static func evaluate(_ message: EmailMessage, rules: [ImportRule], builtIn: BuiltInExclusions)
        -> ImportVerdict
    {
        let subject = fold(message.subject ?? "")
        if builtIn.meetings, message.isCalendar || meetingSubjects.contains(where: subject.hasPrefix) {
            return .exclude("Invito o risposta a un meeting")
        }
        if builtIn.autoReplies, message.isAutoReply || autoReplySubjects.contains(where: subject.contains) {
            return .exclude("Risposta automatica")
        }
        if builtIn.newsletters, message.isBulk { return .exclude("Newsletter o lista di distribuzione") }
        let active = rules.filter { $0.enabled && !$0.pattern.trimmingCharacters(in: .whitespaces).isEmpty }
        for rule in active where rule.action == .exclude && matches(rule, message) {
            return .exclude("Regola: \(label(rule.field)) contiene «\(rule.pattern)»")
        }
        for rule in active where rule.action == .assign && matches(rule, message) {
            if let projectID = rule.projectID { return .assign(projectID: projectID, streamID: rule.streamID) }
        }
        return .none
    }

    static func matches(_ rule: ImportRule, _ message: EmailMessage) -> Bool {
        let pattern = fold(rule.pattern.trimmingCharacters(in: .whitespaces))
        let values: [String] =
            switch rule.field {
            case .from: [message.from.map { "\($0.name ?? "") \($0.address)" } ?? ""]
            case .domain:
                ([message.from].compactMap { $0 } + message.to + message.cc).map {
                    String($0.address.split(separator: "@").last ?? "")
                }
            case .to: (message.to + message.cc).map { "\($0.name ?? "") \($0.address)" }
            case .subject: [message.subject ?? ""]
            }
        return values.contains { fold($0).contains(pattern) }
    }

    public static func label(_ field: ImportRule.Field) -> String {
        switch field {
        case .from: "mittente"
        case .domain: "dominio"
        case .to: "destinatario"
        case .subject: "oggetto"
        }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
