import IAGOStore

/// Italian names of key points and their states (ADR-0046), shared by exports, the MCP server and the app.
public enum KeyPointLabels {
    public static func kind(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: "Decisione"
        case .action: "Attività"
        case .milestone: "Tappa"
        case .openQuestion: "Domanda aperta"
        }
    }

    public static func status(_ decision: Decision) -> String {
        switch (decision.kind, decision.status) {
        case (_, .superseded): "Superata"
        case (_, .cancelled): "Annullata"
        case (.action, .done): "Fatta"
        case (.action, .active): "Aperta"
        case (.milestone, _): "Raggiunta"
        case (_, .done): "Fatta"
        case (_, .active): "Attiva"
        }
    }

    /// "Attiva" for decisions (as always), "Attività · Aperta", "Tappa".
    public static func tag(_ decision: Decision) -> String {
        switch decision.kind {
        case .decision: status(decision)
        case .milestone: decision.status == .active ? "Tappa" : "Tappa · \(status(decision))"
        default: "\(kind(decision.kind)) · \(status(decision))"
        }
    }
}
