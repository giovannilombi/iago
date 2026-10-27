import Testing

@testable import IAGOTranscription

typealias P = TranscriptPostProcessing

@Suite struct ChunkingTests {
    @Test func nearbyRegionsAreJoined() {
        let chunks = P.chunks(
            from: [.init(start: 1, end: 3), .init(start: 3.5, end: 5), .init(start: 10, end: 12)], padding: 0,
            totalDuration: 20)
        #expect(chunks == [.init(start: 1, end: 5), .init(start: 10, end: 12)])
    }

    @Test func chunksStayUnderMaximum() {
        let regions = (0..<10).map { SpeechRegion(start: Double($0) * 5, end: Double($0) * 5 + 4.5) }
        let chunks = P.chunks(from: regions, maxChunk: 28, padding: 0, totalDuration: 60)
        #expect(chunks.allSatisfy { $0.duration <= 28 })
        #expect(chunks.count == 2)
    }

    @Test func paddingIsClampedToAudio() {
        #expect(
            P.chunks(from: [.init(start: 0.1, end: 9.9)], padding: 0.5, totalDuration: 10) == [.init(start: 0, end: 10)]
        )
    }
}

@Suite struct HallucinationFilterTests {
    @Test func dropsConsecutiveRepeats() {
        let segments = ["Va bene.", "va bene", "Allora iniziamo"].enumerated().map {
            TranscribedSegment(start: Double($0), end: Double($0) + 1, text: $1)
        }
        let result = P.filterHallucinations(segments)
        #expect(result.kept.map(\.text) == ["Va bene.", "Allora iniziamo"])
        #expect(result.dropped == 1)
    }

    @Test func dropsNoSpeechAndKnownPhrases() {
        let segments = [
            TranscribedSegment(start: 0, end: 2, text: "Sottotitoli creati dalla comunità Amara.org"),
            TranscribedSegment(start: 2, end: 3, text: "boh", confidence: 0.2, noSpeechProbability: 0.9),
            TranscribedSegment(start: 3, end: 4, text: "   "),
            TranscribedSegment(
                start: 4, end: 6, text: "Partiamo dal budget", confidence: 0.9, noSpeechProbability: 0.1),
        ]
        #expect(P.filterHallucinations(segments).kept.map(\.text) == ["Partiamo dal budget"])
    }
}

@Suite struct SentenceTests {
    @Test func truncatedSentenceOfSameSpeakerIsJoined() {
        let labeled: [(speaker: String, segment: TranscribedSegment)] = [
            ("s1", .init(start: 0, end: 1.2, text: "Partiamo dal")),
            ("s1", .init(start: 1.4, end: 2.4, text: "budget.")),
            ("s1", .init(start: 2.5, end: 3, text: "Poi vediamo")),
        ]
        #expect(P.joinSentences(labeled).map(\.segment.text) == ["Partiamo dal budget.", "Poi vediamo"])
    }

    @Test func speakerChangeAndPauseAreNotCrossed() {
        let labeled: [(speaker: String, segment: TranscribedSegment)] = [
            ("s1", .init(start: 0, end: 1, text: "Allora")),
            ("s2", .init(start: 1.1, end: 2, text: "sì")),
            ("s2", .init(start: 4, end: 5, text: "certo")),
        ]
        #expect(P.joinSentences(labeled).count == 3)
    }
}

@Suite struct SpeakerAssignmentTests {
    let turns = [
        P.SpeakerTurn(speaker: "A", start: 0, end: 10),
        P.SpeakerTurn(speaker: "B", start: 10, end: 20),
    ]

    @Test func largestOverlapWins() {
        let segment = TranscribedSegment(start: 8, end: 15, text: "x")
        #expect(P.assignSpeakers(to: [segment], turns: turns) == ["B"])
    }

    @Test func nearestTurnWhenNoOverlap() {
        let segment = TranscribedSegment(start: 21, end: 22, text: "x")
        #expect(P.assignSpeakers(to: [segment], turns: turns) == ["B"])
    }

    @Test func segmentIsSplitAtSpeakerChange() {
        let words = [
            TranscribedWord(start: 7, end: 8, text: " Va"), TranscribedWord(start: 8, end: 9.5, text: " bene."),
            TranscribedWord(start: 10.2, end: 11, text: " Io"), TranscribedWord(start: 11, end: 12, text: " direi"),
            TranscribedWord(start: 12, end: 12.5, text: " di"), TranscribedWord(start: 12.5, end: 13, text: " sì."),
        ]
        let segment = TranscribedSegment(start: 7, end: 13, text: "Va bene. Io direi di sì.", words: words)
        let result = P.splitBySpeaker([segment], turns: turns, fallback: "s1")
        #expect(result.map(\.speaker) == ["A", "B"])
        #expect(result.map(\.segment.text) == ["Va bene.", "Io direi di sì."])
        #expect(result.map(\.segment.start) == [7, 10.2])
        #expect(result.map(\.segment.end) == [9.5, 13])
    }

    @Test func shortRunIsMergedIntoNeighbour() {
        let words = [
            TranscribedWord(start: 7, end: 9.8, text: " Allora vediamo"),
            TranscribedWord(start: 9.8, end: 10.3, text: " il"),
            TranscribedWord(start: 10.3, end: 11, text: " budget."),
        ]
        let segment = TranscribedSegment(start: 7, end: 11, text: "Allora vediamo il budget.", words: words)
        let result = P.splitBySpeaker([segment], turns: turns, fallback: "s1", minRun: 1.5)
        #expect(result.map(\.speaker) == ["A"])
    }

