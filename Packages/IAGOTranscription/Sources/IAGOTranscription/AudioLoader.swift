@preconcurrency import AVFoundation

/// Decodes any AVFoundation-readable file (spec FR-30) to 16 kHz mono Float32.
public enum AudioLoader {
    public static func load16kMono(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat
        guard
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: transcriptionSampleRate, channels: 1, interleaved: false),
            let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else { throw TranscriptionError.audio("Cannot convert \(inputFormat)") }

        let chunk: AVAudioFrameCount = 1 << 16
        guard let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: chunk) else {
            throw TranscriptionError.audio("Cannot allocate buffer")
        }
        let ratio = transcriptionSampleRate / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(chunk) * ratio) + 1024
        var samples: [Float] = []
        samples.reserveCapacity(Int(Double(file.length) * ratio) + 1024)
        nonisolated(unsafe) var endOfFile = false
        nonisolated(unsafe) var readError: Error?
        nonisolated(unsafe) var hasReadAudio = false
        while true {
            guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else { break }
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
                if endOfFile {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    try file.read(into: input, frameCount: chunk)
                } catch {
                    // `length` is an estimate for AAC/MP3: reading the phantom tail throws instead of
                    // returning an empty buffer. After real audio, treat it as end of file.
                    if !hasReadAudio { readError = error }
                    input.frameLength = 0
                }
                if input.frameLength == 0 {
                    endOfFile = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                hasReadAudio = true
                inputStatus.pointee = .haveData
                return input
            }
            if let error = conversionError ?? readError { throw error }
            if output.frameLength > 0 {
                samples.append(
                    contentsOf: UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
            }
            if status == .endOfStream || status == .error { break }
        }
        return samples
    }
}
