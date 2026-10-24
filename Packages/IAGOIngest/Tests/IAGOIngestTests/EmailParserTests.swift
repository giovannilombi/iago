import Foundation
import Testing

@testable import IAGOIngest

@Suite struct EmailParserTests {
    static func crlf(_ text: String) -> Data { Data(text.replacingOccurrences(of: "\n", with: "\r\n").utf8) }

    @Test func multipartWithAlternativeBodyAndAttachments() throws {
        let pdf = Data("%PDF-1.4 finto".utf8).base64EncodedString()
        let logo = Data(repeating: 7, count: 300).base64EncodedString()
        let eml = Self.crlf(
            """
            From: "Rossi, Mario" <Mario.Rossi@Cliente.it>
            To: Giovanni <giovanni@studio.it>, info@studio.it
            Cc: =?UTF-8?Q?Luc=C3=ADa_P=C3=A9rez?= <lucia@cliente.it>
            Subject: =?UTF-8?B?T2ZmZXJ0YSBwb3J0YWxl?= =?UTF-8?Q?_=E2=80=93_versione_2?=
            Date: Tue, 6 Oct 2026 10:12:33 +0200
            Message-ID: <abc123@cliente.it>
            In-Reply-To: <prev999@studio.it>
            References: <first1@studio.it>
             <prev999@studio.it>
            MIME-Version: 1.0
            Content-Type: multipart/mixed; boundary="outer"

            --outer
            Content-Type: multipart/alternative; boundary="alt"

            --alt
            Content-Type: text/plain; charset="utf-8"
            Content-Transfer-Encoding: quoted-printable

            Buongiorno, in allegato l'offerta aggiornata: il prezzo =C3=A8 12.000 =E2=82=AC=
             e la consegna a novembre.

            Saluti
            --alt
            Content-Type: text/html; charset="utf-8"

            <p>Buongiorno</p>
            --alt--

            --outer
            Content-Type: application/pdf; name="offerta.pdf"
            Content-Disposition: attachment; filename*=utf-8''Offerta%20v2.pdf
            Content-Transfer-Encoding: base64

            \(pdf)
            --outer
            Content-Type: image/png
            Content-Disposition: inline; filename="logo.png"
            Content-ID: <logo@cliente>
            Content-Transfer-Encoding: base64

            \(logo)
            --outer--
            """)
        let message = try EmailParser.parse(eml)
        #expect(message.from == EmailAddress(name: "Rossi, Mario", address: "mario.rossi@cliente.it"))
        #expect(message.to.map(\.address) == ["giovanni@studio.it", "info@studio.it"])
        #expect(message.cc.first?.name == "Lucía Pérez")
        #expect(message.subject == "Offerta portale – versione 2")
        #expect(message.date == Date(timeIntervalSince1970: 1_791_274_353))
        #expect(message.messageID == "abc123@cliente.it")
        #expect(message.inReplyTo == "prev999@studio.it")
        #expect(message.references == ["first1@studio.it", "prev999@studio.it"])
        #expect(message.bodyMarkdown.contains("il prezzo è 12.000 € e la consegna a novembre."))
        #expect(message.attachments.map(\.filename) == ["Offerta v2.pdf", "logo.png"])
        #expect(message.attachments[0].data == Data("%PDF-1.4 finto".utf8))
        #expect(message.attachments[0].isInline == false)
        #expect(message.attachments[1].isInline == true)
    }

    @Test func htmlOnlyLatin1BodyNeverKeepsImages() throws {
        var eml = Self.crlf(
            """
            From: fornitore@ditta.com
            To: giovanni@studio.it
            Subject: Conferma ordine
            Date: 7 Oct 2026 09:00 +0000
            Content-Type: text/html; charset=iso-8859-1
            Content-Transfer-Encoding: 8bit


            """)
        eml.append(
            "<html><head><style>p{color:red}</style></head><body><h2>Ordine n. 7</h2><p>Consegna gi&agrave; fissata: <b>luned\u{EC}</b>.</p><img src=\"https://tracker.example/pixel.gif\"><ul><li>Uno</li><li>Due</li></ul><a href=\"https://ditta.com/ordine\">Dettagli</a></body></html>"
                .data(using: .isoLatin1)!)
        let message = try EmailParser.parse(eml)
        #expect(message.from?.address == "fornitore@ditta.com")
        #expect(message.date != nil)
        let body = message.bodyMarkdown
        #expect(body.contains("## Ordine n. 7"))
        #expect(body.contains("Consegna già fissata: **lunedì**."))
        #expect(body.contains("- Uno\n- Due"))
        #expect(body.contains("[Dettagli](https://ditta.com/ordine)"))
        #expect(!body.contains("tracker"))
        #expect(!body.contains("color"))
    }

    @Test func rejectsNonEmailAndReadsScreenshotHeaders() throws {
        #expect(throws: EmailParserError.self) { try EmailParser.parse(Data("solo testo".utf8)) }
        let guess = EmailParser.guessHeaders(
            fromOCR:
                "Da: Mario Rossi <mario@cliente.it>\nInviato: martedì 6 ottobre 2026 10:12\nA: Giovanni\nOggetto: Offerta portale\n\nCiao"
        )
        #expect(guess.from == "Mario Rossi <mario@cliente.it>")
        #expect(guess.subject == "Offerta portale")
        #expect(guess.date == "martedì 6 ottobre 2026 10:12")
        #expect(guess.to == "Giovanni")
    }

    @Test func outlookPlainTextBulletsAreJoinedToTheirText() {
        let plain =
            "Ciao a tutti,\n\nAllego:\n\n\n  *\nOfferta in ENG:\n     *\nCorreggiamo le 15 weeks?\n     *\nAggiungo Payment terms\n  *\nAllegato tecnico\n\nGrazie"
        #expect(
            Bullets.join(plain)
                == "Ciao a tutti,\n\nAllego:\n\n\n- Offerta in ENG:\n  - Correggiamo le 15 weeks?\n  - Aggiungo Payment terms\n- Allegato tecnico\n\nGrazie"
        )
    }

    @Test func htmlListItemsWrappingParagraphsStayOnOneLine() {
        let html =
            "<p>Punti:</p><ul><li><p class=MsoNormal>Primo</p></li><li><p>Secondo</p></li></ul><ol><li><p>Uno</p></li></ol>"
        let markdown = HTMLToMarkdown.convert(html)
        #expect(markdown.contains("- Primo\n- Secondo"))
        #expect(markdown.contains("- Uno"))
        #expect(!markdown.contains("-\n"))
    }

    @Test func outlookMentionsLoseTheirMailtoAddress() throws {
        let raw =
            "From: a@b.it\r\nSubject: Ciao\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n@Mattia Rossi<mailto:mattia@b.it> dagli una letta"
        #expect(try EmailParser.parse(Data(raw.utf8)).bodyMarkdown == "@Mattia Rossi dagli una letta")
    }

    @Test func numberedMarkersAndPlainLinesAreKept() {
        #expect(Bullets.join("1.\nPrimo\n2)\nSecondo") == "1. Primo\n2. Secondo")
        #expect(Bullets.join("o\n") == "")
        #expect(Bullets.join("Testo normale\n- già elenco") == "Testo normale\n- già elenco")
    }
}
