import AppKit
import Testing

@testable import IAGOIngest

@Suite(.timeLimit(.minutes(1))) struct TeamsTranscriptTests {
    func write(_ text: String, _ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "iago-teams-\(UUID().uuidString)-\(name)")
        if name.hasSuffix(".docx") {
            let string = NSAttributedString(string: text)
            try string.data(
                from: NSRange(location: 0, length: string.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
            )
            .write(to: url)
        } else {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    @Test func webVTTWithVoices() throws {
        let vtt = """
            WEBVTT

            0f3c-1
            00:00:03.120 --> 00:00:05.000
            <v Mario Rossi>Buongiorno a tutti.</v>

            0f3c-2
            00:00:05.500 --> 00:00:09.250
            <v Anna Bianchi>Partiamo dal budget,
            poi la demo.</v>

            00:01:02.000 --> 00:01:04.000
            <v Mario Rossi>Va bene.</v>
            """
        let transcript = try #require(try TeamsTranscript.parse(try write(vtt, "riunione.vtt"), itemID: "x"))
        #expect(transcript.speakers.map(\.label) == ["Mario Rossi", "Anna Bianchi"])
        #expect(transcript.segments.map(\.speaker) == ["t1", "t2", "t1"])
        #expect(transcript.segments[1].text == "Partiamo dal budget, poi la demo.")
        #expect(transcript.segments[2].start == 62)
        #expect(transcript.engine.asr == "teams")
    }

    @Test func recentTeamsDocx() throws {
        let text = """
            Riunione portale - Trascrizione
            15 ottobre 2026, 09:30

            Mario Rossi   0:03
            Buongiorno a tutti.

            Anna Bianchi   1:15
            Partiamo dal budget.
            Poi vediamo la demo.

            Mario Rossi   1:02:03
            Chiudiamo qui.
            """
        let transcript = try #require(try TeamsTranscript.parse(try write(text, "riunione.docx"), itemID: "x"))
        #expect(transcript.segments.map(\.start) == [3, 75, 3723])
        #expect(transcript.segments[1].text == "Partiamo dal budget. Poi vediamo la demo.")
        #expect(transcript.speakers.map(\.label) == ["Mario Rossi", "Anna Bianchi"])
    }

    @Test func olderTeamsDocx() throws {
        let text = """
            0:0:0.0 --> 0:0:3.200
            Mario Rossi
            Ciao, mi sentite?

            0:0:3.200 --> 0:0:6.0
            Anna Bianchi
            Sì, perfettamente.
            """
        let transcript = try #require(try TeamsTranscript.parse(try write(text, "vecchia.docx"), itemID: "x"))
        #expect(transcript.segments.map(\.text) == ["Ciao, mi sentite?", "Sì, perfettamente."])
        #expect(transcript.speakers.map(\.label) == ["Mario Rossi", "Anna Bianchi"])
    }

    @Test func ordinaryDocumentIsNotATranscript() throws {
        let url = try write("Offerta economica\n\nIl prezzo è 10.000 euro.", "offerta.docx")
        #expect(try TeamsTranscript.parse(url, itemID: "x") == nil)
    }
}
