// Mixes the lines listed in a manifest (track, start, duration, file) into fixture files.
// Used by make-fixtures.sh; run with `swift scripts/fixture-mixer.swift MANIFEST OUTDIR`.
import AVFoundation

let rate = 48_000.0
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
let arguments = CommandLine.arguments
let manifest = try String(contentsOfFile: arguments[1], encoding: .utf8)
let outDir = URL(fileURLWithPath: arguments[2], isDirectory: true)

struct Line { var track: String; var start: Double; var file: URL }
let lines = manifest.split(separator: "\n").map { row -> Line in
    let fields = row.split(separator: "\t").map(String.init)
    return Line(track: fields[0], start: Double(fields[1])!, file: URL(fileURLWithPath: fields[3]))
}

func load(_ url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    let converter = AVAudioConverter(from: file.processingFormat, to: format)!
    let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: input)
    let capacity = AVAudioFrameCount(Double(file.length) * rate / file.processingFormat.sampleRate) + 1024
    let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
    nonisolated(unsafe) var done = false
    _ = converter.convert(to: output, error: nil) { _, status in
        if done { status.pointee = .endOfStream; return nil }
        done = true
        status.pointee = .haveData
        return input
    }
    return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
}

var tracks: [String: [Float]] = ["mic": [], "system": []]
for line in lines {
    let samples = try load(line.file)
    let start = Int(line.start * rate)
    var track = tracks[line.track]!
    if track.count < start + samples.count { track += [Float](repeating: 0, count: start + samples.count - track.count) }
    for (index, sample) in samples.enumerated() { track[start + index] += sample }
    tracks[line.track] = track
}
let length = tracks.values.map(\.count).max()! + Int(rate)
for key in tracks.keys { tracks[key]! += [Float](repeating: 0, count: length - tracks[key]!.count) }

func write(_ samples: [Float], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: url)
    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96_000]
    let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
    try file.write(from: buffer)
}

let mic = tracks["mic"]!, system = tracks["system"]!
try write(zip(mic, system).map { $0 + $1 }, to: outDir.appendingPathComponent("import-dialogue.m4a"))
try write(mic, to: outDir.appendingPathComponent("recording/mic.m4a"))
try write(system, to: outDir.appendingPathComponent("recording/system.m4a"))
let delay = Int(0.047 * rate)
let echoMic = mic.indices.map { index in mic[index] + (index >= delay ? 0.1 * system[index - delay] : 0) }
try write(echoMic, to: outDir.appendingPathComponent("recording-echo/mic.m4a"))
try write(system, to: outDir.appendingPathComponent("recording-echo/system.m4a"))
