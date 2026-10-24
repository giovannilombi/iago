import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOExport

@Suite struct TranscriptRendererTests {
    let utc = TimeZone(identifier: "UTC")!
    let start = Date(timeIntervalSince1970: 1_791_969_000)  // 2026-10-14 09:10 UTC

    func document(notes: [Note] = [], transcript: Bool = true) -> ItemDocument {
        let item = Item(
            id: "0192", title: "Kickoff: portale clienti", occurredAt: start, durationSec: 3130, source: .recording,
            status: .transcribed)
        let t = Transcript(
            itemId: "0192", engine: .init(asr: "whisper.cpp", model: "large-v3-turbo"), language: "it",
            speakers: [
                .me(), .init(id: "s1", label: "Speaker 1", source: .system),
                .init(id: "s2", label: "Speaker 2", source: .system),
            ],
            segments: [
                .init(id: 1, speaker: "s1", start: 12.4, end: 18, text: "Iniziamo."),
                .init(id: 2, speaker: "me", start: 31, end: 33, text: "Va bene."),
                .init(id: 3, speaker: "s2", start: 3725, end: 3727, text: "Ultima cosa."),
            ])
        return ItemDocument(
            item: item, projectName: "Progetto Alfa", categoryName: "Kickoff", tags: ["design-system", "roadmap"],
            speakerLabels: ["s1": "Mario Rossi", "me": "Io"], notes: notes, transcript: transcript ? t : nil)
    }

    func note(_ body: String, at offset: Double, kind: Note.Kind = .note) -> Note {
        Note(id: body, itemId: "0192", kind: kind, body: body, notedAt: start.addingTimeInterval(offset))
    }

    @Test func markdownFollowsSpec() {
        let md = TranscriptRenderer.markdown(document(), timeZone: utc)
        #expect(
            md == """
                ---
                iago_id: 0192
                title: "Kickoff: portale clienti"
                date: 2026-10-14T09:10
                duration: 00:52:10
                project: "Progetto Alfa"
                category: "Kickoff"
                tags: ["design-system", "roadmap"]
                participants: ["Mario Rossi", "Io", "Speaker 2"]
                engine: "whisper.cpp large-v3-turbo"
                ---

                # Kickoff: portale clienti

                **Data:** 14/10/2026 09:10 · **Durata:** 52 min · **Progetto:** Progetto Alfa · **Categoria:** Kickoff

                ## Trascrizione

                **[00:00:12] Mario Rossi:** Iniziamo.
                **[00:00:31] Io:** Va bene.
                **[01:02:05] Speaker 2:** Ultima cosa.

                """)
    }

    @Test func addendumListsNotesInOrder() {
        let notes = [note("prima", at: 3600), note("aggiornamento", at: 86_400, kind: .email)]
        let md = TranscriptRenderer.markdown(document(notes: notes), timeZone: utc)
        #expect(
            md.hasSuffix(
                "## Addendum\n\n### 2026-10-14 10:10 · Nota\n\nprima\n\n### 2026-10-15 09:10 · Email\n\naggiornamento\n"
            ))
    }

    @Test func textHasOneLinePerSegment() {
        let txt = TranscriptRenderer.text(document(notes: [note("x", at: 0)]), timeZone: utc)
        #expect(txt.contains("\n[00:00:12] Mario Rossi: Iniziamo.\n[00:00:31] Io: Va bene.\n"))
        #expect(txt.contains("Tag: design-system, roadmap"))
        #expect(!txt.contains("**"))
        #expect(txt.hasSuffix("Addendum\n\n2026-10-14 09:10 · Nota\nx\n"))
    }

    @Test func audioOnlyItemSaysSo() {
        let md = TranscriptRenderer.markdown(document(transcript: false), timeZone: utc)
        #expect(md.contains("solo audio"))
        #expect(!md.contains("participants"))
    }
}
