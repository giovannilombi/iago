import Testing

@testable import IAGOCapture

@Suite struct MicDeviceResolverTests {
    let builtIn: UInt32 = 10
    let airPods: UInt32 = 20
    let usb: UInt32 = 30
    let ownPID: Int32 = 1

    func resolve(_ processes: [ProcessAudioInfo], override: UInt32? = nil) -> MicSelection? {
        MicDeviceResolver.resolve(
            processes: processes, ownPID: ownPID, availableInputDevices: [builtIn, airPods, usb],
            defaultInputDevice: builtIn, manualOverride: override)
    }

    @Test func fallsBackToSystemDefault() {
        #expect(resolve([]) == MicSelection(deviceID: builtIn, reason: .systemDefault))
    }

    @Test func followsCallApp() {
        let teams = ProcessAudioInfo(
            pid: 2, bundleID: "com.microsoft.teams2", isRunningInput: true, inputDevices: [airPods])
        #expect(resolve([teams]) == MicSelection(deviceID: airPods, reason: .callApp(bundleID: "com.microsoft.teams2")))
    }

    @Test func callAppWinsOverOtherApps() {
        let recorder = ProcessAudioInfo(
            pid: 2, bundleID: "com.example.voice", isRunningInput: true, inputDevices: [usb])
        let chromeHelper = ProcessAudioInfo(
            pid: 3, bundleID: "com.google.Chrome.helper", isRunningInput: true, inputDevices: [airPods])
        #expect(resolve([recorder, chromeHelper])?.deviceID == airPods)
    }

    @Test func otherAppIsUsedWhenNoCallApp() {
        let other = ProcessAudioInfo(pid: 2, bundleID: "com.example.voice", isRunningInput: true, inputDevices: [usb])
        #expect(resolve([other]) == MicSelection(deviceID: usb, reason: .otherApp(bundleID: "com.example.voice")))
    }

    @Test func ignoresOwnProcessAndIdleProcesses() {
        let own = ProcessAudioInfo(
            pid: ownPID, bundleID: "com.giovannilombi.iago", isRunningInput: true, inputDevices: [usb])
        let idle = ProcessAudioInfo(pid: 2, bundleID: "us.zoom.xos", isRunningInput: false, inputDevices: [airPods])
        #expect(resolve([own, idle])?.reason == .systemDefault)
    }

    @Test func ignoresUnavailableDevices() {
        let zoom = ProcessAudioInfo(pid: 2, bundleID: "us.zoom.xos", isRunningInput: true, inputDevices: [99])
        #expect(resolve([zoom])?.reason == .systemDefault)
    }

    @Test func manualOverrideWins() {
        let zoom = ProcessAudioInfo(pid: 2, bundleID: "us.zoom.xos", isRunningInput: true, inputDevices: [airPods])
        #expect(resolve([zoom], override: usb) == MicSelection(deviceID: usb, reason: .manual))
    }

    /// Chrome following a new default keeps the previous mic open too (2026-10-12, Meet).
    @Test func prefersSystemDefaultAmongSeveralInputs() {
        let chrome = ProcessAudioInfo(
            pid: 2, bundleID: "com.google.Chrome.helper", isRunningInput: true, inputDevices: [builtIn, airPods])
        let selection = MicDeviceResolver.resolve(
            processes: [chrome], ownPID: ownPID, availableInputDevices: [builtIn, airPods, usb],
            defaultInputDevice: airPods, manualOverride: nil, currentDevice: builtIn)
        #expect(selection?.deviceID == airPods)
    }

    @Test func keepsCurrentMicAmongSeveralInputsWithoutDefault() {
        let chrome = ProcessAudioInfo(
            pid: 2, bundleID: "com.google.Chrome.helper", isRunningInput: true, inputDevices: [usb, airPods])
        let selection = MicDeviceResolver.resolve(
            processes: [chrome], ownPID: ownPID, availableInputDevices: [builtIn, airPods, usb],
            defaultInputDevice: builtIn, manualOverride: nil, currentDevice: airPods)
        #expect(selection?.deviceID == airPods)
    }
}

@Suite struct MicFallbackHoldTests {
    let callMic = MicSelection(deviceID: 20, reason: .callApp(bundleID: "us.zoom.xos"))
    let fallback = MicSelection(deviceID: 10, reason: .systemDefault)
    let start: UInt64 = 1_000_000

    func at(_ seconds: Double) -> UInt64 { start + HostClock.ticks(seconds: seconds) }

    func held(
        _ hold: inout MicFallbackHold, current: MicSelection, proposed: MicSelection, currentStillAvailable: Bool,
        now: UInt64
    ) -> Bool {
        hold.shouldHold(current: current, proposed: proposed, currentStillAvailable: currentStillAvailable, now: now)
    }

    @Test func holdsTheCallMicForAFewSeconds() {
        var hold = MicFallbackHold()
        #expect(held(&hold, current: callMic, proposed: fallback, currentStillAvailable: true, now: at(0)))
        #expect(held(&hold, current: callMic, proposed: fallback, currentStillAvailable: true, now: at(2)))
        #expect(!held(&hold, current: callMic, proposed: fallback, currentStillAvailable: true, now: at(3.1)))
    }

    @Test func switchesImmediatelyWhenTheMicIsGone() {
        var hold = MicFallbackHold()
        #expect(!held(&hold, current: callMic, proposed: fallback, currentStillAvailable: false, now: at(0)))
    }

    @Test func followsTheCallAppToAnotherMicImmediately() {
        var hold = MicFallbackHold()
        let other = MicSelection(deviceID: 30, reason: .callApp(bundleID: "us.zoom.xos"))
        #expect(!held(&hold, current: callMic, proposed: other, currentStillAvailable: true, now: at(0)))
    }

    @Test func restartsTheHoldAfterTheCallAppReturns() {
        var hold = MicFallbackHold()
        #expect(held(&hold, current: callMic, proposed: fallback, currentStillAvailable: true, now: at(0)))
        #expect(!held(&hold, current: callMic, proposed: callMic, currentStillAvailable: true, now: at(1)))
        #expect(held(&hold, current: callMic, proposed: fallback, currentStillAvailable: true, now: at(10)))
    }

    @Test func doesNotHoldAManualOrDefaultMic() {
        var hold = MicFallbackHold()
        let manual = MicSelection(deviceID: 20, reason: .manual)
        #expect(!held(&hold, current: manual, proposed: fallback, currentStillAvailable: true, now: at(0)))
    }
}

@Suite struct CallActivityTests {
    @Test func onlyDedicatedCallAppsCapturingAudioCount() {
        let processes = [
            ProcessAudioInfo(pid: 1, bundleID: "com.microsoft.teams2", isRunningInput: true, inputDevices: []),
            ProcessAudioInfo(pid: 2, bundleID: "com.microsoft.teams2.helper", isRunningInput: true, inputDevices: []),
            ProcessAudioInfo(pid: 3, bundleID: "com.google.Chrome.helper", isRunningInput: true, inputDevices: []),
            ProcessAudioInfo(pid: 4, bundleID: "us.zoom.xos", isRunningInput: false, inputDevices: []),
            ProcessAudioInfo(pid: 5, bundleID: "com.giovannilombi.iago", isRunningInput: true, inputDevices: []),
        ]
        #expect(CallActivity.apps(in: processes, ownPID: 5).map(\.name) == ["Teams"])
        #expect(CallActivity.apps(in: [], ownPID: 5).isEmpty)
    }
}
