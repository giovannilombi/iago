/// Maps host time to the recording timeline, which excludes paused intervals (FR-13).
public struct SessionTimeline: Sendable {
    public let startHostTime: UInt64
    private var pauses: [(start: UInt64, end: UInt64?)] = []

    public init(startHostTime: UInt64) {
        self.startHostTime = startHostTime
    }

    public var isPaused: Bool { pauses.last.map { $0.end == nil } ?? false }

    public mutating func pause(at hostTime: UInt64) {
        guard !isPaused else { return }
        pauses.append((hostTime, nil))
    }

    public mutating func resume(at hostTime: UInt64) {
        guard isPaused, let last = pauses.indices.last else { return }
        pauses[last].end = max(hostTime, pauses[last].start)
    }

    /// Timeline position of `hostTime`, or nil if it falls inside a pause.
    public func position(of hostTime: UInt64) -> Double? {
        var paused = 0.0
        for pause in pauses {
            if hostTime < pause.start { break }
            guard let end = pause.end, hostTime >= end else { return nil }
            paused += HostClock.interval(from: pause.start, to: end)
        }
        return HostClock.interval(from: startHostTime, to: hostTime) - paused
    }

    /// Timeline position at `hostTime`, clamped to the start of the current pause.
    public func elapsed(at hostTime: UInt64) -> Double {
        if let position = position(of: hostTime) { return max(0, position) }
        guard let current = pauses.last(where: { $0.start <= hostTime }) else { return 0 }
        let completed = pauses.lazy.filter { $0.start < current.start }.compactMap { pause in
            pause.end.map { HostClock.interval(from: pause.start, to: $0) }
        }
        return max(0, HostClock.interval(from: startHostTime, to: current.start) - completed.reduce(0, +))
    }
}
