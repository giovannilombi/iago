import Foundation
import IAGOCore

/// A summary of a call with its category's template (ADR-0054), with the checks of the key points (ADR-0046) instead
/// of trusting the model:
/// - the call in blocks of about 10 minutes; every block gives points per section;
/// - every point quotes the transcript: IAGO finds the quote (numbers exact) and links the point to its minute, or
///   drops it;
/// - a section without points says "Non emerso";
/// - "In breve" is written from the verified points only, and a sentence with a number that is not in them is dropped;
/// - date and participants come from IAGO, not from the model.
public enum SummaryGenerator {
    public struct Input: Sendable {
        public var lines: [KeyPointExtractor.Line]
        public var template: SummaryTemplate
        public var date: Date?
        public var participants: [String]
        public var title: String

        public init(
            lines: [KeyPointExtractor.Line], template: SummaryTemplate, date: Date?, participants: [String],
            title: String
        ) {
            self.lines = lines
            self.template = template
            self.date = date
            self.participants = participants
            self.title = title
        }
    }

    /// One verified point of a section.
    public struct Point: Sendable, Equatable {
        public var text: String
        public var fields: [String: String]
        public var atSec: Double?
    }

    public struct Result: Sendable {
        public var markdown: String
        public var sections: [(title: String, points: [Point])]
        public var discarded: [(point: String, reason: String)]
        /// What the model answered, block by block (for the trial, never shown).
        public var answers: [String] = []
    }

    static let maxPointsPerSection = 8
    /// Seconds are linked as `iago://seek/<seconds>`: the app opens the player there.
    public static let seekScheme = "iago://seek/"

