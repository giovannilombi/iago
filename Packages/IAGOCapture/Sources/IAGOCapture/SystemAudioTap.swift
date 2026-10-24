import CoreAudio
import Foundation
import IAGOCore

/// System track (ADR-0003): global process tap excluding IAGO, read through a private aggregate device.
///
/// The aggregate contains only the tap, with no physical sub-device, so changing the output device
/// (speakers, headphones, AirPods) does not affect it. `CaptureEngine` rebuilds it if buffers stop.
final class SystemAudioTap: @unchecked Sendable {
    private let queue = DispatchQueue(label: "iago.capture.system", qos: .userInteractive)
    private let handler: @Sendable (CapturedBuffer) -> Void
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let lock = NSLock()
    private var _lastBufferHostTime: UInt64 = 0

    init(handler: @escaping @Sendable (CapturedBuffer) -> Void) {
        self.handler = handler
    }

    var lastBufferHostTime: UInt64 { lock.withLock { _lastBufferHostTime } }

    func start() throws {
        let ownProcess = try CoreAudioSystem.processObject(for: getpid())
        let exclusions = ownProcess == kAudioObjectUnknown ? [] : [ownProcess]
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: exclusions)
        description.uuid = UUID()
        description.name = "IAGO system tap"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID), "Create process tap")

        let format = try CoreAudioSystem.value(tapID, kAudioTapPropertyFormat, default: AudioStreamBasicDescription())
        guard AudioBufferMixdown.isSupported(format) else {
            stop()
            throw CaptureError.unsupportedFormat("tap \(format)")
        }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "IAGO System Capture",
            kAudioAggregateDeviceUIDKey: "com.giovannilombi.iago.tap.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]
            ],
        ]
        try check(
            AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "Create aggregate device")

        let sampleRate = format.mSampleRate
        let handler = handler
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { [weak self] _, input, inputTime, _, _ in
                let hostTime = inputTime.pointee.mHostTime
                let samples = AudioBufferMixdown.mono(input)
                guard !samples.isEmpty else { return }
                self?.lock.withLock { self?._lastBufferHostTime = hostTime }
                handler(CapturedBuffer(track: .system, hostTime: hostTime, sampleRate: sampleRate, samples: samples))
            }, "Create system IOProc")
        try check(AudioDeviceStart(aggregateID, procID), "Start system capture")
        lock.withLock { _lastBufferHostTime = HostClock.now() }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }
}
