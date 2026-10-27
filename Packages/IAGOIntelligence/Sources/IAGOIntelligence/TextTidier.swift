import Foundation
import IAGOCore

/// "Riordina testo" (FR-219, ADR-0048): the local engine removes filler words, repetitions and false starts from a
/// dictated text, fixes punctuation and splits it into paragraphs, without adding, summarising or changing facts.
/// Only with an engine chosen by the user; the result is a proposal the user confirms.
public enum TextTidier {
    static let system = """
        Riordini testi dettati a voce. Restituisci lo STESSO testo, ripulito:
        - togli gli intercalari: ehm, uhm, allora, cioè, tipo, diciamo, praticamente, insomma, niente, ok, va bene \
        (quando non risponde a una domanda), "no?" a fine frase;
        - togli ripetizioni e frasi ripartite ("io avevo, io avevo provato" → "io avevo provato");
        - correggi punteggiatura, maiuscole e accordi evidenti;
        - unisci le frasi spezzate e dividi in paragrafi brevi; elenchi puntati solo se il testo elenca cose.
        Esempio. Testo: "allora, cioè, io avevo, io avevo provato a chiamare Anna, no? per avere conferma del 2%"
        Risposta: "Avevo provato a chiamare Anna per avere conferma del 2%."
        Regole fisse: non aggiungere nulla (né etichette come "Speaker 1:", né titoli, né commenti), non riassumere, \
        non tradurre, non togliere informazioni. Nomi, numeri, date, importi, percentuali, email e termini tecnici \
        restano identici. Scrivi nella lingua del testo. Rispondi solo con il testo riordinato.
        """

    /// Characters per request: long notes go in pieces, cut between paragraphs.
    static let chunkLength = 3_000

    public static func tidy(_ text: String, with engine: any LLMProvider) async throws -> String {
        var pieces: [String] = []
        for chunk in chunks(text) {
            try Task.checkCancellation()
            let answer = try await engine.generate(
                LLMRequest(system: system, prompt: chunk, maxTokens: max(256, chunk.count / 2)))
            pieces.append(clean(answer))
        }
        return pieces.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Paragraphs grouped up to `chunkLength`; a longer paragraph is cut between sentences, or at a space.
    static func chunks(_ text: String) -> [String] {
        let paragraphs = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var result: [String] = []
        var current = ""
        func push(_ piece: String) {
            if !current.isEmpty, current.count + piece.count + 1 > chunkLength {
                result.append(current)
                current = ""
            }
            current += current.isEmpty ? piece : "\n" + piece
        }
        for paragraph in paragraphs {
            if paragraph.count <= chunkLength {
                push(paragraph)
                continue
            }
            // Cut between sentences, or at a space when there are none (a pasted JSON): never over the limit.
            TextPieces.split(paragraph, limit: chunkLength).forEach(push)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Names, numbers, dates, amounts and addresses of the original that the tidied text no longer has: the preview
    /// warns about them, because a rewrite must never lose facts.
    public static func missingFacts(original: String, tidied: String) -> [String] {
        let after = tidied.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let afterDigits = tidied.filter(\.isNumber)
        var missing: [String] = []
        for fact in facts(original) where !missing.contains(fact) {
            let digits = fact.filter(\.isNumber)
            if !digits.isEmpty {
                // "12.000", "12000" and "12 000" are the same number.
                if !afterDigits.contains(digits) { missing.append(fact) }
            } else if !after.contains(fact.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)) {
                missing.append(fact)
            }
        }
        return missing
    }

    /// Words a transcript capitalises after a pause without ending the sentence: not names.
    static let notNames: Set<String> = [
        "esatto", "giusto", "niente", "perfetto", "certo", "bene", "allora", "grazie", "okay", "sì", "si", "no",
        "va", "vabbè", "infatti", "comunque", "quindi", "però", "poi", "anche", "ecco", "beh", "boh", "ciao", "good",
        "god", "yes", "vero", "chiaro", "assolutamente", "appunto", "dunque", "intanto", "praticamente",
    ]

    /// Tokens with digits (numbers, dates, %, amounts), email addresses, and capitalised words not opening a sentence
    /// (names).
    static func facts(_ text: String) -> [String] {
        var result: [String] = []
        var sentenceStart = true
        for raw in text.split(whereSeparator: \.isWhitespace) {
            let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: ",;:()\"«»“”'?!."))
            defer { sentenceStart = raw.last.map { ".!?\n".contains($0) } ?? false }
            guard !token.isEmpty else { continue }
            if token.contains(where: \.isNumber) || token.contains("@") {
                result.append(token)
            } else if !sentenceStart, token.count >= 3, token.first?.isUppercase == true,
                !notNames.contains(token.lowercased())
            {
                result.append(token)
            }
        }
        return result
    }

    /// The answer without reasoning blocks, code fences or a "here is the text" opening.
    static func clean(_ raw: String) -> String {
        var text = raw
        while let open = text.range(of: "<think>") {
            let close = text.range(of: "</think>", range: open.upperBound..<text.endIndex)
            text.removeSubrange(open.lowerBound..<(close?.upperBound ?? text.endIndex))
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.split(separator: "\n", omittingEmptySubsequences: false).dropFirst()
                .joined(separator: "\n")
            if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        }
        let openings = ["Ecco il testo riordinato:", "Ecco il testo:", "Testo riordinato:", "Here is the text:"]
        for opening in openings where text.hasPrefix(opening) {
            text = String(text.dropFirst(opening.count))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
