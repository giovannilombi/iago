import AVFoundation
import Foundation
import Testing

@testable import IAGOCapture

@Suite struct AudioFileConverterTests {
    func writeTone(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88_200)!
        buffer.frameLength = 88_200
        for channel in 0..<2 {
            for i in 0..<88_200 { buffer.floatChannelData![channel][i] = 0.3 * sin(Float(i) * 0.06) }
        }
        try file.write(from: buffer)
    }

    @Test func convertsWaveToM4A() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("iago-conv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let wav = directory.appendingPathComponent("tone.wav")
        try writeTone(to: wav)  // the AVAudioFile must be closed before converting

        let output = try await AudioFileConverter.convertToM4A(
            wav, destination: directory.appendingPathComponent("out.m4a"))
        #expect(abs(output.duration - 2) < 0.05)
        let converted = try AVAudioFile(forReading: output.file)
        #expect(converted.fileFormat.settings[AVFormatIDKey] as? UInt32 == kAudioFormatMPEG4AAC)
    }

    @Test func readsFilesWithTheWrongExtension() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("iago-conv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let wav = directory.appendingPathComponent("tone.wav")
        try writeTone(to: wav)
        let m4a = directory.appendingPathComponent("voice.m4a")
        _ = try await AudioFileConverter.convertToM4A(wav, destination: m4a)
        let misnamed = directory.appendingPathComponent("WhatsApp Audio.mp3")
        try FileManager.default.moveItem(at: m4a, to: misnamed)
        #expect(AudioFileConverter.sniffedExtension(of: misnamed) == "m4a")

        let output = try await AudioFileConverter.convertToM4A(
            misnamed, destination: directory.appendingPathComponent("out.m4a"))
        #expect(abs(output.duration - 2) < 0.1)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: directory.path).allSatisfy {
                !$0.hasPrefix(".") && $0.count < 40
            })
    }

    @Test func rejectsFilesWithoutAudio() async throws {
        let text = FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID().uuidString).txt")
        try Data("ciao".utf8).write(to: text)
        await #expect(throws: (any Error).self) {
            _ = try await AudioFileConverter.convertToM4A(text, destination: text.appendingPathExtension("m4a"))
        }
    }
}
