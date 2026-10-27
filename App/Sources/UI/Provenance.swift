import IAGOEngine
import IAGOStore
import SwiftUI

/// Who produced a result, said the same way everywhere (ADR-0070). For the local engine the model counts, because a
/// small one gives less; for Claude it is enough to know it was Claude.
enum Provenance {
    /// `Decision.model` of a key point confirmed from one of Claude's proposals.
    static let claude = "claude"

    /// Below this size a model gives fewer and weaker results (trials of ADR-0048 and ADR-0054).
    static let smallBillions: Double = 9

    static func decisionModel(of suggestion: Suggestion) -> String {
        suggestion.origin == .claude ? claude : suggestion.model
    }

    static func engineName(_ id: String) -> String { EngineCatalog.model(id)?.name ?? id }

    static func isSmall(_ id: String) -> Bool { (EngineCatalog.model(id)?.billions ?? smallBillions) < smallBillions }

    /// "Sintetizzata con Qwen 3.5 9B sul Mac" or "Sintetizzata da Claude".
    static func summary(_ summary: ItemSummaryText) -> String? {
        switch summary.origin {
        case .claude: String(localized: "Sintetizzata da Claude")
        case .engine: summary.model.map { String(localized: "Sintetizzata con \(engineName($0)) sul Mac") }
        case .voice: nil
        }
    }

    /// "Proposta da Qwen 3.5 4B", "Consigliata da Claude" or "Riconosciuta dalla voce (somiglianza 82%)".
    static func suggestion(_ suggestion: Suggestion) -> String {
        switch suggestion.origin {
        case .claude: String(localized: "Consigliata da Claude")
        case .engine: String(localized: "Proposta da \(engineName(suggestion.model)) sul Mac")
        case .voice:
            suggestion.content.confidence.map { String(localized: "Riconosciuta dalla voce (somiglianza \($0)%)") }
                ?? String(localized: "Riconosciuta dalla voce")
        }
    }

    /// For a key point confirmed from a proposal: who proposed it.
    static func decision(_ decision: Decision) -> String? {
        guard let model = decision.model else { return nil }
        if model == claude { return String(localized: "Consigliato da Claude, confermato da te") }
        return String(localized: "Proposto da \(engineName(model)) sul Mac, confermato da te")
    }

    /// The hint shown next to a result of a small model.
    static let smallModelHint = String(
        localized: "Modello piccolo: con un modello più grande (Impostazioni › Motore) i risultati sono più completi.")
}

/// One line under a result: who produced it, with the hint for small models.
struct ProvenanceLine: View {
    let text: String
    var model: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: text.contains("Claude") ? "sparkles" : text.contains("voce") ? "waveform" : "cpu")
            Text(text)
            if let model, Provenance.isSmall(model) {
                Text(String(localized: "· modello piccolo")).foregroundStyle(.orange)
                    .help(Provenance.smallModelHint)
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}
