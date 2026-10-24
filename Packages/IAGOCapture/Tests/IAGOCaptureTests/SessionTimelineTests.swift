import Testing

@testable import IAGOCapture

@Suite struct SessionTimelineTests {
    let start: UInt64 = 1_000_000
    func t(_ seconds: Double) -> UInt64 { start + HostClock.ticks(seconds: seconds) }

    @Test func positionWithoutPauses() throws {
        let timeline = SessionTimeline(startHostTime: start)
        #expect(try #require(timeline.position(of: t(10))) == 10.0)
    }

    @Test func pausedIntervalIsExcluded() throws {
        var timeline = SessionTimeline(startHostTime: start)
        timeline.pause(at: t(10))
        #expect(timeline.isPaused)
        #expect(timeline.position(of: t(12)) == nil)
        timeline.resume(at: t(15))
        let position = try #require(timeline.position(of: t(20)))
        #expect(abs(position - 15) < 1e-6)
    }

    @Test func elapsedFreezesDuringPause() {
        var timeline = SessionTimeline(startHostTime: start)
        timeline.pause(at: t(10))
        #expect(abs(timeline.elapsed(at: t(50)) - 10) < 1e-6)
    }

    @Test func bufferBeforePauseStillCounts() throws {
        var timeline = SessionTimeline(startHostTime: start)
        timeline.pause(at: t(10))
        timeline.resume(at: t(15))
        let position = try #require(timeline.position(of: t(9)))
        #expect(abs(position - 9) < 1e-6)
    }
}
