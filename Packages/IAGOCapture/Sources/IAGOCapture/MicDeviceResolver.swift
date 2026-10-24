import CoreAudio

/// Audio state of a process, read from Core Audio process objects (spec 6.2).
public struct ProcessAudioInfo: Equatable, Sendable {
    public var pid: Int32
    public var bundleID: String?
    public var isRunningInput: Bool
    public var inputDevices: [AudioDeviceID]

    public init(pid: Int32, bundleID: String?, isRunningInput: Bool, inputDevices: [AudioDeviceID]) {
        self.pid = pid
        self.bundleID = bundleID
        self.isRunningInput = isRunningInput
        self.inputDevices = inputDevices
    }
}

public struct MicSelection: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case manual
        case callApp(bundleID: String)
        case otherApp(bundleID: String?)
        case systemDefault
    }

    public var deviceID: AudioDeviceID
    public var reason: Reason
}

/// Chooses "the microphone the others hear" (ADR-0004). Pure: all Core Audio state is passed in.
public enum MicDeviceResolver {
    /// Known call apps, highest priority first. Matched as bundle ID prefixes so browser and app
    /// helper processes (e.g. `com.google.Chrome.helper`) count as their parent app.
    public static let callAppBundlePrefixes = [
        "com.microsoft.teams",
        "us.zoom.",
        "com.apple.FaceTime",
        "com.tinyspeck.slackmacgap",
        "com.cisco.webex",
        "com.webex.",
        "com.google.Chrome",
        "com.apple.Safari",
        "com.apple.WebKit",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
    ]

    public static func resolve(
        processes: [ProcessAudioInfo],
        ownPID: Int32,
        availableInputDevices: Set<AudioDeviceID>,
        defaultInputDevice: AudioDeviceID?,
        manualOverride: AudioDeviceID?,
        currentDevice: AudioDeviceID? = nil
    ) -> MicSelection? {
        if let manualOverride, availableInputDevices.contains(manualOverride) {
            return MicSelection(deviceID: manualOverride, reason: .manual)
        }

        let candidates = processes.compactMap { process -> (rank: Int, device: AudioDeviceID, bundleID: String?)? in
            guard process.pid != ownPID, process.isRunningInput,
                let device = preferredDevice(
                    among: process.inputDevices.filter(availableInputDevices.contains),
                    defaultInputDevice: defaultInputDevice, currentDevice: currentDevice)
            else { return nil }
            return (callAppRank(of: process.bundleID), device, process.bundleID)
        }
        if let best = candidates.min(by: { $0.rank < $1.rank }) {
            let reason: MicSelection.Reason =
                if best.rank < callAppBundlePrefixes.count, let bundleID = best.bundleID {
                    .callApp(bundleID: bundleID)
                } else {
                    .otherApp(bundleID: best.bundleID)
                }
            return MicSelection(deviceID: best.device, reason: reason)
        }

        if let defaultInputDevice, availableInputDevices.contains(defaultInputDevice) {
            return MicSelection(deviceID: defaultInputDevice, reason: .systemDefault)
        }
        return nil
    }

    /// A process can list several inputs (Chrome keeps the previous mic open after following a new
    /// default): prefer the system default, then the mic already in use, then the first (ADR-0025).
    static func preferredDevice(
        among devices: [AudioDeviceID], defaultInputDevice: AudioDeviceID?, currentDevice: AudioDeviceID?
    ) -> AudioDeviceID? {
        if let defaultInputDevice, devices.contains(defaultInputDevice) { return defaultInputDevice }
        if let currentDevice, devices.contains(currentDevice) { return currentDevice }
        return devices.first
    }

    static func callAppRank(of bundleID: String?) -> Int {
        guard let bundleID else { return callAppBundlePrefixes.count }
        return callAppBundlePrefixes.firstIndex(where: bundleID.hasPrefix) ?? callAppBundlePrefixes.count
    }
}

/// Delays the fallback to the system default while the call app briefly stops using its mic, as long
/// as that mic is still connected (ADR-0025). A disconnected mic is replaced immediately.
public struct MicFallbackHold: Sendable {
    public static let interval: Double = 3
    private var since: UInt64?

    public init() {}

    /// True when `proposed` must be ignored for now and the current mic kept.
    public mutating func shouldHold(
        current: MicSelection?, proposed: MicSelection, currentStillAvailable: Bool, now: UInt64
    ) -> Bool {
        guard let current, proposed.reason == .systemDefault, proposed.deviceID != current.deviceID,
            currentStillAvailable, current.reason.isAppFollowing
        else {
            since = nil
            return false
        }
        let start = since ?? now
        since = start
        return HostClock.interval(from: start, to: now) < Self.interval
    }
}

extension MicSelection.Reason {
    var isAppFollowing: Bool {
        switch self {
        case .callApp, .otherApp: true
        case .manual, .systemDefault: false
        }
    }
}
