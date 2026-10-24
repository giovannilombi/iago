import CoreAudio
import Foundation
import IAGOCore

/// Runs both capture sources for as long as recording is active (including pauses and "new
/// recording" switches, so consecutive sessions have no gap). Re-evaluates the mic on Core Audio
/// notifications and every 2 s (spec 6.2), and rebuilds the system tap if its buffers stop.
public final class CaptureEngine: @unchecked Sendable {
    public enum Event: Sendable {
        case micChanged(AudioDeviceInfo, MicSelection.Reason)
        case micUnavailable
        case systemTapRebuilt
        case failure(String)
    }

    static let staleInterval: Double = 2

    private let control = DispatchQueue(label: "iago.capture.control")
    private let onEvent: @Sendable (Event) -> Void
    private let tap: SystemAudioTap
    private let mic: MicCapture
    private var timer: DispatchSourceTimer?
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var manualOverrideUID: String?
    private var currentSelection: MicSelection?
    private var fallbackHold = MicFallbackHold()
    private var isRunning = false
    private let lock = NSLock()
    private var _currentMic: AudioDeviceInfo?

    public init(
        onBuffer: @escaping @Sendable (CapturedBuffer) -> Void,
        onEvent: @escaping @Sendable (Event) -> Void
    ) {
        self.onEvent = onEvent
        self.tap = SystemAudioTap(handler: onBuffer)
        self.mic = MicCapture(handler: onBuffer)
    }

    public var currentMic: AudioDeviceInfo? { lock.withLock { _currentMic } }

    public static func availableInputDevices() -> [AudioDeviceInfo] {
        CoreAudioSystem.inputDevices()
    }

    /// Current audio process table and the mic the resolver would pick (diagnostics, spec 6.2).
    public static func diagnoseMicSelection() -> (processes: [ProcessAudioInfo], selection: MicSelection?) {
        let devices = CoreAudioSystem.inputDevices()
        let processes = CoreAudioSystem.processes()
        let selection = MicDeviceResolver.resolve(
            processes: processes, ownPID: getpid(), availableInputDevices: Set(devices.map(\.id)),
            defaultInputDevice: CoreAudioSystem.defaultInputDevice(), manualOverride: nil)
        return (processes, selection)
    }

    public func start() throws {
        try control.sync {
            guard !isRunning else { return }
            try tap.start()
            isRunning = true
            reevaluateMic(force: true)
            addListeners()
            let timer = DispatchSource.makeTimerSource(queue: control)
            timer.schedule(deadline: .now() + 2, repeating: 2)
            timer.setEventHandler { [weak self] in self?.poll() }
            timer.resume()
            self.timer = timer
        }
    }

    public func stop() {
        control.sync {
            guard isRunning else { return }
            isRunning = false
            timer?.cancel()
            timer = nil
            removeListeners()
            mic.stop()
            tap.stop()
            currentSelection = nil
            fallbackHold = MicFallbackHold()
            lock.withLock { _currentMic = nil }
        }
    }

    /// nil = automatic (follow the call app).
    public func setMicOverride(uid: String?) {
        control.async { [self] in
            manualOverrideUID = uid
            if isRunning { reevaluateMic(force: false) }
        }
    }

    // MARK: Private (control queue)

    private func poll() {
        guard isRunning else { return }
        let now = HostClock.now()
        let micStale = HostClock.interval(from: mic.lastBufferHostTime, to: now) > Self.staleInterval
        reevaluateMic(force: micStale)
        // The tap is silent (no buffers) while nothing plays: the aligner fills that with silence.
        // It is a fault only if buffers stop while some app is actually playing audio.
        if HostClock.interval(from: tap.lastBufferHostTime, to: now) > Self.staleInterval,
            CoreAudioSystem.isAnyOtherProcessRunningOutput(ownPID: getpid())
        {
            rebuildTap()
        }
    }

    private func reevaluateMic(force: Bool) {
        let devices = CoreAudioSystem.inputDevices()
        let overrideID = manualOverrideUID.flatMap { uid in devices.first { $0.uid == uid }?.id }
        guard
            let selection = MicDeviceResolver.resolve(
                processes: CoreAudioSystem.processes(), ownPID: getpid(),
                availableInputDevices: Set(devices.map(\.id)), defaultInputDevice: CoreAudioSystem.defaultInputDevice(),
                manualOverride: overrideID, currentDevice: mic.currentDevice)
        else {
            if mic.currentDevice != nil || force {
                mic.stop()
                currentSelection = nil
                lock.withLock { _currentMic = nil }
                onEvent(.micUnavailable)
            }
            return
        }
        let currentStillAvailable = mic.currentDevice.map { id in devices.contains { $0.id == id } } ?? false
        if !force,
            fallbackHold.shouldHold(
                current: currentSelection, proposed: selection, currentStillAvailable: currentStillAvailable,
                now: HostClock.now())
        {
            return
        }
        guard force || selection.deviceID != mic.currentDevice else { return }
        guard let info = devices.first(where: { $0.id == selection.deviceID }) else { return }
        do {
            try mic.start(device: selection.deviceID)
            currentSelection = selection
            lock.withLock { _currentMic = info }
            onEvent(.micChanged(info, selection.reason))
        } catch {
            onEvent(.failure("Mic \(info.name): \(error)"))
        }
    }

    private func rebuildTap() {
        tap.stop()
        do {
            try tap.start()
            onEvent(.systemTapRebuilt)
        } catch {
            onEvent(.failure("System tap: \(error)"))
        }
    }

    private func addListeners() {
        let selectors = [
            kAudioHardwarePropertyProcessObjectList,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDevices,
        ]
        for selector in selectors {
            var address = CoreAudioSystem.address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let self else { return }
                // Let the device settle before re-evaluating.
                control.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.poll() }
            }
            if AudioObjectAddPropertyListenerBlock(CoreAudioSystem.systemObject, &address, control, block) == noErr {
                listeners.append((address, block))
            }
        }
    }

    private func removeListeners() {
        for (address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(CoreAudioSystem.systemObject, &address, control, block)
        }
        listeners.removeAll()
    }
}
