import AVFoundation
import Foundation
import Testing

@testable import IAGOTranscription

@Suite struct AudioLoaderTests {
    /// AAC files whose estimated length overshoots the decodable stream must load completely.
    @Test func loadsAACTo16kMono() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("tone.m4a")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
        ]
        do {
            let file = try AVAudioFile(
                forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100 * 3)!
            buffer.frameLength = buffer.frameCapacity
            for index in 0..<Int(buffer.frameLength) {
                buffer.floatChannelData![0][index] = Float(0.5 * sin(2 * .pi * 440 * Double(index) / 44_100))
            }
            try file.write(from: buffer)
        }
        let samples = try AudioLoader.load16kMono(url)
        #expect(abs(Double(samples.count) / 16_000 - 3) < 0.1)
    }
}
