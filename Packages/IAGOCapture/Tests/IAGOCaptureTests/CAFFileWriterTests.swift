import AVFoundation
import Foundation
import Testing

@testable import IAGOCapture

@Suite struct CAFFileWriterTests {
    func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
    }

    func readSamples(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }

    @Test func closedFileIsReadable() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try CAFFileWriter(url: url, sampleRate: 48_000)
        let samples = (0..<4_800).map { Float($0) / 4_800 }
        try writer.append(samples)
        try writer.close()
        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.sampleRate == 48_000)
        #expect(file.fileFormat.channelCount == 1)
        #expect(try readSamples(url) == samples)
    }

    /// Simulates a crash: the writer is never closed and the last sample is half written.
    @Test func crashedFileIsRepaired() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try CAFFileWriter(url: url, sampleRate: 48_000)
        try writer.append(Array(repeating: 0.25, count: 1_000))
        try writer.synchronize()
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x01, 0x02]))
        try handle.close()

        let frames = try CAFFileWriter.repairHeader(at: url)
        #expect(frames == 1_000)
        #expect(try readSamples(url) == Array(repeating: 0.25, count: 1_000))
    }
}
