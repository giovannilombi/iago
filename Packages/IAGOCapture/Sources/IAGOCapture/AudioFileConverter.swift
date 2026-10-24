@preconcurrency import AVFoundation
import Foundation

/// Converts any audio or video file AVFoundation can read (FR-30) to an AAC `.m4a` for the archive.
public enum AudioFileConverter {
    public struct Output: Sendable {
        public var file: URL
        public var duration: Double
    }

    public enum ConversionError: Error, Sendable, CustomStringConvertible {
        case noAudioTrack(String)
        case exportFailed(String)

        public var description: String {
            switch self {
            case .noAudioTrack(let name): "\(name) has no audio track"
            case .exportFailed(let message): "Conversion failed: \(message)"
            }
        }
    }

    public static func convertToM4A(_ source: URL, destination: URL) async throws -> Output {
        // AVFoundation picks the reader from the file extension: a file with the wrong one (e.g. a
        // WhatsApp voice note saved as .mp3 that is really MP4) is read through a correctly named link.
        var input = source
        var link: URL?
        if let actual = sniffedExtension(of: source), actual != source.pathExtension.lowercased() {
            let url = destination.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).\(actual)")
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: source)
            input = url
            link = url
        }
        defer { if let link { try? FileManager.default.removeItem(at: link) } }
        return try await export(input, displayName: source.lastPathComponent, destination: destination)
    }

    private static func export(_ source: URL, displayName: String, destination: URL) async throws -> Output {
        let asset = AVURLAsset(url: source)
        guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else {
            throw ConversionError.noAudioTrack(displayName)
        }
        let duration = try await asset.load(.duration).seconds
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConversionError.exportFailed("no export session for \(displayName)")
        }
        try? FileManager.default.removeItem(at: destination)
        do {
            try await session.export(to: destination, as: .m4a)
        } catch {
            throw ConversionError.exportFailed("\(error)")
        }
        return Output(file: destination, duration: duration)
    }

    /// Container type from the first bytes of the file, as a file extension; nil if unknown.
    public static func sniffedExtension(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 12), head.count == 12 else { return nil }
        let bytes = [UInt8](head)
        func ascii(_ range: Range<Int>) -> String { String(decoding: bytes[range], as: UTF8.self) }
        if ascii(4..<8) == "ftyp" {
            let brand = ascii(8..<12)
            if brand.hasPrefix("qt") { return "mov" }
            if brand.hasPrefix("M4A") { return "m4a" }
            return "mp4"
        }
        if ascii(0..<3) == "ID3" || (bytes[0] == 0xFF && bytes[1] & 0xE0 == 0xE0) { return "mp3" }
        if ascii(0..<4) == "RIFF", ascii(8..<12) == "WAVE" { return "wav" }
        if ascii(0..<4) == "FORM" { return "aiff" }
        if ascii(0..<4) == "caff" { return "caf" }
        return nil
    }

    /// Default date of an imported item: the file's creation date (FR-31).
    public static func creationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    }
}
