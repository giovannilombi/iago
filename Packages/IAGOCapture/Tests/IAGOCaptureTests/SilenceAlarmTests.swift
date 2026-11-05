import Foundation
import Testing

@testable import IAGOCapture

@Suite struct SilenceAlarmTests {
    @Test func noAlarmInFirst30Seconds() {
        #expect(SilenceAlarm.silentTrack(now: 20, lastSignal: [.system: 19]) == nil)
    }

    @Test func silentMicWhileSystemTalks() {
        #expect(SilenceAlarm.silentTrack(now: 60, lastSignal: [.system: 59]) == .mic)
    }

    @Test func silentSystemWhileMicTalks() {
        #expect(SilenceAlarm.silentTrack(now: 60, lastSignal: [.mic: 58, .system: 10]) == .system)
    }

    @Test func bothSilentIsNotAnAlarm() {
        #expect(SilenceAlarm.silentTrack(now: 120, lastSignal: [.mic: 10, .system: 10]) == nil)
    }

    @Test func micAbsentOnlyWithoutBuffers() {
        #expect(!SilenceAlarm.micAbsent(now: 1, lastBuffer: nil, hasDevice: false))
        #expect(!SilenceAlarm.micAbsent(now: 60, lastBuffer: 59.5, hasDevice: true))
        #expect(SilenceAlarm.micAbsent(now: 60, lastBuffer: 50, hasDevice: true))
        #expect(SilenceAlarm.micAbsent(now: 3, lastBuffer: nil, hasDevice: true))
        #expect(SilenceAlarm.micAbsent(now: 60, lastBuffer: 59.5, hasDevice: false))
    }

    @Test func rmsOfSine() {
        let samples = (0..<48_000).map { Float(sin(Double($0) * 2 * .pi * 440 / 48_000)) }
        #expect(abs(SilenceAlarm.rms(samples) - 0.7071) < 0.001)
    }
}

@Suite struct DriftAnalyzerTests {
    func beeps(every period: Double, count: Int, offset: Double, rate: Double, stretch: Double = 1) -> [Float] {
        var samples = [Float](repeating: 0, count: Int(Double(count) * period * rate * stretch + rate))
        for index in 0..<count {
            let start = Int((Double(index) * period * stretch + offset + 0.5) * rate)
            for frame in 0..<Int(0.05 * rate) where start + frame < samples.count {
                samples[start + frame] = Float(0.5 * sin(2 * .pi * 1000 * Double(frame) / rate))
            }
        }
        return samples
    }

    @Test func constantLatencyIsNotDrift() {
        let system = beeps(every: 10, count: 6, offset: 0, rate: 48_000)
        let mic = beeps(every: 10, count: 6, offset: 0.012, rate: 48_000)
        let report = DriftAnalyzer.analyze(system: system, mic: mic, sampleRate: 48_000)
        #expect(report.matches.count == 6)
        #expect(abs(report.matches[0].offset - 0.012) < 0.001)
        #expect(report.drift < 0.001)
    }

    @Test func findsBeepUnderNoise() {
        let system = beeps(every: 10, count: 4, offset: 0, rate: 48_000)
        var mic = beeps(every: 10, count: 4, offset: 0.03, rate: 48_000).map { $0 * 0.1 }
        var generator = SystemRandomNumberGenerator()
        for index in mic.indices { mic[index] += Float.random(in: -0.1...0.1, using: &generator) }
        let report = DriftAnalyzer.analyze(system: system, mic: mic, sampleRate: 48_000)
        #expect(report.matches.count == 4)
        #expect(report.matches.allSatisfy { abs($0.offset - 0.03) < 0.001 })
    }

    @Test func detectsDrift() {
        let system = beeps(every: 10, count: 6, offset: 0, rate: 48_000)
        let mic = beeps(every: 10, count: 6, offset: 0, rate: 48_000, stretch: 1.0004)  // +20 ms over 50 s
        #expect(abs(DriftAnalyzer.analyze(system: system, mic: mic, sampleRate: 48_000).drift - 0.02) < 0.002)
    }
}
