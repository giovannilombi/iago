@preconcurrency import AVFoundation
import IAGOCore

/// Writes one track: resampling to the session rate, timestamp alignment, batched incremental writes.
/// Not thread-safe: owned by a `RecordingSession` and used on its queue only.
final class TrackWriter {
    let kind: TrackKind
    let url: URL
    private let sampleRate: Double
    private let file: CAFFileWriter
    private var aligner: TrackAligner
    private var resampler: Resampler?
    private var pending: [Float] = []
    private var unsyncedFrames = 0
    private let flushFrames: Int
    private let syncFrames: Int
    private(set) var lastSignalPosition: Double?

    init(kind: TrackKind, url: URL, sampleRate: Double) throws {
        self.kind = kind
        self.url = url
        self.sampleRate = sampleRate
        self.file = try CAFFileWriter(url: url, sampleRate: sampleRate)
        self.aligner = TrackAligner(sampleRate: sampleRate)
        self.flushFrames = Int(sampleRate * 0.5)
        self.syncFrames = Int(sampleRate * 2)  // spec 6.5: flush to disk at least every 2 s
        pending.reserveCapacity(flushFrames * 2)
    }

    var framesWritten: Int64 { file.framesWritten + Int64(pending.count) }

    func append(_ samples: [Float], sourceRate: Double, at position: Double) throws {
        var output = samples
        if sourceRate != sampleRate {
            if resampler?.sourceRate != sourceRate {
                resampler = try Resampler(from: sourceRate, to: sampleRate)
            }
            output = resampler?.process(samples) ?? []
        } else {
            resampler = nil
        }
        if SilenceAlarm.rms(samples) > SilenceAlarm.signalThreshold {
            lastSignalPosition = position
        }
        let placement = aligner.place(frameCount: output.count, at: position)
        if placement.silenceFrames > 0 {
            pending.append(contentsOf: repeatElement(0, count: placement.silenceFrames))
        }
        pending.append(contentsOf: output.dropFirst(placement.droppedLeadingFrames))
        if pending.count >= flushFrames {
            try flush()
        }
    }

    /// Appends silence up to `frames` (end of session), so both tracks have the session length.
    func pad(toFrames frames: Int64) {
        let missing = frames - framesWritten
        guard missing > 0 else { return }
        pending.append(contentsOf: repeatElement(0, count: Int(missing)))
    }

    func flush() throws {
        if !pending.isEmpty {
            try file.append(pending)
            unsyncedFrames += pending.count
            pending.removeAll(keepingCapacity: true)
        }
        if unsyncedFrames >= syncFrames {
            try file.synchronize()
            unsyncedFrames = 0
        }
    }

    func close() throws {
        try flush()
        try file.close()
    }
}

/// Streaming mono sample-rate converter.
final class Resampler {
    let sourceRate: Double
    private let converter: AVAudioConverter
    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat

    init(from sourceRate: Double, to targetRate: Double) throws {
        guard let input = AVAudioFormat(standardFormatWithSampleRate: sourceRate, channels: 1),
            let output = AVAudioFormat(standardFormatWithSampleRate: targetRate, channels: 1),
            let converter = AVAudioConverter(from: input, to: output)
        else { throw CaptureError.unsupportedFormat("resample \(sourceRate) → \(targetRate)") }
        converter.primeMethod = .none
        self.sourceRate = sourceRate
        self.converter = converter
        self.inputFormat = input
        self.outputFormat = output
    }

    func process(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty,
            let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count))
        else { return [] }
        input.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer {
            input.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
        }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(samples.count) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return [] }
        nonisolated(unsafe) var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return input
        }
        return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
    }
}
