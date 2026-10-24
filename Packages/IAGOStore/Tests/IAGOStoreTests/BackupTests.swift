import CryptoKit
import Foundation
import Testing

@testable import IAGOStore

@Suite struct BackupTests {
    @Test func backupRestoresTheSameArchiveOnAnotherMac() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-backup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let key = SymmetricKey(size: .bits256)
        let source = root.appendingPathComponent("mac-a")
        let database = try AppDatabase.open(at: source.appendingPathComponent("iago.sqlite"))
        let archive = try Archive(
            database: database, itemsRoot: source.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore(key: key))
        let project = try archive.createProject(name: "Portale")
        let item = try archive.createItem(
            title: "Kickoff", occurredAt: Date(), source: .recording, status: .recorded)
        try archive.updateItem(item.id) { $0.projectId = project.id }
        let audio = try archive.storeAsset(
            Data("audio segreto".utf8), itemID: item.id, kind: .audioMix, fileName: "mix.m4a")
        try archive.addNote(itemID: item.id, body: "Nota importante")

        let file = root.appendingPathComponent("prova.iagobackup")
        #expect(throws: Backup.BackupError.passwordTooShort) {
            try Backup.create(
                archive: archive, masterKey: key, password: "corta", to: file,
                staging: root.appendingPathComponent("staging"))
        }
        let manifest = try Backup.create(
            archive: archive, masterKey: key, password: "una password lunga", to: file,
            staging: root.appendingPathComponent("staging"))
        #expect(manifest.items == 1)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("staging").path))
        let raw = try Data(contentsOf: file)
        #expect(!raw.isEmpty)
        #expect(raw.range(of: Data("Nota importante".utf8)) == nil)  // nothing readable without the password

        // Wrong password.
        #expect(throws: Backup.BackupError.wrongPasswordOrDamaged) {
            try Backup.extract(file, password: "password sbagliata", to: root.appendingPathComponent("bad"))
        }

        // "Another Mac": unpack, install in an empty place, open with the key from the backup.
        let pending = root.appendingPathComponent("restore-pending")
        #expect(try Backup.extract(file, password: "una password lunga", to: pending) == manifest)
        let restoredKey = try Backup.masterKey(in: pending)
        #expect(restoredKey.withUnsafeBytes { Data($0) } == key.withUnsafeBytes { Data($0) })
        let target = root.appendingPathComponent("mac-b")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Backup.install(
            from: pending, database: target.appendingPathComponent("iago.sqlite"),
            items: target.appendingPathComponent("Items"), previous: target.appendingPathComponent("previous"))
        let restored = try Archive(
            database: try AppDatabase.open(at: target.appendingPathComponent("iago.sqlite")),
            itemsRoot: target.appendingPathComponent("Items"), keyStore: EphemeralMasterKeyStore(key: restoredKey))
        #expect(try restored.items().map(\.title) == ["Kickoff"])
        #expect(try restored.projects().map(\.name) == ["Portale"])
        #expect(try restored.notes(itemID: item.id).map(\.body) == ["Nota importante"])
        let asset = try #require(try restored.assets(itemID: item.id).first { $0.id == audio.id })
        #expect(String(decoding: try restored.readAssetData(asset), as: UTF8.self) == "audio segreto")
    }
}
