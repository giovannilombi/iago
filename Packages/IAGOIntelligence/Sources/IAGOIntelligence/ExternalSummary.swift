import Foundation

/// A summary written outside the local engine, by Claude through MCP (ADR-0071): the same template as the category,
/// the same check of every quote, the same Markdown with the minutes. Only the writer changes.
extension SummaryGenerator {
    /// How far, in seconds, the minute given for a screenshot may be from the real one (Claude reads mm:ss).
    static let screenshotTolerance: Double = 5

    public struct ExternalPoint: Sendable, Equatable {
        public var text: String
        /// The sentence of the text it comes from, word for word.
        public var quote: String?
        /// Values of the section's columns ("Chi", "Entro"…).
        public var fields: [String: String]
        /// A point read on a screenshot of the call: its second, and no quote to check in the transcript.
        public var screenshotAtSec: Double?

        public init(text: String, quote: String? = nil, fields: [String: String] = [:], screenshotAtSec: Double? = nil)
        {
            self.text = text
            self.quote = quote
            self.fields = fields
            self.screenshotAtSec = screenshotAtSec
        }
    }

    /// Points with a quote IAGO finds keep the minute of the quote; points without one, or whose quote is not in the
    /// text, or in a section the template does not have, are dropped with the reason. A point read on a screenshot
    /// is kept only if the call has a screenshot within a few seconds of the minute given (`screenshots`, seconds).
    public static func compose(
        _ input: Input, brief: String?, sections: [(title: String, points: [ExternalPoint])],
        screenshots: [Double] = []
    ) -> Result {
        let hasTimes = input.lines.contains { $0.atSec > 0 }
        var verified: [(title: String, points: [Point])] = input.template.sections.map { ($0.title, []) }
        var discarded: [(point: String, reason: String)] = []
        for section in sections {
            guard
                let index = input.template.sections.firstIndex(where: {
                    normalized($0.title) == normalized(section.title)
                })
            else {
                discarded += section.points.map { ($0.text, "la sezione «\(section.title)» non è nel modello") }
                continue
            }
            for point in section.points {
                let text = point.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let fields = point.fields.filter { !emptyValues.contains(normalized($0.value)) }
                if let wanted = point.screenshotAtSec {
                    guard let at = screenshots.min(by: { abs($0 - wanted) < abs($1 - wanted) }),
                        abs(at - wanted) <= screenshotTolerance
                    else {
                        discarded.append((text, "nessuna schermata a quel minuto"))
                        continue
                    }
                    verified[index].points.append(
                        Point(text: text + " (dalla schermata)", fields: fields, atSec: hasTimes ? at : nil))
                    continue
                }
                guard let quote = point.quote?.trimmingCharacters(in: .whitespacesAndNewlines), !quote.isEmpty else {
                    discarded.append((text, "manca la citazione"))
                    continue
                }
                guard let at = KeyPointExtractor.locate(quote, in: input.lines, span: 3) else {
                    discarded.append((text, "citazione non trovata nel testo: «\(quote.prefix(80))»"))
                    continue
                }
                verified[index].points.append(Point(text: text, fields: fields, atSec: hasTimes ? at : nil))
            }
        }
        let brief = brief?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(
            markdown: render(input, brief: brief?.isEmpty == false ? brief : nil, sections: verified),
            sections: verified, discarded: discarded)
    }
}
