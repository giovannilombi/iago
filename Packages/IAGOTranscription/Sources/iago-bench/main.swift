import Foundation
import IAGOTranscription

/// Phase 0 ASR benchmark (spec 7.1): whisper.cpp vs Parakeet, with FluidAudio VAD and diarization.
///
///   iago-bench [--engines whisper,parakeet] [--whisper-model PATH] [--parakeet v3|ultra]
///              [--language it|auto] [--no-diarize] [--allow-download] [--min-speaker-run SECONDS]
///              [--vocabulary "Acme,PX7"]
///              [--out DIR] INPUT...
///
/// INPUT is an audio file (import pipeline) or an IAGO recording directory with mic.m4a and
/// system.m4a (two-track pipeline). Outputs go to --out (default: ./bench-out), never committed.

struct Options {
    var engines = ["whisper", "parakeet"]
    var whisperModel = "Models/ggml-large-v3-turbo.bin"
    var parakeet = ParakeetEngine.Variant.v3
    var language: String? = "it"
    var diarize = true
    var allowDownload = false
    var out = "bench-out"
    var minSpeakerRun = 1.5
    var vocabulary: [String] = []
    /// IAGO's FluidAudio folder (`…/IAGO/Models/FluidAudio`) instead of FluidAudio's own cache.
    var fluidRoot: String?
    var inputs: [String] = []
}

func parse() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--engines": options.engines = args.removeFirst().split(separator: ",").map(String.init)
        case "--whisper-model": options.whisperModel = args.removeFirst()
        case "--parakeet": options.parakeet = ParakeetEngine.Variant(rawValue: args.removeFirst()) ?? .v3
        case "--language":
            let value = args.removeFirst()
            options.language = value == "auto" ? nil : value
        case "--no-diarize": options.diarize = false
        case "--vocabulary": options.vocabulary = args.removeFirst().split(separator: ",").map(String.init)
        case "--fluid-root": options.fluidRoot = args.removeFirst()
        case "--allow-download": options.allowDownload = true
        case "--out": options.out = args.removeFirst()
        case "--min-speaker-run": options.minSpeakerRun = Double(args.removeFirst()) ?? options.minSpeakerRun
        default: options.inputs.append(arg)
        }
    }
    return options
}

func measure<T>(_ body: () async throws -> T) async rethrows -> (T, Double) {
    let start = ContinuousClock.now
    let value = try await body()
    let elapsed = start.duration(to: .now)
    return (value, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
}

func input(for path: String) -> (TranscriptionPipeline.Input, String) {
    let url = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    if isDirectory.boolValue {
        return (
            .recording(mic: url.appendingPathComponent("mic.m4a"), system: url.appendingPathComponent("system.m4a")),
            url.lastPathComponent
        )
    }
    return (.imported(url), url.deletingPathExtension().lastPathComponent)
}

let options = parse()
guard !options.inputs.isEmpty else {
    print(
        "usage: iago-bench [--engines whisper,parakeet] [--whisper-model PATH] [--parakeet v3|ultra] [--language it|auto] [--no-diarize] [--allow-download] [--min-speaker-run SECONDS] [--out DIR] INPUT..."
    )
    exit(2)
}
FluidAudioServices.setDownloadsAllowed(options.allowDownload)
let fluidBase = options.fluidRoot.map { URL(fileURLWithPath: $0) }
let outDir = URL(fileURLWithPath: options.out, isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var rows: [String] = []
do {
    let (vad, vadLoad) = try await measure { try await FluidAudioServices.VoiceActivityDetector.load(from: fluidBase) }
    let (diarizer, diarizerLoad) = try await measure {
        options.diarize ? try await FluidAudioServices.Diarizer.load(from: fluidBase) : nil
    }
    print(String(format: "VAD loaded in %.1f s, diarizer in %.1f s", vadLoad, diarizerLoad))

    for engineName in options.engines {
        let (engine, engineLoad): (any TranscriptionEngine, Double) = try await measure {
            switch engineName {
            case "whisper": try WhisperCppEngine(modelURL: URL(fileURLWithPath: options.whisperModel))
            case "parakeet": try await ParakeetEngine.load(variant: options.parakeet)
            default: throw TranscriptionError.engineFailure("Unknown engine \(engineName)")
            }
        }
        print(String(format: "%@ (%@) loaded in %.1f s", engine.asrName, engine.modelName, engineLoad))
        var pipeline = TranscriptionPipeline(engine: engine, vad: vad, diarizer: diarizer)
        pipeline.minSpeakerRun = options.minSpeakerRun

        for path in options.inputs {
            let (pipelineInput, name) = input(for: path)
            let output = try await pipeline.run(
                itemId: name, input: pipelineInput,
                options: .init(language: options.language, vocabulary: options.vocabulary))
            let m = output.metrics
            let base = outDir.appendingPathComponent("\(name).\(engine.modelName)")
            try output.transcript.encoded().write(to: base.appendingPathExtension("json"))
            try TranscriptText.lines(output.transcript).joined(separator: "\n")
                .write(to: base.appendingPathExtension("txt"), atomically: true, encoding: .utf8)
            let row = String(
                format: "| %@ | %.0f | %@ | %.1f | %.1f | %.1f | %.1f | %.1f | %.1fx | %d | %d | %d | %d |",
                name, m.audioDuration, engine.modelName, m.decode, m.vad, m.asr, m.diarization, m.total, m.speedFactor,
                output.transcript.segments.count, output.transcript.speakers.count, m.droppedHallucinations,
                m.droppedEcho)
            rows.append(row)
            print(row)
        }
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}

let header = """
    | Input | Audio (s) | Engine | Decode (s) | VAD (s) | ASR (s) | Diar. (s) | Total (s) | Speed | Segments | Speakers | Dropped halluc. | Dropped echo |
    |---|---|---|---|---|---|---|---|---|---|---|---|---|
    """
try (header + "\n" + rows.joined(separator: "\n") + "\n").write(
    to: outDir.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
print("Summary: \(outDir.appendingPathComponent("summary.md").path)")
