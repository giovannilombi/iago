import Foundation

/// Minimal incremental writer for mono Float32 CAF files.
///
/// The data chunk size stays at -1 ("unknown, last chunk") while recording, so whatever reached the
/// disk is a valid file even after a crash; `repairHeader` patches the real size during recovery.
final class CAFFileWriter {
    static let headerSize: UInt64 = 68
    private static let dataSizeOffset: UInt64 = 56

    let url: URL
    private let handle: FileHandle
    private(set) var framesWritten: Int64 = 0

    init(url: URL, sampleRate: Double) throws {
        self.url = url
        guard FileManager.default.createFile(atPath: url.path, contents: Self.header(sampleRate: sampleRate)) else {
            throw CaptureError.fileSystem("Cannot create \(url.lastPathComponent)")
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    func append(_ samples: [Float]) throws {
        guard !samples.isEmpty else { return }
        try samples.withUnsafeBytes { try handle.write(contentsOf: $0) }
        framesWritten += Int64(samples.count)
    }

    /// Forces written data to stable storage (power loss safety, spec 6.5).
    func synchronize() throws {
        try handle.synchronize()
    }

    func close() throws {
        try handle.synchronize()
        try handle.seek(toOffset: Self.dataSizeOffset)
        try handle.write(contentsOf: Self.bigEndian(Int64(4 + framesWritten * 4)))
        try handle.close()
    }

    /// Fixes the data chunk size of a file left open by a crash and drops a trailing partial sample.
    /// Returns the number of frames in the file.
    @discardableResult
    /// Appends silence to a repaired file until it holds `frames` frames; returns the new frame count.
    static func padWithSilence(at url: URL, toFrames frames: Int64) throws -> Int64 {
        let current = try repairHeader(at: url)
        guard frames > current else { return current }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        var missing = frames - current
        let chunk = Data(count: 48_000 * 4)
        while missing > 0 {
            let count = Int(min(missing, 48_000))
            try handle.write(contentsOf: chunk.prefix(count * 4))
            missing -= Int64(count)
        }
        try handle.close()
        return try repairHeader(at: url)
    }

    static func repairHeader(at url: URL) throws -> Int64 {
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let length = try handle.seekToEnd()
        guard length >= headerSize else {
            throw CaptureError.fileSystem("Truncated CAF header: \(url.lastPathComponent)")
        }
        let frames = Int64((length - headerSize) / 4)
        let validLength = headerSize + UInt64(frames) * 4
        if validLength != length {
            try handle.truncate(atOffset: validLength)
        }
        try handle.seek(toOffset: dataSizeOffset)
        try handle.write(contentsOf: bigEndian(Int64(4 + frames * 4)))
        try handle.synchronize()
        return frames
    }

    private static func header(sampleRate: Double) -> Data {
        var data = Data()
        data.append(contentsOf: Array("caff".utf8))
        data.append(bigEndian(UInt16(1)))  // file version
        data.append(bigEndian(UInt16(0)))  // file flags
        data.append(contentsOf: Array("desc".utf8))
        data.append(bigEndian(Int64(32)))
        data.append(bigEndian(sampleRate.bitPattern))
        data.append(contentsOf: Array("lpcm".utf8))
        data.append(bigEndian(UInt32(3)))  // float | little endian
        data.append(bigEndian(UInt32(4)))  // bytes per packet
        data.append(bigEndian(UInt32(1)))  // frames per packet
        data.append(bigEndian(UInt32(1)))  // channels
        data.append(bigEndian(UInt32(32)))  // bits per channel
        data.append(contentsOf: Array("data".utf8))
        data.append(bigEndian(Int64(-1)))
        data.append(bigEndian(UInt32(0)))  // edit count
        assert(UInt64(data.count) == headerSize)
        return data
    }

    private static func bigEndian<T: FixedWidthInteger>(_ value: T) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}