    @Test func cutSnapsToNearbyPunctuation() {
        let words = [
            TranscribedWord(start: 6, end: 8, text: " Va"), TranscribedWord(start: 8, end: 9.6, text: " bene,"),
            TranscribedWord(start: 9.6, end: 10.4, text: " no?"), TranscribedWord(start: 10.4, end: 12, text: " Io"),
            TranscribedWord(start: 12, end: 13, text: " direi"),
        ]
        let segment = TranscribedSegment(start: 6, end: 13, text: "Va bene, no? Io direi", words: words)
        let result = P.splitBySpeaker([segment], turns: turns, fallback: "s1", minRun: 0)
        #expect(result.map(\.segment.text) == ["Va bene, no?", "Io direi"])
    }

    @Test func segmentWithoutWordsKeepsOneSpeaker() {
        let segment = TranscribedSegment(start: 8, end: 15, text: "x")
        let result = P.splitBySpeaker([segment], turns: turns, fallback: "s1")
        #expect(result.map(\.speaker) == ["B"])
        #expect(result.map(\.segment) == [segment])
    }

    @Test func singleSpeakerSegmentIsUnchanged() {
        let words = [
            TranscribedWord(start: 1, end: 2, text: " Ciao"), TranscribedWord(start: 2, end: 3, text: " a tutti"),
        ]
        let segment = TranscribedSegment(start: 1, end: 3, text: "Ciao a tutti", words: words)
        #expect(P.splitBySpeaker([segment], turns: turns, fallback: "s1").map(\.segment) == [segment])
    }

    @Test func noTurnsUsesFallback() {
        let words = [TranscribedWord(start: 1, end: 2, text: " Ciao")]
        let segment = TranscribedSegment(start: 1, end: 2, text: "Ciao", words: words)
        #expect(P.splitBySpeaker([segment], turns: [], fallback: "s1").map(\.speaker) == ["s1"])
    }

    @Test func roomModeMakesTheMainVoiceMe() {
        let labeled: [(speaker: String, segment: TranscribedSegment)] = [
            ("s1", .init(start: 0, end: 2, text: "ospite")),
            ("s2", .init(start: 2, end: 10, text: "io parlo tanto")),
            ("s3", .init(start: 10, end: 11, text: "terzo")),
            ("s1", .init(start: 11, end: 12, text: "ancora ospite")),
        ]
        let room = P.roomSpeakers(labeled)
        #expect(room.labeled.map(\.speaker) == ["r2", "me", "r3", "r2"])
        #expect(room.others == ["r2", "r3"])
    }

    @Test func idsAreNormalizedByFirstAppearance() {
        let raw = [
            P.SpeakerTurn(speaker: "SPEAKER_07", start: 5, end: 6),
            P.SpeakerTurn(speaker: "SPEAKER_02", start: 0, end: 1),
            P.SpeakerTurn(speaker: "SPEAKER_07", start: 9, end: 10),
        ]
        let result = P.normalizeSpeakerIDs(raw)
        #expect(result.ids == ["s1", "s2"])
        #expect(result.turns.map(\.speaker) == ["s1", "s2", "s2"])
    }

    @Test func voicesFollowTheSameRenaming() {
        let raw = [
            P.SpeakerTurn(speaker: "SPEAKER_07", start: 5, end: 8),
            P.SpeakerTurn(speaker: "SPEAKER_02", start: 0, end: 1),
        ]
        let voices = P.normalizeVoices(
            ["SPEAKER_02": [1, 0], "SPEAKER_07": [0, 1], "SPEAKER_09": [1, 1]], turns: raw)
        #expect(voices == ["s1": [1, 0], "s2": [0, 1]])
    }
}

@Suite struct EchoFilterTests {
    @Test func dropsMicSegmentEchoingSystem() {
        let system = [TranscribedSegment(start: 10, end: 14, text: "Possiamo spostare la consegna a venerdì?")]
        let mic = [
            TranscribedSegment(start: 10.05, end: 14.1, text: "possiamo spostare la consegna a venerdì"),
            TranscribedSegment(start: 15, end: 17, text: "Sì, nessun problema."),
        ]
        let result = P.removeEcho(mic: mic, system: system)
        #expect(result.kept.map(\.text) == ["Sì, nessun problema."])
        #expect(result.dropped == 1)
    }

    @Test func keepsSimilarTextFarApartInTime() {
        let system = [TranscribedSegment(start: 10, end: 12, text: "va bene grazie")]
        let mic = [TranscribedSegment(start: 60, end: 62, text: "va bene grazie")]
        #expect(P.removeEcho(mic: mic, system: system).kept.count == 1)
    }

    @Test func normalizationFoldsAccentsAndPunctuation() {
        #expect(P.normalize("  Perché, PERÒ? ") == "perche pero")
    }
}

@Suite struct ParakeetSegmenterTests {
    func token(_ text: String, _ start: Double) -> ParakeetSegmenter.Token {
        .init(text: text, start: start, end: start + 0.2, confidence: 0.9)
    }

    @Test func splitsOnSentenceEndAndPause() {
        let tokens = [
            token(" Buon", 0), token("giorno", 0.2), token(".", 0.4),
            token(" Come", 0.6), token(" va", 0.8),
            token(" Bene", 3.0),
        ]
        let segments = ParakeetSegmenter.segments(from: tokens)
        #expect(segments.map(\.text) == ["Buongiorno.", "Come va", "Bene"])
        #expect(segments[0].start == 0)
        #expect(abs(segments[1].end - 1.0) < 1e-9)
    }

    @Test func keepsThousandsSeparatorTogether() {
        let tokens = [token(" 512", 0), token(".", 0.2), token("000", 0.4), token(" canzoni", 0.6), token(".", 0.8)]
        #expect(ParakeetSegmenter.segments(from: tokens).map(\.text) == ["512.000 canzoni."])
    }
}
