import CoreAudio
import IAGOCore

/// Converts a Core Audio buffer list to mono Float32 samples by averaging channels.
enum AudioBufferMixdown {
    static func isSupported(_ format: AudioStreamBasicDescription) -> Bool {
        format.mFormatID == kAudioFormatLinearPCM && format.mFormatFlags & kAudioFormatFlagIsFloat != 0
            && format.mBitsPerChannel == 32
    }

    static func mono(_ list: UnsafePointer<AudioBufferList>) -> [Float] {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        guard let first = buffers.first, first.mDataByteSize > 0 else { return [] }
        // Interleaved: one buffer with N channels. Non-interleaved: N buffers with one channel each.
        let channelsPerBuffer = Int(max(1, first.mNumberChannels))
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / channelsPerBuffer
        var output = [Float](repeating: 0, count: frames)
        var channelCount = 0
        for buffer in buffers {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let channels = Int(max(1, buffer.mNumberChannels))
            let bufferFrames = min(frames, Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / channels)
            for channel in 0..<channels {
                for frame in 0..<bufferFrames {
                    output[frame] += data[frame * channels + channel]
                }
            }
            channelCount += channels
        }
        if channelCount > 1 {
            let scale = 1 / Float(channelCount)
            for frame in 0..<frames { output[frame] *= scale }
        }
        return output
    }
}

/// A chunk of captured audio, already mixed down to mono.
public struct CapturedBuffer: Sendable {
    public var track: TrackKind
    public var hostTime: UInt64
    public var sampleRate: Double
    public var samples: [Float]
}
