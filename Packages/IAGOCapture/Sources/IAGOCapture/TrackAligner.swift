/// Places incoming buffers on the track by timestamp (spec 6.4).
///
/// Each buffer is compared with its absolute expected position, so errors never accumulate:
/// gaps (device change, tap rebuild, late start) become silence, overlaps are trimmed. Small jitter
/// within `toleranceFrames` is ignored to avoid clicks.
public struct TrackAligner: Sendable {
    public struct Placement: Equatable, Sendable {
        public var silenceFrames: Int
        public var droppedLeadingFrames: Int
    }

    public let sampleRate: Double
    public let toleranceFrames: Int
    public private(set) var framesWritten: Int64 = 0

    public init(sampleRate: Double, toleranceFrames: Int = 480) {
        self.sampleRate = sampleRate
        self.toleranceFrames = toleranceFrames
    }

    /// - Parameters:
    ///   - frameCount: frames in the buffer, already at `sampleRate`.
    ///   - position: timeline position of the buffer's first frame, in seconds.
    public mutating func place(frameCount: Int, at position: Double) -> Placement {
        let expected = Int64((position * sampleRate).rounded())
        let drift = expected - framesWritten
        var placement = Placement(silenceFrames: 0, droppedLeadingFrames: 0)
        if drift > Int64(toleranceFrames) {
            placement.silenceFrames = Int(drift)
        } else if drift < -Int64(toleranceFrames) {
            placement.droppedLeadingFrames = Int(min(-drift, Int64(frameCount)))
        }
        framesWritten += Int64(placement.silenceFrames + frameCount - placement.droppedLeadingFrames)
        return placement
    }
}
