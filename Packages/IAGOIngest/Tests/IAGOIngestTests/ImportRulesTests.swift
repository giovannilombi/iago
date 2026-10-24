import Foundation
import Testing

@testable import IAGOIngest

@Suite struct ImportRulesTests {
    func email(_ headers: String, body: String = "Testo") -> EmailMessage {
        try! EmailParser.parse(Data((headers + "\r\n\r\n" + body).utf8))
    }

    @Test func meetingsAutoRepliesAndNewslettersAreRecognised() {
        let invite = email(
            """
            From: Anna <anna@assicura.example>\r
            Subject: Invito: Adesione fondo\r
            Content-Type: multipart/mixed; boundary="b"
            """,
            body:
                "--b\r\nContent-Type: text/plain\r\n\r\nCiao\r\n--b\r\nContent-Type: text/calendar; method=REQUEST\r\n\r\nBEGIN:VCALENDAR\r\n--b--"
        )
        #expect(invite.isCalendar)
        #expect(ImportRules.evaluate(invite, rules: [], builtIn: .init()) == .exclude("Invito o risposta a un meeting"))
        // Only the subject is enough, in Italian or English.
        let accepted = email("From: Mario <mario@poldo.it>\r\nSubject: Accepted: Kickoff")
        #expect(ImportRules.evaluate(accepted, rules: [], builtIn: .init()) != .none)
        let auto = email("From: a@b.it\r\nSubject: Grazie\r\nAuto-Submitted: auto-replied")
        #expect(auto.isAutoReply)
        #expect(ImportRules.evaluate(auto, rules: [], builtIn: .init()) == .exclude("Risposta automatica"))
        let news = email("From: news@x.it\r\nSubject: Novità\r\nList-Unsubscribe: <mailto:x@x.it>")
        #expect(news.isBulk && ImportRules.evaluate(news, rules: [], builtIn: .init()) == .none)  // off by default
        #expect(ImportRules.evaluate(news, rules: [], builtIn: .init(newsletters: true)) != .none)
        // Switched off, a meeting goes through.
        #expect(ImportRules.evaluate(invite, rules: [], builtIn: .init(meetings: false)) == .none)
    }

    @Test func userRulesExcludeFirstThenAssignInOrder() {
        let message = email(
            "From: Anna Bianchi <anna@Assicura.example>\r\nTo: io@studio.it\r\nSubject: Modulo di adesione")
        let rules = [
            ImportRule(id: "1", action: .assign, field: .domain, pattern: "assicura.example", projectID: "fondo"),
            ImportRule(id: "2", action: .assign, field: .subject, pattern: "adesione", projectID: "altro"),
            ImportRule(id: "3", action: .exclude, field: .subject, pattern: "promo"),
            ImportRule(id: "4", action: .exclude, field: .from, pattern: "anna", enabled: false),
        ]
        #expect(
            ImportRules.evaluate(message, rules: rules, builtIn: .init()) == .assign(projectID: "fondo", streamID: nil))
        let promo = email("From: x@assicura.example\r\nSubject: PROMO di ottobre")
        #expect(
            ImportRules.evaluate(promo, rules: rules, builtIn: .init()) == .exclude("Regola: oggetto contiene «promo»"))
        let other = email("From: x@altro.it\r\nSubject: Ciao")
        #expect(ImportRules.evaluate(other, rules: rules, builtIn: .init()) == .none)
    }
}
