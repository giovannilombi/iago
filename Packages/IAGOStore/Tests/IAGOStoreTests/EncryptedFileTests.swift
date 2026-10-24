import CryptoKit
import Foundation
import Testing

@testable import IAGOStore

@Suite struct EncryptedFileTests {
    let key = SymmetricKey(size: .bits256)
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("iago-enc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func file(_ name: String, _ data: Data) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func roundTrip(_ data: Data, chunkSize: Int) throws -> Data {
        let source = try file("plain", data)
        let encrypted = directory.appendingPathComponent("plain.enc")
        let written = try EncryptedFile.encrypt(source, to: encrypted, key: key, context: "a/mic", chunkSize: chunkSize)
        let restored = directory.appendingPathComponent("restored")
        let read = try EncryptedFile.decrypt(encrypted, to: restored, key: key, context: "a/mic")
        #expect(written == read)
        #expect(written.size == Int64(data.count))
        #expect(written.sha256 == EncryptedFile.hex(SHA256.hash(data: data)))
        return try Data(contentsOf: restored)
    }

    @Test(arguments: [0, 1, 15, 16, 17, 64, 100])
    func roundTripsAnySize(size: Int) throws {
        let data = Data((0..<size).map { UInt8($0 % 251) })
        #expect(try roundTrip(data, chunkSize: 16) == data)
    }

    @Test func ciphertextDoesNotContainPlaintext() throws {
        let data = Data(String(repeating: "riservato ", count: 50).utf8)
        let encrypted = directory.appendingPathComponent("x.enc")
        try EncryptedFile.encrypt(data, to: encrypted, key: key, context: "a/t")
        let raw = try Data(contentsOf: encrypted)
        #expect(raw.range(of: Data("riservato".utf8)) == nil)
    }

    func encrypted(_ size: Int, chunkSize: Int = 16) throws -> URL {
        let source = try file("p\(size)", Data(repeating: 7, count: size))
        let url = directory.appendingPathComponent("p\(size).enc")
        try EncryptedFile.encrypt(source, to: url, key: key, context: "a/mic", chunkSize: chunkSize)
        return url
    }

    @Test func rejectsTamperedByte() throws {
        let url = try encrypted(40)
        var raw = try Data(contentsOf: url)
        raw[raw.count / 2] ^= 0x01
        try raw.write(to: url)
        #expect(throws: EncryptedFile.Error.self) { try EncryptedFile.decryptData(url, key: key, context: "a/mic") }
    }

    @Test func rejectsTruncationAtChunkBoundary() throws {
        let url = try encrypted(40)  // chunks of 16 + 16 + 8
        let raw = try Data(contentsOf: url)
        try raw.prefix(12 + 2 * (16 + 28)).write(to: url)
        #expect(throws: EncryptedFile.Error.authenticationFailed(chunk: 1)) {
            try EncryptedFile.decryptData(url, key: key, context: "a/mic")
        }
    }

    @Test func rejectsWrongContextOrKey() throws {
        let url = try encrypted(20)
        #expect(throws: EncryptedFile.Error.self) { try EncryptedFile.decryptData(url, key: key, context: "a/system") }
        #expect(throws: EncryptedFile.Error.self) {
            try EncryptedFile.decryptData(url, key: SymmetricKey(size: .bits256), context: "a/mic")
        }
    }

    @Test func rejectsForeignFile() throws {
        let url = try file("junk.enc", Data("not encrypted".utf8))
        #expect(throws: EncryptedFile.Error.badHeader) {
            try EncryptedFile.decryptData(url, key: key, context: "a/mic")
        }
    }

    @Test func failedDecryptionLeavesNoOutput() throws {
        let url = try encrypted(40)
        let destination = directory.appendingPathComponent("out")
        #expect(throws: (any Error).self) {
            try EncryptedFile.decrypt(url, to: destination, key: key, context: "other")
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
