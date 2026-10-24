import Foundation
import Testing

@testable import IAGOStore

@Suite struct EmailTests {
    func input(
        _ subject: String?, from: String, id: String?, replyTo: String? = nil, refs: [String] = [], at seconds: Double
    ) -> EmailInput {
        EmailInput(
            from: .init(name: nil, address: from), to: [.init(name: "Giovanni", address: "giovanni@studio.it")],
            subject: subject, sentAt: Date(timeIntervalSince1970: seconds), messageID: id, inReplyTo: replyTo,
            references: refs, bodyMarkdown: "Corpo di \(subject ?? "-")")
    }

    @Test func directionTitleAndSearch() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        try archive.setUserEmailAddresses(["Giovanni@Studio.it", "non-un-indirizzo"])
        #expect(try archive.userEmailAddresses() == ["giovanni@studio.it"])
        let inbound = try archive.importEmail(
            input("Offerta", from: "mario@cliente.it", id: "a@x", at: 1_000), original: Data("raw".utf8))
        let outbound = try archive.importEmail(
            input(nil, from: "GIOVANNI@studio.it", id: "b@x", at: 2_000), original: nil)
        #expect(inbound.type == .email)
        #expect(inbound.title == "Offerta")
        #expect(outbound.title.hasPrefix("Email · "))
        #expect(try archive.emailMeta(itemID: inbound.id)?.direction == .inbound)
        #expect(try archive.emailMeta(itemID: outbound.id)?.direction == .outbound)
        #expect(try archive.emailMeta(itemID: inbound.id)?.to.first?.name == "Giovanni")
        #expect(try archive.assets(itemID: inbound.id).map(\.kind).contains(.originalEmail))
        #expect(try archive.search("offerta").first?.itemID == inbound.id)
        try archive.setEmailDirection(inbound.id, .outbound)
        #expect(try archive.emailMeta(itemID: inbound.id)?.direction == .outbound)
    }

    @Test func bodyRefreshKeepsHeadersAndSkipsCorrectedText() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let email = try archive.importEmail(input("Offerta", from: "m@c.it", id: "r@x", at: 1_000), original: nil)
        let corrected = try archive.importEmail(input("Altra", from: "m@c.it", id: "s@x", at: 2_000), original: nil)
        try archive.updateContentMarkdown("# Altra\n\nTesto mio", itemID: corrected.id)
        #expect(try archive.refreshEmailBody(itemID: email.id, body: "- primo punto"))
        #expect(try !archive.refreshEmailBody(itemID: email.id, body: "- primo punto"))
        #expect(try !archive.refreshEmailBody(itemID: corrected.id, body: "- altro"))
        let content = try archive.assets(itemID: email.id).first { $0.kind == .contentMD }!
        let text = String(decoding: try archive.readAssetData(content), as: UTF8.self)
        #expect(text.hasPrefix("# Offerta\n\n**Da:** m@c.it  \n**A:** Giovanni <giovanni@studio.it>  \n"))
        #expect(text.hasSuffix("  \n\n- primo punto"))
        #expect(try archive.search("primo").first?.itemID == email.id)
    }

    @Test func threadsAreBuiltInAnyImportOrder() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        // The reply arrives before the message it answers.
        let reply = try archive.importEmail(
            input("Re: Offerta", from: "g@studio.it", id: "2@x", replyTo: "1@x", at: 2_000), original: nil)
        let first = try archive.importEmail(input("Offerta", from: "m@cliente.it", id: "1@x", at: 1_000), original: nil)
        let third = try archive.importEmail(
            input("Re: Re: Offerta", from: "m@cliente.it", id: "3@x", replyTo: "2@x", refs: ["1@x", "2@x"], at: 3_000),
            original: nil)
        #expect(try archive.thread(itemID: first.id).map(\.id) == [first.id, reply.id, third.id])
        #expect(try archive.thread(itemID: third.id).map(\.id) == [first.id, reply.id, third.id])
        let links = try archive.links(itemID: reply.id)
        #expect(Set(links.map(\.item.id)) == [first.id, third.id])
        #expect(links.allSatisfy { $0.link.kind == .replyTo })
    }

    @Test func manualLinksAndPurge() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let call = try fixture.makeItem("Kickoff")
        let email = try archive.importEmail(input("Verbale", from: "m@c.it", id: "v@x", at: 1_000), original: nil)
        let link = try #require(try archive.addLink(from: email.id, to: call.id, kind: .followUpOf))
        #expect(try archive.addLink(from: call.id, to: email.id, kind: .related)?.id == link.id)  // no duplicates
        #expect(try archive.links(itemID: call.id).first?.outgoing == false)
        try archive.removeLink(link.id)
        #expect(try archive.links(itemID: call.id).isEmpty)
        try archive.addLink(from: email.id, to: call.id, kind: .related)
        try archive.purgeItem(email.id)
        #expect(try archive.links(itemID: call.id).isEmpty)
        #expect(try archive.emailMeta(itemID: email.id) == nil)
    }

    @Test func contactsSuggestProjects() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let client = try archive.createClient(name: "Poldo")
        let portale = try archive.createProject(name: "Portale")
        try archive.addContact(name: "Mario Rossi", email: "Mario@Poldo.it", role: .client, clientID: client.id)
        try archive.addContact(name: "Anna Verdi", email: "anna@forn.it", role: .supplier, projectID: portale.id)
        try archive.addContact(name: "Luca Bianchi", email: "luca@studio.it", role: .internal)
        #expect(try archive.contacts(clientID: client.id).map(\.name) == ["Mario Rossi"])
        #expect(try archive.contacts().map(\.name) == ["Luca Bianchi"])
        #expect(try archive.people().map(\.name).contains("Mario Rossi"))  // suggested on decisions
        let suggestions = try archive.projectSuggestions(for: ["mario@poldo.it", "luca@studio.it", "anna@forn.it"])
        #expect(suggestions.count == 2)
        #expect(suggestions.contains { $0.clientID == client.id && $0.people == ["Mario Rossi"] })
        #expect(suggestions.contains { $0.projectID == portale.id })
        #expect(try archive.projectSuggestions(for: ["luca@studio.it"]).isEmpty)  // colleagues do not decide
    }

    @Test func domainRulesGiveRolesAndPointToClients() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let client = try archive.createClient(name: "Poldo")
        try archive.setDomainRules([
            DomainRule(domain: "@Azienda.it", role: .internal),
            DomainRule(domain: "gruppo.example", role: .internal),
            DomainRule(domain: "fornitore.it", role: .supplier),
            DomainRule(domain: "poldo.it", role: .client, clientID: client.id),
            DomainRule(domain: "nodot", role: .internal),
        ])
        #expect(
            try archive.domainRules().map(\.domain) == [
                "azienda.it", "gruppo.example", "fornitore.it", "poldo.it",
            ])
        try archive.addContact(name: "Mario Rossi", email: "mario@poldo.it", role: .supplier)
        let roles = try archive.roles(for: [
            "Giovanni@azienda.it", "x@mail.gruppo.example", "a@fornitore.it", "mario@poldo.it", "b@poldo.it",
            "z@altro.it",
        ])
        #expect(roles["giovanni@azienda.it"]?.role == .internal)
        #expect(roles["x@mail.gruppo.example"]?.role == .internal)  // subdomain
        #expect(roles["a@fornitore.it"]?.role == .supplier)
        #expect(roles["mario@poldo.it"]?.byDomain == false)  // the person wins over the domain
        #expect(roles["mario@poldo.it"]?.role == .supplier)
        #expect(roles["b@poldo.it"]?.clientID == client.id)
        #expect(roles["z@altro.it"] == nil)
        let suggestions = try archive.projectSuggestions(for: ["b@poldo.it", "giovanni@azienda.it"])
        #expect(suggestions.map(\.clientID) == [client.id])
    }

    @Test func classificationUsesConversationPeopleDomainsAndSubject() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let poldo = try archive.createClient(name: "Poldo")
        let portale = try archive.createProject(name: "Portale")
        let app = try archive.createProject(name: "App mobile")
        try archive.setProjectClient(portale.id, poldo.id)
        try archive.setProjectClient(app.id, poldo.id)
        let design = try archive.createStream(projectID: portale.id, name: "Design")
        try archive.setDomainRules([DomainRule(domain: "poldo.it", role: .client, clientID: poldo.id)])

        // Conversation: a reply to an email already filed in Portale / Design.
        let first = try archive.importEmail(input("Offerta", from: "m@poldo.it", id: "o1@x", at: 1_000), original: nil)
        try archive.updateItem(first.id) { $0.projectId = portale.id }
        try archive.setStreams([design.id], itemID: first.id)
        #expect(try archive.emailExists(messageID: "o1@x"))
        #expect(throws: ArchiveError.duplicateEmail("o1@x")) {
            try archive.importEmail(input("Offerta", from: "m@poldo.it", id: "o1@x", at: 1_000), original: nil)
        }
        #expect(try !archive.emailExists(messageID: "nuovo@x"))
        let reply = try archive.classifyEmail(
            addresses: ["m@poldo.it"], subject: "Re: Offerta", inReplyTo: "o1@x", references: [])
        #expect(reply.projectID == portale.id && reply.streamIDs == [design.id] && reply.confident)

        // Client domain with two projects: the subject decides, otherwise it is a doubt.
        let named = try archive.classifyEmail(
            addresses: ["x@poldo.it"], subject: "Verbale app mobile", inReplyTo: nil, references: [])
        #expect(named.projectID == app.id && named.confident)
        let doubt = try archive.classifyEmail(
            addresses: ["x@poldo.it"], subject: "Ciao", inReplyTo: nil, references: [])
        #expect(doubt.projectID == nil && doubt.clientID == poldo.id && !doubt.confident)

        // Only the subject: a proposal to check.
        let subjectOnly = try archive.classifyEmail(
            addresses: ["a@altro.it"], subject: "Aggiornamento Portale", inReplyTo: nil, references: [])
        #expect(subjectOnly.projectID == portale.id && !subjectOnly.confident)
        let nothing = try archive.classifyEmail(
            addresses: ["a@altro.it"], subject: "Ciao", inReplyTo: nil, references: [])
        #expect(nothing.reason == .none)
    }
}
