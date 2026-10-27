import Foundation

/// Pure post-processing steps of the pipeline (spec 7.2).
public enum TranscriptPostProcessing {
    // MARK: Chunking

    /// Groups VAD regions into chunks for the ASR: regions closer than `maxGap` are joined (keeping the
    /// gap audio, so words at the edges are not cut) as long as the chunk stays under `maxChunk`.
    public static func chunks(
        from regions: [SpeechRegion], maxGap: Double = 1.5, maxChunk: Double = 28, padding: Double = 0.2,
        totalDuration: Double
    ) -> [SpeechRegion] {
        var result: [SpeechRegion] = []
        for region in regions.sorted(by: { $0.start < $1.start }) {
            let padded = SpeechRegion(
                start: max(0, region.start - padding), end: min(totalDuration, region.end + padding))
            if var last = result.last, padded.start - last.end <= maxGap, padded.end - last.start <= maxChunk {
                last.end = max(last.end, padded.end)
                result[result.count - 1] = last
            } else {
                result.append(padded)
            }
        }
        return result
    }

    // MARK: Hallucination filter

    /// Known Whisper hallucinations on silence or noise in Italian (normalized).
    static let knownHallucinations: Set<String> = [
        "sottotitoli creati dalla comunita amara org",
        "sottotitoli e revisione a cura di qtss",
        "grazie per la visione",
        "grazie a tutti per la visione",
        "iscriviti al canale",
        "grazie",
    ]

    public struct FilterResult: Sendable {
        public var kept: [TranscribedSegment]
        public var dropped: Int
    }

    /// Whisper protections (spec 7.2): drops empty segments, consecutive identical repetitions, segments
    /// likely to be "no speech" and known hallucination phrases.
    public static func filterHallucinations(_ segments: [TranscribedSegment], noSpeechThreshold: Float = 0.6)
        -> FilterResult
    {
        var kept: [TranscribedSegment] = []
        var dropped = 0
        for segment in segments {
            let normalized = normalize(segment.text)
            let isEmpty = normalized.isEmpty
            let isRepeat = kept.last.map { normalize($0.text) == normalized } ?? false
            let isNoSpeech = (segment.noSpeechProbability ?? 0) > noSpeechThreshold && (segment.confidence ?? 1) < 0.5
            let isKnown = knownHallucinations.contains(normalized) && segment.end - segment.start < 4
            if isEmpty || isRepeat || isNoSpeech || isKnown {
                dropped += 1
            } else {
                kept.append(segment)
            }
        }
        return FilterResult(kept: kept, dropped: dropped)
    }

    // MARK: Sentences

    /// Joins consecutive segments of the same speaker when the first one does not end a sentence: Whisper
    /// often ends a segment mid-sentence. Speaker changes are never crossed, so this runs after
    /// `splitBySpeaker`. Segments stay apart after . ? !, a pause longer than `pause` or past `maxDuration`.
    public static func joinSentences(
        _ labeled: [(speaker: String, segment: TranscribedSegment)], pause: Double = 0.8, maxDuration: Double = 20
    ) -> [(speaker: String, segment: TranscribedSegment)] {
        var result: [(speaker: String, segment: TranscribedSegment)] = []
        for entry in labeled {
            if let last = result.last, last.speaker == entry.speaker, !endsSentence(last.segment.text),
                entry.segment.start - last.segment.end <= pause, entry.segment.end - last.segment.start <= maxDuration
            {
                var joined = last.segment
                joined.end = max(joined.end, entry.segment.end)
                joined.text = [joined.text, entry.segment.text].joined(separator: " ")
                joined.words += entry.segment.words
                if let a = last.segment.confidence, let b = entry.segment.confidence {
                    let (wa, wb) = (Float(last.segment.text.count), Float(entry.segment.text.count))
                    joined.confidence = (a * wa + b * wb) / max(1, wa + wb)
                }
                result[result.count - 1].segment = joined
            } else {
                result.append(entry)
            }
        }
        return result
    }

