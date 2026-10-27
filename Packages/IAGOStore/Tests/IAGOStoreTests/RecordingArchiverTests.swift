import Foundation
import IAGOCore
import Testing

@testable import IAGOStore

@Suite struct RecordingArchiverTests {
    func finalizedFolder(in fixture: ArchiveFixture, id: ItemID, tracks: [String], title: String? = nil) throws -> URL {
        let folder = fixture.root.appendingPathComponent("finalized/\(id.rawValue)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var manifest = SessionManifest(itemID: id, startedAt: fixture.clock.now, sampleRate: 48_000)
        manifest.state = .finalized
        manifest.duration = 42
        manifest.markers = [
            .init(kind: .pause, at: 10), .init(kind: .resume, at: 10),
            .init(kind: .bookmark, at: 12, detail: "budget approvato"), .init(kind: .bookmark, at: 30),
        ]
        manifest.devices = [.mic: ["MacBook Pro Microphone"]]
        manifest.suggestedTitle = title
        try manifest.encoded().write(to: folder.appendingPathComponent("session.json"))
        for track in tracks { try Data("audio \(track)".utf8).write(to: folder.appendingPathComponent(track)) }
        return folder
    }

    @Test func theMeetingTitleBecomesTheItemTitle() throws {
        let fixture = try ArchiveFixture()
        let folder = try finalizedFolder(in: fixture, id: ItemID.generate(), tracks: ["mic.m4a"], title: "igo test 2")
        #expect(try RecordingArchiver(archive: fixture.archive).archive(folder: folder).title == "igo test 2")
    }

    @Test func archivesTracksMarkersAndMetadata() throws {
        let fixture = try ArchiveFixture()
        let id = ItemID.generate()
        let folder = try finalizedFolder(in: fixture, id: id, tracks: ["mic.m4a", "system.m4a", "mix.m4a"])
        #expect(
            RecordingArchiver.pendingFolders(in: folder.deletingLastPathComponent()).map(\.lastPathComponent) == [
                id.rawValue
            ])

        let item = try RecordingArchiver(archive: fixture.archive).archive(folder: folder)

        #expect(item.id == id.rawValue)
        #expect(item.title == ItemTitle.unclassified(startedAt: fixture.clock.now))
        #expect(item.durationSec == 42 && item.source == .recording && item.status == .recorded)
        #expect(item.captureMeta?.contains("MacBook Pro Microphone") == true)
        #expect(item.captureMeta?.contains("bookmark") == false)
        #expect(try fixture.archive.markers(itemID: item.id).map(\.note) == ["budget approvato", nil])
        let assets = try fixture.archive.assets(itemID: item.id)
        #expect(Set(assets.map(\.kind)) == [.audioMic, .audioSystem, .audioMix])
        let mic = assets.first { $0.kind == .audioMic }!
        #expect(try fixture.archive.readAssetData(mic) == Data("audio mic.m4a".utf8))
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    /// ADR-0072: screenshots of the session become encrypted files of the call, with minute and text, searchable.
    @Test func screenshotsJoinTheCall() throws {
        let fixture = try ArchiveFixture()
        let id = ItemID.generate()
        let folder = try finalizedFolder(in: fixture, id: id, tracks: ["mic.m4a"])
        var manifest = try SessionManifest.decode(from: Data(contentsOf: folder.appendingPathComponent("session.json")))
        manifest.markers.append(.init(kind: .screenshot, at: 25, detail: "screenshot-1.png"))
        manifest.markers.append(.init(kind: .screenshot, at: 8, detail: "screenshot-2.png"))
        try manifest.encoded().write(to: folder.appendingPathComponent("session.json"))
        try Data("png one".utf8).write(to: folder.appendingPathComponent("screenshot-1.png"))
        try Data("Roadmap del portale\nRilascio a novembre".utf8).write(
            to: folder.appendingPathComponent("screenshot-1.txt"))
        try Data("png two".utf8).write(to: folder.appendingPathComponent("screenshot-2.png"))

        let item = try RecordingArchiver(archive: fixture.archive).archive(folder: folder)
        let shots = try fixture.archive.screenshots(itemID: item.id)
        #expect(shots.map(\.atSec) == [8, 25])
        #expect(shots[1].text == "Roadmap del portale\nRilascio a novembre")
        #expect(shots[1].originalName == "Schermata 00:25.png")
        #expect(try fixture.archive.readAssetData(shots[1]) == Data("png one".utf8))
        // Not among the files of the call, and not in the capture metadata.
        #expect(try fixture.archive.assets(itemID: item.id).map(\.kind) == [.audioMic])
        #expect(item.captureMeta?.contains("screenshot") == false)
        // The text read on the slide is found by the search, at its minute.
        let hits = try fixture.archive.search("roadmap")
        #expect(hits.first?.itemID == item.id && hits.first?.atSec == 25)

        try fixture.archive.deleteScreenshot(shots[0].id)
        #expect(try fixture.archive.screenshots(itemID: item.id).count == 1)
    }

    @Test func resumesAfterInterruptedArchiving() throws {
        let fixture = try ArchiveFixture()
        let id = ItemID.generate()
        let folder = try finalizedFolder(in: fixture, id: id, tracks: ["mic.m4a", "system.m4a"])
        // First run "crashed" after the item and one track were stored.
        try fixture.archive.createItem(
            id: id.rawValue, title: "x", occurredAt: fixture.clock.now, source: .recording, status: .recorded)
        try fixture.archive.addMarker(itemID: id.rawValue, atSec: 12, note: "budget approvato")
        try fixture.archive.storeAsset(
            folder.appendingPathComponent("mic.m4a"), itemID: id.rawValue, kind: .audioMic, fileName: "mic.m4a")

        try RecordingArchiver(archive: fixture.archive).archive(folder: folder)

        #expect(try fixture.archive.markers(itemID: id.rawValue).count == 1)
        #expect(try fixture.archive.assets(itemID: id.rawValue).count == 2)
        #expect(try fixture.archive.items().count == 1)
    }

    @Test func importedAudioIsOneEncryptedTrack() throws {
        let fixture = try ArchiveFixture()
        let converted = try fixture.plainFile("converted audio")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let item = try fixture.archive.importAudio(converted, title: "Intervista", occurredAt: date, durationSec: 61)
        #expect(item.source == .import && item.title == "Intervista" && item.occurredAt == date)
        #expect(try fixture.archive.assets(itemID: item.id).map(\.kind) == [.audioImport])
    }
}
