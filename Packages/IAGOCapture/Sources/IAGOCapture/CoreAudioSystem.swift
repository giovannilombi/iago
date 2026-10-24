import CoreAudio
import Foundation

public struct AudioDeviceInfo: Equatable, Sendable, Identifiable {
    public var id: AudioDeviceID
    public var uid: String
    public var name: String
}

/// Thin typed wrappers around `AudioObjectGetPropertyData`.
enum CoreAudioSystem {
    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func value<T: BitwiseCopyable>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, default defaultValue: T
    ) throws -> T {
        var address = address(selector, scope: scope)
        var value = defaultValue
        var size = UInt32(MemoryLayout<T>.size)
        try withUnsafeMutableBytes(of: &value) { raw in
            try check(
                AudioObjectGetPropertyData(object, &address, 0, nil, &size, raw.baseAddress!),
                "Get property \(selector)")
        }
        return value
    }

    static func array<T: BitwiseCopyable>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, zero: T
    ) throws -> [T] {
        var address = address(selector, scope: scope)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size), "Get size \(selector)")
        var values = [T](repeating: zero, count: Int(size) / MemoryLayout<T>.stride)
        guard !values.isEmpty else { return [] }
        try values.withUnsafeMutableBytes { raw in
            try check(
                AudioObjectGetPropertyData(object, &address, 0, nil, &size, raw.baseAddress!), "Get array \(selector)")
        }
        return Array(values.prefix(Int(size) / MemoryLayout<T>.stride))
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String? {
        var address = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value), "Get string \(selector)")
        return value?.takeRetainedValue() as String?
    }

    // MARK: Processes

    static func processObject(for pid: pid_t) throws -> AudioObjectID {
        var address = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(
                systemObject, &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object),
            "Translate PID to process object")
        return object
    }

    static func processes() -> [ProcessAudioInfo] {
        let objects = (try? array(systemObject, kAudioHardwarePropertyProcessObjectList, zero: AudioObjectID(0))) ?? []
        return objects.compactMap { object in
            guard let pid = try? value(object, kAudioProcessPropertyPID, default: pid_t(0)) else { return nil }
            let running = (try? value(object, kAudioProcessPropertyIsRunningInput, default: UInt32(0))) ?? 0
            let devices =
                running != 0
                ? (try? array(
                    object, kAudioProcessPropertyDevices, scope: kAudioObjectPropertyScopeInput,
                    zero: AudioObjectID(0))) ?? []
                : []
            return ProcessAudioInfo(
                pid: pid, bundleID: try? string(object, kAudioProcessPropertyBundleID),
                isRunningInput: running != 0, inputDevices: devices)
        }
    }

    /// True when a process other than `ownPID` is playing audio. The system tap delivers no buffers
    /// while nothing plays, so a stale tap is only a fault when this is true.
    static func isAnyOtherProcessRunningOutput(ownPID: pid_t) -> Bool {
        let objects = (try? array(systemObject, kAudioHardwarePropertyProcessObjectList, zero: AudioObjectID(0))) ?? []
        return objects.contains { object in
            guard let pid = try? value(object, kAudioProcessPropertyPID, default: pid_t(0)), pid != ownPID else {
                return false
            }
            return ((try? value(object, kAudioProcessPropertyIsRunningOutput, default: UInt32(0))) ?? 0) != 0
        }
    }

    // MARK: Devices

    static func defaultInputDevice() -> AudioDeviceID? {
        let id = try? value(systemObject, kAudioHardwarePropertyDefaultInputDevice, default: AudioDeviceID(0))
        return id.flatMap { $0 == kAudioObjectUnknown ? nil : $0 }
    }

    static func defaultOutputDevice() -> AudioDeviceID? {
        let id = try? value(systemObject, kAudioHardwarePropertyDefaultOutputDevice, default: AudioDeviceID(0))
        return id.flatMap { $0 == kAudioObjectUnknown ? nil : $0 }
    }

    static func inputDevices() -> [AudioDeviceInfo] {
        let ids = (try? array(systemObject, kAudioHardwarePropertyDevices, zero: AudioDeviceID(0))) ?? []
        return ids.compactMap { id in
            guard hasInputStreams(id), let info = deviceInfo(id), !isVoiceProcessingAggregate(info) else { return nil }
            return info
        }
    }

    /// The hidden device macOS builds for a call app's echo cancellation (Teams, FaceTime…): not a microphone.
    static func isVoiceProcessingAggregate(_ info: AudioDeviceInfo) -> Bool {
        info.uid.hasPrefix("VPAUAggregateAudioDevice") || info.name.hasPrefix("VPAUAggregateAudioDevice")
    }

    static func deviceInfo(_ id: AudioDeviceID) -> AudioDeviceInfo? {
        guard let uid = try? string(id, kAudioDevicePropertyDeviceUID) else { return nil }
        let name = (try? string(id, kAudioObjectPropertyName)) ?? uid
        return AudioDeviceInfo(id: id, uid: uid, name: name)
    }

    static func hasInputStreams(_ id: AudioDeviceID) -> Bool {
        let streams = try? array(
            id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput, zero: AudioStreamID(0))
        return !(streams ?? []).isEmpty
    }

    static func isAlive(_ id: AudioDeviceID) -> Bool {
        ((try? value(id, kAudioDevicePropertyDeviceIsAlive, default: UInt32(0))) ?? 0) != 0
    }

    static func inputStreamFormat(_ id: AudioDeviceID) throws -> AudioStreamBasicDescription {
        try value(
            id, kAudioDevicePropertyStreamFormat, scope: kAudioObjectPropertyScopeInput,
            default: AudioStreamBasicDescription())
    }
}
