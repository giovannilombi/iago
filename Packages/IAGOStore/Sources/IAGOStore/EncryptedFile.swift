import CryptoKit
import Foundation

/// Chunked AES-GCM file format (ADR-0027). Files are encrypted and decrypted as streams, so an hour of
/// audio never sits in memory.
///
///     header:  "IAGOENC" | format version (1 byte) | chunk size (UInt32 BE)
///     chunks:  nonce (12) | ciphertext (≤ chunk size) | tag (16)
///
/// Each chunk authenticates the header, a caller-chosen context (e.g. `<itemId>/mic.m4a`), its index
/// and whether it is the last one: swapping files or chunks, truncating at a chunk boundary or
/// appending chunks all fail to decrypt. An empty file is one empty final chunk.
public enum EncryptedFile {
    static let magic = Data("IAGOENC".utf8)
    static let formatVersion: UInt8 = 1
    public static let defaultChunkSize = 1 << 20
    static let overhead = 12 + 16

    public enum Error: Swift.Error, Sendable, Equatable {
        case badHeader
        case authenticationFailed(chunk: Int)
        case truncated
    }

    public struct Result: Sendable, Equatable {
        /// Plaintext size in bytes.
        public var size: Int64
        /// SHA-256 of the plaintext, lowercase hex.
        public var sha256: String
    }

    /// Encrypts `source` into `destination` (written to a temporary file, then moved into place).
    @discardableResult
    public static func encrypt(
        _ source: URL, to destination: URL, key: SymmetricKey, context: String, chunkSize: Int = defaultChunkSize
    ) throws -> Result {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        return try writeAtomically(destination) { output in
            var header = magic
            header.append(formatVersion)
            withUnsafeBytes(of: UInt32(chunkSize).bigEndian) { header.append(contentsOf: $0) }
            try output.write(contentsOf: header)

            var hasher = SHA256()
            var size: Int64 = 0
            var index: UInt64 = 0
            var chunk = try input.read(upToCount: chunkSize) ?? Data()
            while true {
                let next = chunk.count == chunkSize ? (try input.read(upToCount: chunkSize) ?? Data()) : Data()
                let isLast = next.isEmpty
                hasher.update(data: chunk)
                size += Int64(chunk.count)
                let sealed = try AES.GCM.seal(
                    chunk, using: key,
                    authenticating: aad(header: header, context: context, index: index, isLast: isLast))
                try output.write(contentsOf: sealed.combined!)
                if isLast { break }
                chunk = next
                index += 1
            }
            return Result(size: size, sha256: hex(hasher.finalize()))
        }
    }

    /// Decrypts `source` into `destination`, verifying every chunk.
    @discardableResult
    public static func decrypt(_ source: URL, to destination: URL, key: SymmetricKey, context: String) throws -> Result
    {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        return try writeAtomically(destination) { output in
            try decryptChunks(input, key: key, context: context) { try output.write(contentsOf: $0) }
        }
    }

    /// Encrypts small contents (e.g. `transcript.json`) held in memory.
    @discardableResult
    public static func encrypt(_ data: Data, to destination: URL, key: SymmetricKey, context: String) throws -> Result {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID().uuidString)")
        try data.write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        return try encrypt(temporary, to: destination, key: key, context: context)
    }

    /// Decrypts a file into memory.
    public static func decryptData(_ source: URL, key: SymmetricKey, context: String) throws -> Data {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var data = Data()
        _ = try decryptChunks(input, key: key, context: context) { data.append($0) }
        return data
    }

    private static func decryptChunks(
        _ input: FileHandle, key: SymmetricKey, context: String, sink: (Data) throws -> Void
    ) throws -> Result {
        let header = try input.read(upToCount: magic.count + 5) ?? Data()
        guard header.count == magic.count + 5, header.prefix(magic.count) == magic,
            header[header.startIndex + magic.count] == formatVersion
        else { throw Error.badHeader }
        let chunkSize = Int(header.suffix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        guard chunkSize > 0 else { throw Error.badHeader }

        var hasher = SHA256()
        var size: Int64 = 0
        var index: UInt64 = 0
        var sealed = try input.read(upToCount: chunkSize + overhead) ?? Data()
        while true {
            guard sealed.count >= overhead else { throw Error.truncated }
            let next =
                sealed.count == chunkSize + overhead
                ? (try input.read(upToCount: chunkSize + overhead) ?? Data()) : Data()
            let isLast = next.isEmpty
            let plain: Data
            do {
                plain = try AES.GCM.open(
                    AES.GCM.SealedBox(combined: sealed), using: key,
                    authenticating: aad(header: header, context: context, index: index, isLast: isLast))
            } catch {
                throw Error.authenticationFailed(chunk: Int(index))
            }
            hasher.update(data: plain)
            size += Int64(plain.count)
            try sink(plain)
            if isLast { break }
            sealed = next
            index += 1
        }
        return Result(size: size, sha256: hex(hasher.finalize()))
    }

    private static func aad(header: Data, context: String, index: UInt64, isLast: Bool) -> Data {
        var data = header
        data.append(Data(context.utf8))
        withUnsafeBytes(of: index.bigEndian) { data.append(contentsOf: $0) }
        data.append(isLast ? 1 : 0)
        return data
    }

    private static func writeAtomically(_ destination: URL, _ body: (FileHandle) throws -> Result) throws -> Result {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: temporary.path])
        }
        do {
            let output = try FileHandle(forWritingTo: temporary)
            let result = try body(output)
            try output.synchronize()
            try output.close()
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
            return result
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
