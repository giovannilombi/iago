import Foundation

/// A hard ceiling on what one request to the engine carries. Texts are normally cut between lines or paragraphs, but a
/// line can be enormous (a pasted JSON, a text without line breaks): sent whole, it fills the memory of the Mac. Such a
/// line is cut here, at the end of a sentence when there is one, else at a space, else exactly at the limit.
enum TextPieces {
    static func split(_ text: String, limit: Int) -> [String] {
        guard limit > 0, text.count > limit else { return [text] }
        let characters = Array(text)
        var pieces: [String] = []
        var start = 0
        while characters.count - start > limit {
            let end = start + limit
            // Look for a cut only in the second half, so no piece comes out tiny.
            let earliest = start + limit / 2
            var cut = end
            if let sentence = (earliest..<end).last(where: { index in
                ".!?\n".contains(characters[index - 1]) && characters[index].isWhitespace
            }) {
                cut = sentence
            } else if let space = (earliest..<end).last(where: { characters[$0].isWhitespace }) {
                cut = space
            }
            let piece = String(characters[start..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { pieces.append(piece) }
            start = cut
        }
        let rest = String(characters[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { pieces.append(rest) }
        return pieces
    }
}
