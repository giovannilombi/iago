import CoreAudio

/// Host time is the shared clock of both tracks (spec 6.4).
public enum HostClock {
    public static func now() -> UInt64 { AudioGetCurrentHostTime() }

    /// Signed interval in seconds from `start` to `end`.
    public static func interval(from start: UInt64, to end: UInt64) -> Double {
        if end >= start {
            return Double(AudioConvertHostTimeToNanos(end - start)) / 1e9
        }
        return -Double(AudioConvertHostTimeToNanos(start - end)) / 1e9
    }

    public static func ticks(seconds: Double) -> UInt64 {
        AudioConvertNanosToHostTime(UInt64(max(0, seconds) * 1e9))
    }
}
