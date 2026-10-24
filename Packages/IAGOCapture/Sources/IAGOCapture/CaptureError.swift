import CoreAudio

public enum CaptureError: Error, Sendable, CustomStringConvertible {
    case coreAudio(OSStatus, String)
    case fileSystem(String)
    case unsupportedFormat(String)
    case noInputDevice
    case invalidState(String)

    public var description: String {
        switch self {
        case .coreAudio(let status, let operation): "\(operation) failed (OSStatus \(status))"
        case .fileSystem(let message): message
        case .unsupportedFormat(let message): "Unsupported audio format: \(message)"
        case .noInputDevice: "No input device available"
        case .invalidState(let message): "Invalid state: \(message)"
        }
    }
}

@inline(__always)
func check(_ status: OSStatus, _ operation: @autoclosure () -> String) throws {
    guard status == noErr else { throw CaptureError.coreAudio(status, operation()) }
}
