import Foundation
import Testing

@testable import IAGOStore

@Suite struct WatchedFoldersTests {
    @Test func foldersRegisterAndRules() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let folder = try archive.addWatchedFolder(path: "/Users/x/OneDrive/IAGO")
        try archive.addWatchedFolder(path: "/Users/x/OneDrive/IAGO")  // the same path once
        #expect(try archive.watchedFolders().count == 1)
        try archive.updateWatchedFolder(folder.id) { $0.moveImported = true }
        #expect(try archive.watchedFolders().first?.moveImported == true)

        let file = WatchedFile(
            path: "/Users/x/OneDrive/IAGO/a.eml", folderId: folder.id, size: 10,
            modifiedAt: Date(timeIntervalSince1970: 5),
            sha256: "abc", outcome: .imported, subject: "Modulo", itemId: "i1")
        try archive.recordWatchedFile(file)
        #expect(try archive.watchedFile(file.path)?.itemId == "i1")
        #expect(try archive.watchedContentSeen(sha256: "abc", except: "/other.eml"))
        #expect(try !archive.watchedContentSeen(sha256: "abc", except: file.path))
        try archive.recordWatchedFile(
            WatchedFile(
                path: "/Users/x/OneDrive/IAGO/b.eml", folderId: folder.id, size: 3, modifiedAt: Date(), sha256: "def",
                outcome: .excluded, reason: "Invito o risposta a un meeting"))
        #expect(try archive.discardedWatchedFiles().map(\.reason) == ["Invito o risposta a un meeting"])
        try archive.moveWatchedFile(from: file.path, to: "/Users/x/OneDrive/IAGO/Importate/a.eml")
        #expect(try archive.watchedFile("/Users/x/OneDrive/IAGO/Importate/a.eml")?.sha256 == "abc")

        try archive.setImportRules([("r2", "{\"b\":1}"), ("r1", "{\"a\":1}")])
        #expect(try archive.importRules().map(\.id) == ["r2", "r1"])
        try archive.removeWatchedFolder(folder.id)
        #expect(try archive.watchedFolders().isEmpty && archive.discardedWatchedFiles().isEmpty)
    }
}
