import AVFoundation
import Foundation
import IAGOCapture

/// Phase 0 spike tools.
///   iago-spike levels <file>...                 per-second RMS in dBFS
///   iago-spike make-beep <out.wav> [minutes]    1 kHz beep every 10 s, for drift tests
///   iago-spike drift <recording-dir>            drift between system.m4a and mic.m4a
///   iago-spike processes                        audio processes and the mic IAGO would follow

func readMono(_ path: String) throws -> (samples: [Float], rate: Double) {
    let file = try AVAudioFile(
        forReading: URL(fileURLWithPath: path), commonFormat: .pcmFormatFloat32, interleaved: false)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
    else { throw NSError(domain: "iago-spike", code: 1) }
    try file.read(into: buffer)
    let channels = Int(buffer.format.channelCount)
    let frames = Int(buffer.frameLength)
    var samples = [Float](repeating: 0, count: frames)
    for channel in 0..<channels {
        let data = buffer.floatChannelData![channel]
        for index in 0..<frames { samples[index] += data[index] / Float(channels) }
    }
    return (samples, file.processingFormat.sampleRate)
}

func levels(_ paths: [String]) throws {
    for path in paths {
        let (samples, rate) = try readMono(path)
        let perSecond = stride(from: 0, to: samples.count, by: Int(rate)).map { start -> String in
            let chunk = Array(samples[start..<min(samples.count, start + Int(rate))])
            let rms = SilenceAlarm.rms(chunk)
            return String(format: "%4.0f", rms > 0 ? 20 * log10(Double(rms)) : -120.0)
        }
        print("\((path as NSString).lastPathComponent): \(perSecond.joined(separator: " "))")
    }
}

func makeBeep(_ path: String, minutes: Double) throws {
    let rate = 48_000.0
    let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    let file = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: format.settings)
    let period = Int(rate * 10)
    let total = Int(minutes * 60 * rate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(period))!
    buffer.frameLength = AVAudioFrameCount(period)
    let data = buffer.floatChannelData![0]
    for index in 0..<period {
        data[index] = index < Int(rate * 0.05) ? Float(0.5 * sin(2 * .pi * 1000 * Double(index) / rate)) : 0
    }
    for _ in 0..<(total / period) { try file.write(from: buffer) }
    print("Wrote \(path): \(minutes) min, beep every 10 s")
}

func drift(_ directory: String) throws {
    let system = try readMono(directory + "/system.m4a")
    let mic = try readMono(directory + "/mic.m4a")
    let report = DriftAnalyzer.analyze(system: system.samples, mic: mic.samples, sampleRate: system.rate)
    for entry in report.matches {
        print(
            String(
                format: "t=%8.2f s  offset=%7.2f ms  score=%.2f", entry.time, entry.offset * 1000, Double(entry.score)))
    }
    print(
        String(
            format: "beeps matched: %d  drift: %.2f ms  %@", report.matches.count, report.drift * 1000,
            report.matches.count >= 2 && report.drift < 0.05 ? "OK (< 50 ms)" : "CHECK"))
}

func processes() {
    let devices = Dictionary(uniqueKeysWithValues: CaptureEngine.availableInputDevices().map { ($0.id, $0.name) })
    print(
        "Input devices: " + devices.sorted { $0.key < $1.key }.map { "[\($0.key)] \($0.value)" }.joined(separator: ", ")
    )
    let (table, selection) = CaptureEngine.diagnoseMicSelection()
    for process in table where process.isRunningInput {
        let names = process.inputDevices.map { devices[$0] ?? "#\($0)" }.joined(separator: ", ")
        print("pid \(process.pid)  \(process.bundleID ?? "?")  input: \(names)")
    }
    print("Processes with audio objects: \(table.count), running input: \(table.filter(\.isRunningInput).count)")
    if let selection {
        print("Selected mic: \(devices[selection.deviceID] ?? "#\(selection.deviceID)")  reason: \(selection.reason)")
    } else {
        print("Selected mic: none")
    }
}

let args = Array(CommandLine.arguments.dropFirst())
do {
    switch args.first {
    case "levels": try levels(Array(args.dropFirst()))
    case "make-beep" where args.count >= 2: try makeBeep(args[1], minutes: args.count > 2 ? Double(args[2]) ?? 5 : 5)
    case "drift" where args.count == 2: try drift(args[1])
    case "processes": processes()
    default:
        print("usage: iago-spike levels <file>... | make-beep <out.wav> [minutes] | drift <recording-dir> | processes")
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
