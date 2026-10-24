import Accelerate
import Foundation

/// Measures drift between the two tracks using beeps played through the speakers, which reach the
/// system track digitally and the mic track acoustically. A constant offset (acoustic and device
/// latency) is expected; drift is how much that offset changes over the recording (spec 4.3: < 50 ms).
///
/// Beeps are found in the (clean) system track by onset, then located in the (noisy) mic track by
/// normalized cross-correlation with the system segment as template (matched filter).
public enum DriftAnalyzer {
    public struct Match: Sendable {
        public var time: Double
        public var offset: Double
        public var score: Float
    }

    public struct Report: Sendable {
        public var matches: [Match]
        public var drift: Double {
            (matches.map(\.offset).max() ?? 0) - (matches.map(\.offset).min() ?? 0)
        }
    }

    /// Onsets: first sample above `threshold` (relative to the track peak) after `quietGap` of quiet.
    public static func onsets(_ samples: [Float], sampleRate: Double, threshold: Float = 0.3, quietGap: Double = 1)
        -> [Double]
    {
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0 else { return [] }
        let level = peak * threshold
        let gap = Int(quietGap * sampleRate)
        var result: [Double] = []
        var lastLoud = -gap
        for (index, sample) in samples.enumerated() where abs(sample) >= level {
            if index - lastLoud >= gap {
                result.append(Double(index) / sampleRate)
            }
            lastLoud = index
        }
        return result
    }

    public static func analyze(
        system: [Float], mic: [Float], sampleRate: Double, maxOffset: Double = 0.3, minScore: Float = 0.3
    ) -> Report {
        let before = Int(0.01 * sampleRate)
        let templateLength = Int(0.07 * sampleRate)
        let searchRadius = Int(maxOffset * sampleRate)
        var matches: [Match] = []
        for onset in onsets(system, sampleRate: sampleRate) {
            let templateStart = Int(onset * sampleRate) - before
            let searchStart = templateStart - searchRadius
            let searchEnd = templateStart + searchRadius + templateLength
            guard templateStart >= 0, templateStart + templateLength <= system.count, searchStart >= 0,
                searchEnd <= mic.count
            else { continue }
            let template = Array(system[templateStart..<(templateStart + templateLength)])
            let window = Array(mic[searchStart..<searchEnd])
            guard let (lag, score) = bestLag(template: template, in: window), score >= minScore else { continue }
            matches.append(Match(time: onset, offset: Double(lag - searchRadius) / sampleRate, score: score))
        }
        return Report(matches: matches)
    }

    /// Lag in `window` maximizing the normalized cross-correlation with `template`.
    static func bestLag(template: [Float], in window: [Float]) -> (Int, Float)? {
        let count = window.count - template.count + 1
        guard count > 0 else { return nil }
        var correlation = [Float](repeating: 0, count: count)
        vDSP_conv(window, 1, template, 1, &correlation, 1, vDSP_Length(count), vDSP_Length(template.count))
        let templateEnergy = vDSP.sumOfSquares(template)
        // Sliding energy of the window, from a running sum of squares.
        let squares = vDSP.square(window)
        var running = [Float](repeating: 0, count: squares.count + 1)
        for index in squares.indices { running[index + 1] = running[index] + squares[index] }
        var best: (Int, Float)?
        for lag in 0..<count {
            let energy = running[lag + template.count] - running[lag]
            guard energy > 0, templateEnergy > 0 else { continue }
            let score = correlation[lag] / (templateEnergy * energy).squareRoot()
            if score > (best?.1 ?? -1) { best = (lag, score) }
        }
        return best
    }
}