    static func endsSentence(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).last.map { ".?!".contains($0) } ?? false
    }

    // MARK: Speakers

    public struct SpeakerTurn: Equatable, Sendable {
        public var speaker: String
        public var start: Double
        public var end: Double

        public init(speaker: String, start: Double, end: Double) {
            self.speaker = speaker
            self.start = start
            self.end = end
        }
    }

    /// Assigns each segment the speaker with the largest time overlap, or the nearest turn (spec 7.2, step 6).
    public static func assignSpeakers(to segments: [TranscribedSegment], turns: [SpeakerTurn]) -> [String?] {
        segments.map { segment in
            var best: (speaker: String, overlap: Double)?
            for turn in turns {
                let overlap = min(segment.end, turn.end) - max(segment.start, turn.start)
                if overlap > (best?.overlap ?? 0) { best = (turn.speaker, overlap) }
            }
            if let best { return best.speaker }
            let midpoint = (segment.start + segment.end) / 2
            return turns.min { distance($0, midpoint) < distance($1, midpoint) }?.speaker
        }
    }

    /// Splits segments at speaker changes using word timings (spec 7.2, step 6): each word gets the
    /// speaker of its overlapping turn and consecutive words of the same speaker form one segment. Runs
    /// shorter than `minRun` seconds are merged into a neighbour, because diarization turns are imprecise
    /// at their edges. Segments without word timings keep a single speaker for the whole segment.
    public static func splitBySpeaker(
        _ segments: [TranscribedSegment], turns: [SpeakerTurn], fallback: String, minRun: Double = 1.5
    ) -> [(speaker: String, segment: TranscribedSegment)] {
        segments.flatMap { segment -> [(speaker: String, segment: TranscribedSegment)] in
            guard !segment.words.isEmpty, !turns.isEmpty else {
                return [(assignSpeakers(to: [segment], turns: turns)[0] ?? fallback, segment)]
            }
            let wordSpeakers = assignSpeakers(
                to: segment.words.map { TranscribedSegment(start: $0.start, end: $0.end, text: $0.text) }, turns: turns)
            var runs: [(speaker: String, words: [TranscribedWord])] = []
            for (word, speaker) in zip(segment.words, wordSpeakers) {
                let speaker = speaker ?? fallback
                if runs.last?.speaker == speaker {
                    runs[runs.count - 1].words.append(word)
                } else {
                    runs.append((speaker, [word]))
                }
            }
            runs = snapToPunctuation(mergeShortRuns(runs, minRun: minRun))
            guard runs.count > 1 else { return [(runs[0].speaker, segment)] }
            return runs.map { run in
                var part = segment
                part.start = run.words.first!.start
                part.end = run.words.last!.end
                part.text = run.words.map(\.text).joined().trimmingCharacters(in: .whitespaces)
                part.words = run.words
                return (run.speaker, part)
            }
        }
    }

    /// Moves each speaker change by up to `reach` words to the nearest word ending in punctuation: word
    /// timings and diarization turns are both a little imprecise, punctuation is where turns usually end.
    static func snapToPunctuation(_ runs: [(speaker: String, words: [TranscribedWord])], reach: Int = 2)
        -> [(speaker: String, words: [TranscribedWord])]
    {
        guard runs.count > 1 else { return runs }
        var runs = runs
        for index in 1..<runs.count {
            let before = runs[index - 1].words
            let after = runs[index].words
            // Candidate cut = number of words moved: negative moves words from `before` to `after`.
            let candidates = (-min(reach, before.count - 1)...min(reach, after.count - 1)).filter { shift in
                let lastBefore = shift <= 0 ? before[before.count - 1 + shift] : after[shift - 1]
                return ".,?!;:".contains(lastBefore.text.trimmingCharacters(in: .whitespaces).last ?? " ")
            }
            guard let shift = candidates.min(by: { abs($0) < abs($1) }), shift != 0 else { continue }
            if shift < 0 {
                runs[index].words = Array(before.suffix(-shift)) + after
                runs[index - 1].words = Array(before.dropLast(-shift))
            } else {
                runs[index - 1].words = before + after.prefix(shift)
                runs[index].words = Array(after.dropFirst(shift))
            }
        }
        return runs
    }

    /// Repeatedly merges the shortest run under `minRun` into its longer neighbour.
    static func mergeShortRuns(_ runs: [(speaker: String, words: [TranscribedWord])], minRun: Double)
        -> [(speaker: String, words: [TranscribedWord])]
    {
        func duration(_ words: [TranscribedWord]) -> Double { words.last!.end - words.first!.start }
        var runs = runs
        while runs.count > 1,
            let index = runs.indices.filter({ duration(runs[$0].words) < minRun })
                .min(by: { duration(runs[$0].words) < duration(runs[$1].words) })
        {
            let previous = index > 0 ? index - 1 : nil
            let next = index < runs.count - 1 ? index + 1 : nil
            let target: Int
            switch (previous, next) {
            case (let p?, let n?): target = duration(runs[p].words) >= duration(runs[n].words) ? p : n
            case (let p?, nil): target = p
            case (nil, let n?): target = n
            default: return runs
            }
            if target < index {
                runs[target].words += runs[index].words
            } else {
                runs[target].words = runs[index].words + runs[target].words
            }
            runs.remove(at: index)
            // Neighbours with the same speaker become one run.
            var merged: [(speaker: String, words: [TranscribedWord])] = []
            for run in runs {
                if merged.last?.speaker == run.speaker {
                    merged[merged.count - 1].words += run.words
                } else {
                    merged.append(run)
                }
            }
            runs = merged
        }
        return runs
    }

    private static func distance(_ turn: SpeakerTurn, _ time: Double) -> Double {
        time < turn.start ? turn.start - time : max(0, time - turn.end)
    }

    /// "Più persone nella stanza" (ADR-0031): the mic voice with the most speech is the user (`me`); the
    /// others become `r2`, `r3`… in order of first appearance.
    public static func roomSpeakers(_ labeled: [(speaker: String, segment: TranscribedSegment)])
        -> (labeled: [(speaker: String, segment: TranscribedSegment)], others: [String])
    {
        var talk: [String: Double] = [:]
        var order: [String] = []
        for entry in labeled {
            if talk[entry.speaker] == nil { order.append(entry.speaker) }
            talk[entry.speaker, default: 0] += entry.segment.end - entry.segment.start
        }
        guard let main = order.max(by: { talk[$0]! < talk[$1]! }) else { return ([], []) }
        var mapping = [main: "me"]
        var others: [String] = []
        for id in order where id != main {
            others.append("r\(others.count + 2)")
            mapping[id] = others.last
        }
        return (labeled.map { (mapping[$0.speaker]!, $0.segment) }, others)
    }

    /// Maps raw diarizer IDs to `s1`, `s2`… in order of first appearance.
    public static func normalizeSpeakerIDs(_ turns: [SpeakerTurn]) -> (turns: [SpeakerTurn], ids: [String]) {
        var mapping: [String: String] = [:]
        var ids: [String] = []
        let mapped = turns.sorted { $0.start < $1.start }.map { turn -> SpeakerTurn in
            if mapping[turn.speaker] == nil {
                ids.append("s\(ids.count + 1)")
                mapping[turn.speaker] = ids.last
            }
            return SpeakerTurn(speaker: mapping[turn.speaker]!, start: turn.start, end: turn.end)
        }
        return (mapped, ids)
    }

    /// The voices of `normalizeSpeakerIDs`' speakers: raw diarizer IDs → `s1`, `s2`… with the same mapping.
    public static func normalizeVoices(_ voices: [String: [Float]], turns: [SpeakerTurn]) -> [String: [Float]] {
        var result: [String: [Float]] = [:]
        var seen: Set<String> = []
        for turn in turns.sorted(by: { $0.start < $1.start }) where seen.insert(turn.speaker).inserted {
            if let voice = voices[turn.speaker] { result["s\(seen.count)"] = voice }
        }
        return result
    }

    // MARK: Echo filter

    /// Drops mic segments that overlap in time with a system segment of very similar text: with
    /// speakers, the mic also captures the other participants (spec 6.3, 7.2 step 7).
    public static func removeEcho(
        mic: [TranscribedSegment], system: [TranscribedSegment], tolerance: Double = 1.0, similarity: Double = 0.6
    ) -> (kept: [TranscribedSegment], dropped: Int) {
        var dropped = 0
        let kept = mic.filter { segment in
            let isEcho = system.contains { other in
                min(segment.end, other.end + tolerance) > max(segment.start, other.start - tolerance)
                    && wordSimilarity(segment.text, other.text) >= similarity
            }
            if isEcho { dropped += 1 }
            return !isEcho
        }
        return (kept, dropped)
    }

    /// Share of the shorter text's words found in the other text.
    public static func wordSimilarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(normalize(a).split(separator: " "))
        let wordsB = Set(normalize(b).split(separator: " "))
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return 0 }
        return Double(wordsA.intersection(wordsB).count) / Double(min(wordsA.count, wordsB.count))
    }

    /// Lowercase, no diacritics, letters/digits/spaces only, collapsed spaces.
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it"))
            .lowercased()
        let cleaned = folded.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) || $0 == " " ? Character($0) : " "
        }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }
}
