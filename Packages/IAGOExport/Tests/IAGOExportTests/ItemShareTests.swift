import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOExport

@Suite struct ItemShareTests {
    let utc = TimeZone(identifier: "UTC")!

    @Test func writesOnlyThePartsChosen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-share-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore())
        let project = try archive.createProject(name: "Portale")
        let call = try archive.createItem(
            title: "Kickoff", occurredAt: Date(timeIntervalSince1970: 1_791_000_000), source: .recording,
            status: .transcribed, durationSec: 600)
        _ = try archive.updateItem(call.id) { $0.projectId = project.id }
        let transcript = Transcript(
            itemId: call.id, engine: .init(asr: "whisper.cpp", model: "turbo"), language: "it",
            speakers: [.me(), .init(id: "s1", label: "Speaker 1", source: .system)],
            segments: [.init(id: 1, speaker: "s1", start: 5, end: 8, text: "Partiamo dal design system.")])
        try archive.storeAsset(
            transcript.encoded(), itemID: call.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.setSpeakers([("s1", "Anna Prova")], for: call.id)
        try archive.storeAsset(Data("audio".utf8), itemID: call.id, kind: .audioMix, fileName: "mix.m4a")
        _ = try archive.createDecision(
            Decision(
                text: "Design system condiviso", decidedAt: call.occurredAt, projectId: project.id,
                sourceItemId: call.id, sourceAtSec: 5, origin: .manual))
        try archive.saveSummary(
            itemID: call.id, categoryID: nil, templateID: nil, markdown: "## Punti\n\n- Avvio", model: "test")

        #expect(try ItemShare.available(call.id, archive: archive) == [.card, .transcript, .audio])

        let folder = root.appendingPathComponent("out")
        let files = try ItemShare.write(
            [.card, .transcript], itemID: call.id, archive: archive, to: folder, timeZone: utc)
        #expect(
            files.map(\.lastPathComponent) == [
                "2026-10-03 0400 Kickoff.md", "2026-10-03 0400 Kickoff - trascrizione.md",
            ])
        let card = try String(contentsOf: files[0], encoding: .utf8)
        #expect(card.contains("## Sintesi"))
        #expect(card.contains("Design system condiviso"))
        #expect(!card.contains("Partiamo dal design system"))
        let text = try String(contentsOf: files[1], encoding: .utf8)
        #expect(text.contains("Anna Prova:** Partiamo dal design system."))

        let audio = try ItemShare.write([.audio], itemID: call.id, archive: archive, to: folder, timeZone: utc)
        #expect(try Data(contentsOf: audio[0]) == Data("audio".utf8))
        let zip = try ItemShare.zip(folder)
        #expect(zip.lastPathComponent == "out.zip")
        #expect(FileManager.default.fileExists(atPath: zip.path))
    }
}
