import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOExport

@Suite struct ProjectExporterTests {
    let utc = TimeZone(identifier: "UTC")!

    func archive() throws -> (Archive, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-export-\(UUID().uuidString)")
        let archive = try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore())
        return (archive, root)
    }

    @Test func projectExportHasIndexDecisionsAndChronologicalTypedEntries() throws {
        let (archive, root) = try archive()
        let project = try archive.createProject(name: "Portale")
        let t0 = Date(timeIntervalSince1970: 1_791_000_000)  // 2026-10-03

        let call = try archive.createItem(
            title: "Kickoff", occurredAt: t0, source: .recording, status: .transcribed, durationSec: 600)
        let transcript = Transcript(
            itemId: call.id, engine: .init(asr: "whisper.cpp", model: "turbo"), language: "it",
            speakers: [.me(), .init(id: "s1", label: "Speaker 1", source: .system)],
            segments: [
                .init(id: 1, speaker: "s1", start: 5, end: 8, text: "Partiamo dal design system."),
                .init(id: 2, speaker: "me", start: 9, end: 12, text: "D'accordo."),
            ])
        try archive.storeAsset(
            transcript.encoded(), itemID: call.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.setSpeakers([("s1", "Mario Rossi")], for: call.id)
        try archive.addNote(itemID: call.id, body: "Richiamare Mario", notedAt: t0.addingTimeInterval(3_600))

        let email = try archive.importEmail(
            EmailInput(
                from: .init(name: "Mario Rossi", address: "mario@poldo.it"),
                to: [.init(name: "Io", address: "io@studio.it")], subject: "Offerta",
                sentAt: t0.addingTimeInterval(86_400), messageID: "m1@x", bodyMarkdown: "Prezzo 12.000 euro."),
            original: nil)
        let source = root.appendingPathComponent("doc.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: source)
        let document = try archive.importDocument(
            source, isImage: false, markdown: "# Capitolato\n\n" + String(repeating: "Requisito tecnico. ", count: 50),
            title: "Capitolato", occurredAt: t0.addingTimeInterval(2 * 86_400))
        try archive.addLink(from: document.id, to: email.id, kind: .attachmentOf, origin: .attachment)
        for id in [call.id, email.id, document.id] { try archive.updateItem(id) { $0.projectId = project.id } }
        try archive.addNote(
            itemID: nil, projectID: project.id, body: "Cambio referente", notedAt: t0.addingTimeInterval(36_000))

        let first = try archive.createDecision(
            Decision(
                text: "Go-live a marzo", decidedAt: t0, projectId: project.id, sourceItemId: call.id,
                sourceAtSec: 5, origin: .selection), people: ["Mario Rossi"])
        try archive.createDecision(
            Decision(
                text: "Go-live ad aprile", decidedAt: t0.addingTimeInterval(86_400), projectId: project.id,
                supersedesId: first.id, origin: .manual, notes: "Ritardo fornitore"))

        let options = ProjectExporter.Options(
            title: "Portale", itemIDs: [document.id, email.id, call.id], projectNoteIDs: [project.id],
            decisionScope: .project(project.id), documents: .excerpt(120))
        let md = try ProjectExporter.markdown(
            options, archive: archive, now: t0.addingTimeInterval(10 * 86_400), timeZone: utc)

        #expect(md.hasPrefix("---\nproject: \"Portale\"\nexported_at: 2026-10-13T"))
        #expect(md.contains("items: 3"))
        #expect(
            md.contains(
                "## Indice\n\n1. 2026-10-03 · Call · Kickoff\n2. 2026-10-03 · Nota di progetto · Portale\n3. 2026-10-04 · Email ricevuta · Da: Mario Rossi · Oggetto: Offerta\n4. 2026-10-05 · Documento · Capitolato"
            ))
        #expect(
            md.contains(
                "- **[Superata] 2026-10-03** Go-live a marzo — fonte: Kickoff @ 00:00:05; persone: Mario Rossi; superata da: «Go-live ad aprile»"
            ))
        #expect(
            md.contains(
                "- **[Attiva] 2026-10-04** Go-live ad aprile — supera: «Go-live a marzo»\n  > Ritardo fornitore"))
        #expect(md.contains("**[00:00:05] Mario Rossi:** Partiamo dal design system."))
        #expect(md.contains("### Note\n\n**2026-10-03 "))
        #expect(md.contains("### Messaggio"))
        #expect(md.contains("Prezzo 12.000 euro."))
        #expect(md.contains("Allegati: Capitolato"))
        #expect(md.contains("_(estratto: documento completo in IAGO, «Capitolato»)_"))
        // Chronological order of the sections.
        let order = ["## 1. 2026-10-03", "## 2. 2026-10-03", "## 3. 2026-10-04", "## 4. 2026-10-05"].map {
            md.range(of: $0)!.lowerBound
        }
        #expect(order == order.sorted())
        #expect(ProjectExporter.estimatedTokens(md) > 100)
    }
}
