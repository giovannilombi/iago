import Foundation
import IAGOCore
import IAGOStore

/// Renders an item as Markdown or plain text (spec 11.1; "Addendum" with the notes, 11.3). Both are
/// regenerated from `transcript.json` and the database, never edited.
public enum TranscriptRenderer {
    public static func markdown(_ document: ItemDocument, timeZone: TimeZone = .current) -> String {
        let item = document.item
        var lines = [
            "---", "iago_id: \(item.id)", "title: \(yaml(item.title))",
            "date: \(format(item.occurredAt, "yyyy-MM-dd'T'HH:mm", timeZone))",
        ]
        if let duration = item.durationSec { lines.append("duration: \(clock(duration))") }
        if let project = document.projectName { lines.append("project: \(yaml(project))") }
        if let category = document.categoryName { lines.append("category: \(yaml(category))") }
        lines.append("tags: [\(document.tags.map(yaml).joined(separator: ", "))]")
        if document.transcript != nil {
            lines.append("participants: [\(document.participants.map(yaml).joined(separator: ", "))]")
        }
        if let engine = document.transcript?.engine { lines.append("engine: \(yaml("\(engine.asr) \(engine.model)"))") }
        lines += ["---", "", "# \(item.title)", "", summary(document, timeZone: timeZone, bold: true), ""]
        if let text = document.summary {
            lines += ["## Sintesi", "", ItemDocument.plainSummary(text, headingLevel: 3), ""]
        }
        lines += ["## Trascrizione", ""]
        if let transcript = document.transcript {
            lines += transcript.segments.map {
                "**[\(clock($0.start))] \(document.label(for: $0.speaker)):** \($0.text)"
            }
        } else {
            lines.append(String(localized: "_(solo audio, non trascritta)_"))
        }
        if !document.notes.isEmpty {
            lines += ["", "## Addendum"]
            for note in document.notes {
                lines += [
                    "", "### \(format(note.notedAt, "yyyy-MM-dd HH:mm", timeZone)) · \(kindLabel(note.kind))", "",
                    note.body,
                ]
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// TXT: same content without Markdown, one line per segment `[hh:mm:ss] Speaker: testo` (spec 11.1).
    public static func text(_ document: ItemDocument, timeZone: TimeZone = .current) -> String {
        var lines = [document.item.title, summary(document, timeZone: timeZone, bold: false)]
        if !document.tags.isEmpty { lines.append("Tag: \(document.tags.joined(separator: ", "))") }
        lines.append("")
        if let transcript = document.transcript {
            lines += transcript.segments.map { "[\(clock($0.start))] \(document.label(for: $0.speaker)): \($0.text)" }
        } else {
            lines.append(String(localized: "(solo audio, non trascritta)"))
        }
        if !document.notes.isEmpty {
            lines += ["", "Addendum"]
            for note in document.notes {
                lines += [
                    "", "\(format(note.notedAt, "yyyy-MM-dd HH:mm", timeZone)) · \(kindLabel(note.kind))", note.body,
                ]
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func summary(_ document: ItemDocument, timeZone: TimeZone, bold: Bool) -> String {
        func field(_ name: String, _ value: String) -> String { bold ? "**\(name):** \(value)" : "\(name): \(value)" }
        var parts = [field(String(localized: "Data"), format(document.item.occurredAt, "dd/MM/yyyy HH:mm", timeZone))]
        if let duration = document.item.durationSec {
            parts.append(field(String(localized: "Durata"), minutes(duration)))
        }
        if let project = document.projectName { parts.append(field(String(localized: "Progetto"), project)) }
        if let category = document.categoryName { parts.append(field(String(localized: "Categoria"), category)) }
        return parts.joined(separator: " · ")
    }

    public static func kindLabel(_ kind: Note.Kind) -> String {
        switch kind {
        case .note: String(localized: "Nota")
        case .email: String(localized: "Email")
        case .lateDecision: String(localized: "Decisione successiva")
        case .update: String(localized: "Aggiornamento")
        }
    }

    /// `hh:mm:ss`.
    public static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    public static func minutes(_ seconds: Double) -> String {
        seconds < 60 ? "\(Int(seconds.rounded())) s" : "\(Int((seconds / 60).rounded())) min"
    }

    public static func format(_ date: Date, _ pattern: String, _ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// Double-quoted YAML scalar: titles may contain `:` or `#`.
    public static func yaml(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
