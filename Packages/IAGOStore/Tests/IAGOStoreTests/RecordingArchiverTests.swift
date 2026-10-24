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
