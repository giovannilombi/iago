import CoreAudio
import Foundation
import IAGOCore

/// Mic track: a HAL IOProc on the selected input device, timestamped with the same host clock as
/// the system tap. Switching device only swaps the IOProc; the writer fills the gap with silence.
final class MicCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "iago.capture.mic", qos: .userInteractive)
    private let handler: @Sendable (CapturedBuffer) -> Void
    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let lock = NSLock()
    private var _lastBufferHostTime: UInt64 = 0

    init(handler: @escaping @Sendable (CapturedBuffer) -> Void) {
        self.handler = handler
    }

    var currentDevice: AudioDeviceID? { deviceID == kAudioObjectUnknown ? nil : deviceID }
    var lastBufferHostTime: UInt64 { lock.withLock { _lastBufferHostTime } }

    func start(device: AudioDeviceID) throws {
        stop()
        let format = try CoreAudioSystem.inputStreamFormat(device)
        guard AudioBufferMixdown.isSupported(format) else {
            throw CaptureError.unsupportedFormat("mic \(format)")
        }
        let sampleRate = format.mSampleRate
        let handler = handler
        var newProcID: AudioDeviceIOProcID?
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&newProcID, device, queue) { [weak self] _, input, inputTime, _, _ in
                let hostTime = inputTime.pointee.mHostTime
                let samples = AudioBufferMixdown.mono(input)
                guard !samples.isEmpty else { return }
                self?.lock.withLock { self?._lastBufferHostTime = hostTime }
                handler(CapturedBuffer(track: .mic, hostTime: hostTime, sampleRate: sampleRate, samples: samples))
            }, "Create mic IOProc")
        do {
            try check(AudioDeviceStart(device, newProcID), "Start mic capture")
        } catch {
            AudioDeviceDestroyIOProcID(device, newProcID!)
            throw error
        }
        deviceID = device
        procID = newProcID
        lock.withLock { _lastBufferHostTime = HostClock.now() }
    }

    func stop() {
        if let procID, deviceID != kAudioObjectUnknown {
            AudioDeviceStop(deviceID, procID)
            AudioDeviceDestroyIOProcID(deviceID, procID)
        }
        procID = nil
        deviceID = AudioDeviceID(kAudioObjectUnknown)
    }
}
