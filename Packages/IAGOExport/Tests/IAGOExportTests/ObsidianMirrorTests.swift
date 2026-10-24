import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOExport

@Suite struct ObsidianMirrorTests {
    let utc = TimeZone(identifier: "UTC")!

    @Test func writesOnlyEnabledProjectsAndNeverTouchesOtherNotes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-vault-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore())
        let vault = root.appendingPathComponent("Vault")
        let client = try archive.createClient(name: "Poldo S.p.A.")
        let portale = try archive.createProject(name: "Portale")
        let privato = try archive.createProject(name: "Privato")
        try archive.setProjectClient(portale.id, client.id)
        let t0 = Date(timeIntervalSince1970: 1_791_000_000)
        let call = try archive.createItem(
            title: "Kickoff: fase 1", occurredAt: t0, source: .recording, status: .recorded)
        try archive.updateItem(call.id) { $0.projectId = portale.id }
        let secret = try archive.createItem(title: "Segreto", occurredAt: t0, source: .recording, status: .recorded)
        try archive.updateItem(secret.id) { $0.projectId = privato.id }
        try archive.createDecision(
            Decision(
                text: "Go-live ad aprile", decidedAt: t0, projectId: portale.id, sourceItemId: call.id, origin: .manual),
            people: ["Mario Rossi"])
        try archive.addNote(itemID: nil, projectID: portale.id, body: "Cambio referente", notedAt: t0)

        // A note of the user in the IAGO folder, with the same name IAGO would use: left alone.
        let mine = vault.appendingPathComponent("IAGO/Progetti/Portale.md")
        try FileManager.default.createDirectory(at: mine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "le mie note".write(to: mine, atomically: true, encoding: .utf8)
        let other = vault.appendingPathComponent("Diario.md")
        try "privato".write(to: other, atomically: true, encoding: .utf8)

        let first = try ObsidianMirror.sync(archive: archive, vault: vault, projectIDs: [portale.id], timeZone: utc)
        let base = vault.appendingPathComponent("IAGO")
        let callFile = base.appendingPathComponent("Portale/2026-10-03 0400 Kickoff- fase 1.md")
        let callText = try String(contentsOf: callFile, encoding: .utf8)
        #expect(callText.hasPrefix("---\niago_id: \(call.id)"))
        #expect(callText.contains("Progetto: [[Portale]] · Cliente: [[Poldo S.p.A.]]"))
        #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("Clienti/Poldo S.p.A..md").path))
        #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("Persone/Mario Rossi.md").path))
        let decisionText = try String(
            contentsOf: base.appendingPathComponent("Portale/Decisioni/2026-10-03 Go-live ad aprile.md"),
            encoding: .utf8)
        #expect(decisionText.contains("Persone: [[Mario Rossi]]"))
        #expect(decisionText.contains("Fonte: [[2026-10-03 0400 Kickoff- fase 1|Kickoff: fase 1]]"))
        #expect(!FileManager.default.fileExists(atPath: base.appendingPathComponent("Privato").path))  // not enabled
        #expect(try String(contentsOf: mine, encoding: .utf8) == "le mie note")
        #expect(first.written > 0)

        // Nothing changed: nothing rewritten. Item deleted: its file goes, the user's notes stay.
        #expect(
            try ObsidianMirror.sync(archive: archive, vault: vault, projectIDs: [portale.id], timeZone: utc).written
                == 0)
        try archive.purgeItem(call.id)
        let third = try ObsidianMirror.sync(archive: archive, vault: vault, projectIDs: [portale.id], timeZone: utc)
        #expect(third.removed >= 1)
        #expect(!FileManager.default.fileExists(atPath: callFile.path))
        #expect(try String(contentsOf: other, encoding: .utf8) == "privato")
        #expect(try String(contentsOf: mine, encoding: .utf8) == "le mie note")
    }
}
