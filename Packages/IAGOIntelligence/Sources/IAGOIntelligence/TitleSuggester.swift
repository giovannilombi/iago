import Foundation
import os

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// Short titles for a dictated or selected passage (ADR-0042). Apple's on-device model writes the title when
/// Apple Intelligence is on: it runs on the Mac, never on the network. Otherwise the first sentence is offered
/// as a hint and the user writes the title. The text itself is never logged.
public enum TitleSuggester {
    public static let maxWords = 8
    private static let logger = Logger(subsystem: "com.giovannilombi.iago", category: "intelligence")

    /// True when the on-device model can be used now (Apple Intelligence on, model ready).
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
            if #available(macOS 26, *) {
                if case .available = SystemLanguageModel.default.availability { return true }
            }
        #endif
        return false
    }

    /// A title of at most `maxWords` words in the language of the text, or nil (model unavailable or refused).
    public static func suggest(for text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isAvailable else { return nil }
        #if canImport(FoundationModels)
            if #available(macOS 26, *) {
                do {
                    let session = LanguageModelSession(
                        instructions: """
                            Scrivi un titolo breve, al massimo \(maxWords) parole, che riassuma il testo che ricevi. \
                            Usa la stessa lingua del testo. Rispondi solo con il titolo, senza virgolette, \
                            senza punto finale e senza premesse.
                            """)
                    let response = try await session.respond(to: String(trimmed.prefix(4_000)))
                    let title = clean(response.content)
                    return title.isEmpty ? nil : title
                } catch {
                    logger.notice(
                        "Title suggestion unavailable: \(String(describing: type(of: error)), privacy: .public)")
                    return nil
                }
            }
        #endif
        return nil
    }

    /// The model's answer as a title: one line, no quotes, no "Titolo:" prefix, no final period, word limit.
    static func clean(_ raw: String) -> String {
        var title =
            raw.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        for prefix in ["Titolo:", "Title:", "titolo:", "title:"] where title.hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'«»“”*#").union(.whitespaces))
        while let last = title.last, ".:;".contains(last) { title.removeLast() }
        let words = title.split(separator: " ")
        if words.count > maxWords + 4 { title = words.prefix(maxWords + 4).joined(separator: " ") + "…" }
        return title
    }

    /// The first sentence, cut to `limit` characters: the hint when no model is available.
    public static func firstSentence(_ text: String, limit: Int = 90) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentence = trimmed.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? trimmed
        return sentence.count > limit
            ? "\(sentence.prefix(limit).trimmingCharacters(in: .whitespaces))…" : sentence
    }
}
