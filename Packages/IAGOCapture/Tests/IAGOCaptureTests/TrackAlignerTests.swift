import Testing

@testable import IAGOCapture

@Suite struct TrackAlignerTests {
    @Test func contiguousBuffersAreWrittenAsIs() {
        var aligner = TrackAligner(sampleRate: 48_000)
        for index in 0..<100 {
            let placement = aligner.place(frameCount: 480, at: Double(index) * 0.01)
            #expect(placement == .init(silenceFrames: 0, droppedLeadingFrames: 0))
        }
        #expect(aligner.framesWritten == 48_000)
    }

    @Test func gapIsFilledWithSilence() {
        var aligner = TrackAligner(sampleRate: 48_000)
        _ = aligner.place(frameCount: 48_000, at: 0)
        let placement = aligner.place(frameCount: 480, at: 1.5)
        #expect(placement.silenceFrames == 24_000)
        #expect(aligner.framesWritten == 48_000 + 24_000 + 480)
    }

    @Test func overlapIsTrimmed() {
        var aligner = TrackAligner(sampleRate: 48_000)
        _ = aligner.place(frameCount: 48_000, at: 0)
        let placement = aligner.place(frameCount: 4_800, at: 0.95)
        #expect(placement.droppedLeadingFrames == 2_400)
        #expect(aligner.framesWritten == 48_000 + 2_400)
    }

    @Test func jitterWithinToleranceIsIgnored() {
        var aligner = TrackAligner(sampleRate: 48_000, toleranceFrames: 480)
        _ = aligner.place(frameCount: 480, at: 0)
        let placement = aligner.place(frameCount: 480, at: 0.0105)
        #expect(placement == .init(silenceFrames: 0, droppedLeadingFrames: 0))
    }

    /// Device clock 0.01% fast against host time for 2 hours: the error stays within tolerance.
    @Test func clockDriftStaysBounded() {
        var aligner = TrackAligner(sampleRate: 48_000, toleranceFrames: 480)
        let deviceRate = 48_004.8
        var deviceFrames = 0.0
        var maxError = 0.0
        for _ in 0..<(2 * 3600 * 100) {
            let position = deviceFrames / deviceRate
            _ = aligner.place(frameCount: 480, at: position)
            deviceFrames += 480
            let error = abs(Double(aligner.framesWritten) - deviceFrames / deviceRate * 48_000) / 48_000
            maxError = max(maxError, error)
        }
        #expect(maxError < 0.05)
    }

    @Test func bufferBeforeStartIsDropped() {
        var aligner = TrackAligner(sampleRate: 48_000)
        let placement = aligner.place(frameCount: 960, at: -0.1)
        #expect(placement.droppedLeadingFrames == 960)
        #expect(aligner.framesWritten == 0)
    }
}