    public static func generate(
        _ input: Input, with engine: any LLMProvider, progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> Result {
        let blocks = KeyPointExtractor.blocks(input.lines)
        let hasTimes = input.lines.contains { $0.atSec > 0 }
        var collected: [String: [Point]] = [:]
        var discarded: [(String, String)] = []
        var answers: [String] = []
        for (index, block) in blocks.enumerated() {
            try Task.checkCancellation()
            let prompt = block.map {
                $0.speaker.isEmpty ? $0.text : "[\(KeyPointExtractor.clock($0.atSec))] \($0.speaker): \($0.text)"
            }.joined(separator: "\n")
            let answer = try await engine.generate(
                LLMRequest(system: system(input.template), prompt: prompt, maxTokens: 2_500))
            answers.append(answer)
            for (sectionTitle, candidates) in parse(answer, template: input.template) {
                let isOverview = input.template.sections.first { $0.title == sectionTitle }?.format == .paragraph
                for var candidate in candidates {
                    // Spoken words pasted as a point ("sistemare il resto") are not a summary.
                    guard candidate.text.first.map({ !$0.isLowercase }) ?? false else {
                        discarded.append((candidate.text, "frase copiata dal parlato, non riassunta"))
                        continue
                    }
                    candidate.text = withoutOwner(candidate.text, fields: candidate.fields)
                    guard !isCopy(candidate.text, of: candidate.quote) else {
                        discarded.append((candidate.text, "frase copiata dal parlato, non riassunta"))
                        continue
                    }
                    let atSec = KeyPointExtractor.locate(candidate.quote, in: block, span: 3)
                    // An overview sums up the block and seldom has one sentence to quote: it stays without a minute
                    // when every number it has is in the block.
                    guard atSec != nil || (isOverview && numbersAreIn(candidate.text, block)) else {
                        discarded.append((candidate.text, "citazione non trovata nella trascrizione"))
                        continue
                    }
                    var points = collected[sectionTitle, default: []]
                    let point = Point(
                        text: candidate.text, fields: candidate.fields, atSec: hasTimes ? atSec : nil)
                    if points.contains(where: { similar($0.text, point.text) }) {
                        discarded.append((candidate.text, "doppione"))
                        continue
                    }
                    points.append(point)
                    collected[sectionTitle] = points
                }
            }
            progress(Double(index + 1) / Double(blocks.count + 1))
        }
        let sections = input.template.sections.map { section in
            (title: section.title, points: Array(collected[section.title, default: []].prefix(maxPointsPerSection)))
        }
        try Task.checkCancellation()
        let brief = try await inBrief(sections, input: input, engine: engine)
        progress(1)
        return Result(
            markdown: render(input, brief: brief, sections: sections), sections: sections, discarded: discarded,
            answers: answers)
    }

    // MARK: Prompt

    static func system(_ template: SummaryTemplate) -> String {
        let sections = template.sections.map { section -> String in
            var line = "- \"\(section.title)\": \(section.instruction)"
            if !section.columns.isEmpty {
                line +=
                    " Per ogni punto indica anche, se detti: "
                    + section.columns.map { "\"\($0)\"" }
                    .joined(separator: ", ") + "."
            }
            return line
        }.joined(separator: "\n")
        return """
            Leggi un pezzo della trascrizione di una riunione di tipo «\(template.name)» e riempi queste sezioni:
            \(sections)

            Regole:
            - "testo" è un RIASSUNTO scritto da te, in terza persona e al massimo 15 parole: non copiare la frase \
            detta, non usare "io" o "noi". Esempio: detto «mettiamo la 22 così» → testo «Scelto il codice attività 22».
            - Ogni punto deve venire da ciò che è stato detto: in "citazione" copia parola per parola un pezzo breve \
            (al massimo 20 parole) della frase della trascrizione da cui lo ricavi, senza il minuto e senza il nome di \
            chi parla. Se non trovi una frase precisa, non scrivere il punto.
            - Al massimo 4 punti per sezione: solo quelli importanti. Ignora chiacchiere, battute e saluti.
            - Ignora i fatti personali e privati (salute, famiglia, visite, vita privata): non vanno nella sintesi.
            - Una decisione è presa in QUESTA riunione: un racconto di cose successe altrove o in passato non è una \
            decisione (al più è un punto saliente).
            - Non inventare nomi, numeri, date o importi. Usa i nomi di chi parla solo come compaiono nella trascrizione.
            - Nei punti con le colonne, "testo" dice solo cosa: chi e quando vanno nei "campi", non ripeterli nel testo.
            - Se un campo non è detto, non scriverlo (niente "non specificato").
            - Scrivi "testo" e i "campi" \(ContentLanguage.current.inLanguage); la "citazione" resta come è detta.
            - Se in questo pezzo una sezione non ha niente, lasciala vuota: va benissimo.

            Rispondi solo con JSON valido e compatto (su una riga, senza rientri), senza altro testo:
            {"sezioni":[{"titolo":"titolo della sezione","punti":[{"testo":"...","citazione":"...","campi":{"Chi":"..."}}]}]}
            """
    }

    struct Candidate {
        var text: String
        var quote: String
        var fields: [String: String]
    }

    /// Points per section title of the template; unknown sections are dropped.
    static func parse(_ answer: String, template: SummaryTemplate) -> [(String, [Candidate])] {
        // Section by section: a model that closes a bracket in the wrong place loses one section, not the block.
        var sections = sectionObjects(answer)
        if sections.isEmpty, let object = jsonObject(answer), let all = object["sezioni"] as? [[String: Any]] {
            sections = all
        }
        // Broken JSON (stray quotes and commas): read titles and points without the brackets.
        let lenient = lenientSections(answer)
        if lenient.reduce(0, { $0 + (($1["punti"] as? [Any])?.count ?? 0) })
            > sections.reduce(0, { $0 + (($1["punti"] as? [Any])?.count ?? 0) })
        {
            sections = lenient
        }
        guard !sections.isEmpty else { return [] }
        var result: [(String, [Candidate])] = []
        for section in sections {
            guard let title = section["titolo"] as? String,
                let match = template.sections.first(where: { normalized($0.title) == normalized(title) })
            else { continue }
            let points = (section["punti"] as? [[String: Any]] ?? []).compactMap { entry -> Candidate? in
                guard let text = (entry["testo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !text.isEmpty, let quote = entry["citazione"] as? String
                else { return nil }
                var fields: [String: String] = [:]
                for (key, value) in entry["campi"] as? [String: Any] ?? [:] {
                    guard let column = match.columns.first(where: { normalized($0) == normalized(key) }),
                        let value = (value as? String)?.trimmingCharacters(in: .whitespaces), !value.isEmpty,
                        !Self.emptyValues.contains(normalized(value))
                    else { continue }
                    fields[column] = value
                }
                return Candidate(text: text, quote: quote, fields: fields)
            }
            result.append((match.title, points))
        }
        return result
    }

    /// The JSON object of the answer; when the model ran out of room and the answer is cut, the last complete point
    /// is kept and the brackets are closed, so the block is not lost.
    static func jsonObject(_ answer: String) -> [String: Any]? {
        guard let open = answer.firstIndex(of: "{") else { return nil }
        let text = String(answer[open...])
        func decode(_ candidate: String) -> [String: Any]? {
            try? JSONSerialization.jsonObject(with: Data(candidate.utf8)) as? [String: Any]
        }
        if let close = text.lastIndex(of: "}"), let object = decode(String(text[...close])) { return object }
        // Cut answer: back to the end of a complete point, then close what is open.
        var end = text.endIndex
        while let close = text[..<end].lastIndex(of: "}") {
            let prefix = String(text[...close])
            for suffix in ["]}]}", "}]}]}", "]}]}]}", "}]}", "]}"] {
                if let object = decode(prefix + suffix) { return object }
            }
            end = close
        }
        return nil
    }

    /// Every `{"titolo": …}` object of the answer, read on its own (balanced braces, strings respected); a cut one is
    /// repaired like the whole answer.
    static func sectionObjects(_ answer: String) -> [[String: Any]] {
        let chars = Array(answer)
        var result: [[String: Any]] = []
        var index = 0
        while index < chars.count {
            guard chars[index] == "{" else {
                index += 1
                continue
            }
            // Only objects that start with "titolo".
            let head = String(chars[index..<min(chars.count, index + 20)]).replacingOccurrences(of: " ", with: "")
            guard head.hasPrefix("{\"titolo\"") else {
                index += 1
                continue
            }
            var depth = 0
            var inString = false
            var escaped = false
            var end = chars.count
            for position in index..<chars.count {
                let char = chars[position]
                if inString {
                    if escaped {
                        escaped = false
                    } else if char == "\\" {
                        escaped = true
                    } else if char == "\"" {
                        inString = false
                    }
                    continue
                }
                if char == "\"" { inString = true }
                if char == "{" || char == "[" { depth += 1 }
                if char == "}" || char == "]" {
                    depth -= 1
                    if depth == 0 {
                        end = position + 1
                        break
                    }
                }
            }
            let text = String(chars[index..<end])
            if let object = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
                ?? jsonObject(text)
            {
                result.append(object)
            }
            index = max(end, index + 1)
        }
        return result
    }

    /// Titles and points read with patterns instead of brackets: every "titolo", then the "testo"/"citazione" pairs
    /// (and "campi") until the next title.
    static func lenientSections(_ answer: String) -> [[String: Any]] {
        let string = #""((?:[^"\\]|\\.)*)""#
        guard let titleRegex = try? Regex(#""titolo"\s*:\s*"# + string),
            let pointRegex = try? Regex(#""testo"\s*:\s*"# + string + #"\s*,\s*"citazione"\s*:\s*"# + string),
            let fieldsRegex = try? Regex(#""campi"\s*:\s*\{([^}]*)\}"#),
            let pairRegex = try? Regex(string + #"\s*:\s*"# + string)
        else { return [] }
        func text(_ match: Regex<AnyRegexOutput>.Match, _ index: Int) -> String {
            guard let substring = match.output[index].substring else { return "" }
            return String(substring).replacingOccurrences(of: "\\\"", with: "\"")
        }
        let titles = answer.matches(of: titleRegex)
        var result: [[String: Any]] = []
        for (index, title) in titles.enumerated() {
            let end = index + 1 < titles.count ? titles[index + 1].range.lowerBound : answer.endIndex
            let region = answer[title.range.upperBound..<end]
            let points = region.matches(of: pointRegex)
            var entries: [[String: Any]] = []
            for (position, point) in points.enumerated() {
                var entry: [String: Any] = ["testo": text(point, 1), "citazione": text(point, 2)]
                let next = position + 1 < points.count ? points[position + 1].range.lowerBound : region.endIndex
                if let fields = region[point.range.upperBound..<next].firstMatch(of: fieldsRegex),
                    let body = fields.output[1].substring
                {
                    var values: [String: String] = [:]
                    for pair in body.matches(of: pairRegex) { values[text(pair, 1)] = text(pair, 2) }
                    entry["campi"] = values
                }
                entries.append(entry)
            }
            result.append(["titolo": text(title, 1), "punti": entries])
        }
        return result
    }

    /// The point is the quote itself (spoken words), not a summary of it.
    static func isCopy(_ text: String, of quote: String) -> Bool {
        let a = Set(KeyPointExtractor.words(text))
        let b = Set(KeyPointExtractor.words(quote))
        guard a.count >= 4, !b.isEmpty else { return false }
        return Double(a.intersection(b).count) / Double(a.union(b).count) >= 0.75
    }

    // MARK: In breve

    /// Three sentences from the verified points; a sentence with a number that is not in the points is dropped.
    static func inBrief(
        _ sections: [(title: String, points: [Point])], input: Input, engine: any LLMProvider
    ) async throws -> String? {
        let material = sections.filter { !$0.points.isEmpty }.map { section in
            "\(section.title):\n" + section.points.map { "- \($0.text)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        guard !material.isEmpty else { return nil }
        let answer = try await engine.generate(
            LLMRequest(
                system: """
                    Scrivi \(ContentLanguage.current.inLanguage) al massimo 3 frasi che riassumono la riunione «\(input.title)», usando SOLO \
                    i punti che ti do. Non aggiungere fatti, nomi o numeri che non ci sono. Solo il testo, senza titoli.
                    """, prompt: material, maxTokens: 300))
        let allowed = Set(KeyPointExtractor.words(material).filter { $0.contains(where: \.isNumber) })
        let sentences = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: ".!?")).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .filter { sentence in
                Set(KeyPointExtractor.words(sentence).filter { $0.contains(where: \.isNumber) }).isSubset(of: allowed)
            }
        guard !sentences.isEmpty else { return nil }
        return sentences.prefix(3).map { $0 + "." }.joined(separator: " ")
    }

    // MARK: Markdown

    static func render(_ input: Input, brief: String?, sections: [(title: String, points: [Point])]) -> String {
        var lines: [String] = []
        let language = ContentLanguage.current
        if let brief { lines += ["## \(language.pick(it: "In breve", en: "In brief"))", "", brief, ""] }
        var facts: [String] = []
        if let date = input.date {
            facts.append(
                "**\(language.pick(it: "Data", en: "Date")):** \(date.formatted(.dateTime.day().month(.wide).year().locale(language.locale)))"
            )
        }
        if !input.participants.isEmpty {
            facts.append(
                "**\(language.pick(it: "Partecipanti", en: "Participants")):** \(input.participants.joined(separator: ", "))"
            )
        }
        if !facts.isEmpty { lines += [facts.joined(separator: " · "), ""] }
        for (index, section) in input.template.sections.enumerated() {
            let points = sections[index].points
            lines += ["## \(section.title)", ""]
            guard !points.isEmpty else {
                lines += ["_\(language.pick(it: "Non emerso", en: "Not mentioned"))_", ""]
                continue
            }
            let columns = section.columns
            if !columns.isEmpty {
                // The verified text goes in the first column that describes the point ("Cosa", "Rischio"…); without
                // one, in a "Punto" column.
                let textColumn = columns.first { !metaColumns.contains(normalized($0)) }
                let header = (textColumn == nil ? columns + ["Punto"] : columns) + ["Minuto"]
                lines.append("| " + header.joined(separator: " | ") + " |")
                lines.append("|" + String(repeating: " --- |", count: header.count))
                for point in points {
                    var cells = columns.map { $0 == textColumn ? cell(point.text) : cell(point.fields[$0] ?? "—") }
                    if textColumn == nil { cells.append(cell(point.text)) }
                    cells.append(minute(point))
                    lines.append("| " + cells.joined(separator: " | ") + " |")
                }
                lines.append("")
            } else if section.format == .paragraph {
                lines += [
                    points.map { "\($0.text) \(minute($0))".trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " "), "",
                ]
            } else {
                lines += points.map { "- \($0.text) \(minute($0))".trimmingCharacters(in: .whitespaces) } + [""]
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// What models write for "not said".
    static let emptyValues: Set<String> = [
        "null", "nil", "n a", "nd", "n d", "non specificato", "non specificata", "non detto", "non indicato",
        "non indicata", "sconosciuto", "nessuno",
    ]

    /// Columns that qualify a point (who, when, state) rather than say it.
    static let metaColumns: Set<String> = [
        "chi", "persona", "entro", "data", "quando", "stato", "previsione", "impatto", "chi la propone",
    ]

    static func minute(_ point: Point) -> String {
        guard let atSec = point.atSec else { return "" }
        return "[\(KeyPointExtractor.clock(atSec))](\(seekScheme)\(Int(atSec)))"
    }

    static func cell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
    }

    /// "Mario deve verificare il CCNL" with Chi = Mario → "Verificare il CCNL": the column already says who.
    static func withoutOwner(_ text: String, fields: [String: String]) -> String {
        guard let owner = ["Chi", "Persona"].compactMap({ fields[$0] }).first, !owner.isEmpty,
            text.lowercased().hasPrefix(owner.lowercased() + " ")
        else { return text }
        var rest = text.dropFirst(owner.count + 1)
        for verb in ["deve ", "dovrà ", "si occupa di ", "si occuperà di ", "provvede a ", "provvederà a "]
        where rest.lowercased().hasPrefix(verb) {
            rest = rest.dropFirst(verb.count)
            break
        }
        guard let first = rest.first else { return text }
        return first.uppercased() + rest.dropFirst()
    }

    /// Every number of `text` is said somewhere in the block.
    static func numbersAreIn(_ text: String, _ block: [KeyPointExtractor.Line]) -> Bool {
        let numbers = Set(KeyPointExtractor.words(text).filter { $0.contains(where: \.isNumber) })
        guard !numbers.isEmpty else { return true }
        let said = Set(block.flatMap { KeyPointExtractor.words($0.text) })
        return numbers.isSubset(of: said)
    }

    static func normalized(_ text: String) -> String {
        KeyPointExtractor.words(text).joined(separator: " ")
    }

    static func similar(_ a: String, _ b: String) -> Bool {
        let left = Set(KeyPointExtractor.words(a).filter { $0.count > 3 })
        let right = Set(KeyPointExtractor.words(b).filter { $0.count > 3 })
        guard !left.isEmpty, !right.isEmpty else { return false }
        return Double(left.intersection(right).count) / Double(min(left.count, right.count)) >= 0.7
    }
}
