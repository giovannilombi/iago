import Foundation
import Testing

@testable import IAGOIntelligence

/// A request to the engine never carries an unbounded text: a single enormous line (a pasted JSON) used to fill the
/// memory of the Mac.
@Suite struct TextPiecesTests {
    static let json = "{" + (0..<4_000).map { "\"voce\($0)\":\"valore numero \($0)\"" }.joined(separator: ",") + "}"

    @Test func shortTextsStayWhole() {
        #expect(TextPieces.split("Una frase breve.", limit: 100) == ["Una frase breve."])
    }

    @Test func cutsAtTheEndOfASentenceThenAtASpace() {
        let text = String(repeating: "Prima frase lunga. ", count: 10) + String(repeating: "parola ", count: 40)
        let pieces = TextPieces.split(text, limit: 120)
        #expect(pieces.allSatisfy { $0.count <= 120 })
        #expect(pieces[0].hasSuffix("."))
        #expect(pieces.joined(separator: " ").split(separator: " ") == text.split(separator: " "))
    }

    @Test func aLineWithoutSpacesIsCutAtTheLimit() {
        let pieces = TextPieces.split(String(repeating: "x", count: 1_000), limit: 300)
        #expect(pieces.map(\.count) == [300, 300, 300, 100])
    }

    @Test func aHugeLineNeverMakesAHugeBlock() {
        let lines = [KeyPointExtractor.Line(atSec: 0, speaker: "", text: Self.json)]
        let blocks = KeyPointExtractor.blocks(lines)
        #expect(blocks.count > 10)
        let limit = KeyPointExtractor.blockCharacters + KeyPointExtractor.lineCharacters
        #expect(blocks.allSatisfy { $0.map(\.text.count).reduce(0, +) <= limit })
    }

    @Test func aHugeLineNeverMakesAHugeTidyRequest() {
        let chunks = TextTidier.chunks(Self.json)
        #expect(chunks.count > 10)
        #expect(chunks.allSatisfy { $0.count <= TextTidier.chunkLength })
    }
}
