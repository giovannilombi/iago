@preconcurrency import AVFoundation
import Foundation
import IAGOCore

public struct FinalizedRecording: Sendable, Equatable {
    public var itemID: ItemID
    public var title: String
    public var startedAt: Date
    public var duration: Double
    public var directory: URL
    public var recovered: Bool
}

/// Turns a session directory into final files (spec 6.5): AAC mono `.m4a` per track plus a mix for
/// listening. Idempotent: the temporary directory is deleted only after all outputs are written, so a
/// crash during finalization is retried at the next launch.
/// Outputs are plaintext in `tmp/finalized/`: the app encrypts them into the archive right after.
public enum SessionFinalizer {
    static var aacSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: RecordingSession.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
    }

    public static func finalize(sessionDirectory: URL, into outputRoot: URL) throws -> FinalizedRecording {
        let manifestURL = sessionDirectory.appendingPathComponent(RecordingSession.manifestName)
        var manifest = try SessionManifest.decode(from: Data(contentsOf: manifestURL))
        let recovered = manifest.state != .stopped && manifest.state != .finalized

        var trackFrames: [TrackKind: Int64] = [:]
        for kind in TrackKind.allCases {
            let caf = sessionDirectory.appendingPathComponent("\(kind.rawValue).caf")
            if FileManager.default.fileExists(atPath: caf.path) {
                trackFrames[kind] = try CAFFileWriter.repairHeader(at: caf)
            }
        }
        // A normal stop pads every track to the session length; after a crash a track can be shorter or
        // empty (the system tap delivers nothing while no app plays), so pad it here.
        let longest = trackFrames.values.max() ?? 0
        for (kind, frames) in trackFrames where frames < longest {
            let caf = sessionDirectory.appendingPathComponent("\(kind.rawValue).caf")
            trackFrames[kind] = try CAFFileWriter.padWithSilence(at: caf, toFrames: longest)
        }

        let output = outputRoot.appendingPathComponent(manifest.itemID.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var mixInputs: [URL] = []
        for kind in TrackKind.allCases where (trackFrames[kind] ?? 0) > 0 {
            let caf = sessionDirectory.appendingPathComponent("\(kind.rawValue).caf")
            try encode([caf], to: output.appendingPathComponent("\(kind.rawValue).m4a"))
            mixInputs.append(caf)
        }
        if !mixInputs.isEmpty {
            try encode(mixInputs, to: output.appendingPathComponent("mix.m4a"))
        }

        let frames = trackFrames.values.max() ?? 0
        manifest.duration = manifest.duration ?? Double(frames) / manifest.sampleRate
        manifest.state = .finalized
        try manifest.encoded().write(to: output.appendingPathComponent(RecordingSession.manifestName), options: .atomic)
        try FileManager.default.removeItem(at: sessionDirectory)

        return FinalizedRecording(
            itemID: manifest.itemID,
            title: manifest.suggestedTitle?.isEmpty == false
                ? manifest.suggestedTitle! : ItemTitle.unclassified(startedAt: manifest.startedAt),
            startedAt: manifest.startedAt, duration: manifest.duration ?? 0, directory: output, recovered: recovered)
    }

    /// Session directories left behind by a crash or by a finalization that did not complete.
    public static func pendingSessions(in sessionsRoot: URL, excluding active: Set<ItemID> = []) -> [URL] {
        let entries =
            (try? FileManager.default.contentsOfDirectory(at: sessionsRoot, includingPropertiesForKeys: nil)) ?? []
        return entries.filter { url in
            guard let id = ItemID(rawValue: url.lastPathComponent), !active.contains(id) else { return false }
            return FileManager.default.fileExists(
                atPath: url.appendingPathComponent(RecordingSession.manifestName).path)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Encodes one or more mono CAF files to a mono AAC file, summing them (mix) when there are several.
    static func encode(_ inputs: [URL], to destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        let sources = try inputs.map {
            try AVAudioFile(forReading: $0, commonFormat: .pcmFormatFloat32, interleaved: false)
        }
        guard let format = sources.first?.processingFormat else { return }
        let writer = try AVAudioFile(
            forWriting: destination, settings: aacSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let chunk: AVAudioFrameCount = 48_000 * 5
        guard let mixed = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk),
            let scratch = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk)
        else { return }
        let total = sources.map(\.length).max() ?? 0
        var position: AVAudioFramePosition = 0
        while position < total {
            let frames = AVAudioFrameCount(min(AVAudioFramePosition(chunk), total - position))
            let out = mixed.floatChannelData![0]
            out.update(repeating: 0, count: Int(frames))
            for source in sources where source.framePosition < source.length {
                scratch.frameLength = 0
                try source.read(into: scratch, frameCount: frames)
                let samples = scratch.floatChannelData![0]
                for index in 0..<Int(scratch.frameLength) {
                    out[index] += samples[index]
                }
            }
            if sources.count > 1 {
                for index in 0..<Int(frames) {
                    out[index] = min(1, max(-1, out[index]))
                }
            }
            mixed.frameLength = frames
            try writer.write(from: mixed)
            position += AVAudioFramePosition(frames)
        }
    }
}
