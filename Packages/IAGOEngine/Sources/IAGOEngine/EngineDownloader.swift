import CryptoKit
import Foundation

/// How far a model download is.
public struct EngineProgress: Sendable, Equatable {
    public var bytes: Int64
    public var total: Int64
    public var bytesPerSecond: Double

    public var fraction: Double { total > 0 ? min(1, Double(bytes) / Double(total)) : 0 }

    public init(bytes: Int64, total: Int64, bytesPerSecond: Double) {
        self.bytes = bytes
        self.total = total
        self.bytesPerSecond = bytesPerSecond
    }
}

public enum EngineDownloadError: Error, Equatable, CustomStringConvertible {
    case checksumMismatch(String)
    case badResponse(Int)

    public var description: String {
        switch self {
        case .checksumMismatch(let path): "SHA-256 mismatch for \(path)"
        case .badResponse(let status): "HTTP status \(status)"
        }
    }
}

/// Downloads a catalog model from its fixed addresses (ADR-0048), only when the user asks: file by file, resuming an
/// interrupted file with an HTTP range, each file checked with SHA-256 before it takes its final name. A file with its
/// final name has therefore been verified; the `.verified` marker comes when all of them are there.
public struct EngineDownloader: Sendable {
    let library: EngineLibrary
    let makeSession: @Sendable (URLSessionDataDelegate) -> URLSession

    public init(library: EngineLibrary) {
        self.init(library: library) { delegate in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 60
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }
    }

    /// Tests pass a session whose configuration serves the files locally.
    init(library: EngineLibrary, makeSession: @escaping @Sendable (URLSessionDataDelegate) -> URLSession) {
        self.library = library
        self.makeSession = makeSession
    }

    /// Cancel the task to stop: what was downloaded stays and the next download resumes from there.
    public func download(
        _ model: EngineModel, progress: @escaping @Sendable (EngineProgress) -> Void,
        onNetworkAccess: @Sendable (String) -> Void
    ) async throws {
        let folder = library.folder(of: model)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let total = model.downloadBytes
        let meter = Meter(total: total, report: progress)
        for file in model.files {
            try Task.checkCancellation()
            let destination = folder.appendingPathComponent(file.path)
            if library.size(destination) == file.size {
                meter.add(file.size)
                continue
            }
            let partial = destination.appendingPathExtension("part")
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            var offset = library.size(partial) ?? 0
            if offset > file.size {
                try FileManager.default.removeItem(at: partial)
                offset = 0
            }
            meter.add(offset)
            if offset < file.size {
                let url = model.url(of: file)
                onNetworkAccess("GET \(url.absoluteString)" + (offset > 0 ? " (da \(offset) byte)" : ""))
                try await fetch(url, to: partial, from: offset, meter: meter)
            }
            guard try Self.sha256(of: partial) == file.sha256 else {
                try? FileManager.default.removeItem(at: partial)
                throw EngineDownloadError.checksumMismatch(file.path)
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: partial, to: destination)
        }
        try library.markVerified(model)
        meter.finish()
    }

    private func fetch(_ url: URL, to partial: URL, from offset: Int64, meter: Meter) async throws {
        if !FileManager.default.fileExists(atPath: partial.path) {
            FileManager.default.createFile(atPath: partial.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: partial)
        defer { try? handle.close() }
        var request = URLRequest(url: url)
        if offset > 0 { request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range") }
        let receiver = Receiver(handle: handle, offset: offset, meter: meter)
        let session = makeSession(receiver)
        defer { session.invalidateAndCancel() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                receiver.start(session.dataTask(with: request), continuation)
            }
        } onCancel: {
            receiver.cancel()
        }
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 16 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Bytes done over the whole model and the speed, reported at most every half second.
final class Meter: @unchecked Sendable {
    private let lock = NSLock()
    private let total: Int64
    private let report: @Sendable (EngineProgress) -> Void
    private var bytes: Int64 = 0
    private var started = Date()
    private var startBytes: Int64 = 0
    private var lastReport = Date.distantPast

    init(total: Int64, report: @escaping @Sendable (EngineProgress) -> Void) {
        self.total = total
        self.report = report
    }

    func add(_ count: Int64) {
        let progress: EngineProgress? = lock.withLock {
            bytes += count
            let now = Date()
            guard now.timeIntervalSince(lastReport) >= 0.5 else { return nil }
            lastReport = now
            let elapsed = now.timeIntervalSince(started)
            return EngineProgress(
                bytes: bytes, total: total,
                bytesPerSecond: elapsed > 1 ? Double(bytes - startBytes) / elapsed : 0)
        }
        if let progress { report(progress) }
    }

    /// Speed counts only what comes from the network, not what was already on disk.
    func resetSpeed() {
        lock.withLock {
            started = Date()
            startBytes = bytes
        }
    }

    func finish() {
        let done = lock.withLock { EngineProgress(bytes: total, total: total, bytesPerSecond: 0) }
        report(done)
    }
}

/// Writes the body of one request to the partial file as it arrives.
final class Receiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private let offset: Int64
    private let meter: Meter
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<Void, Error>?
    private var failure: Error?

    init(handle: FileHandle, offset: Int64, meter: Meter) {
        self.handle = handle
        self.offset = offset
        self.meter = meter
    }

    func start(_ task: URLSessionDataTask, _ continuation: CheckedContinuation<Void, Error>) {
        lock.withLock {
            self.task = task
            self.continuation = continuation
        }
        meter.resetSpeed()
        task.resume()
    }

    func cancel() { lock.withLock { task }?.cancel() }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        do {
            switch status {
            case 206 where offset > 0:
                try handle.seekToEnd()
            case 200:
                // The server ignored the range: start the file again.
                try handle.truncate(atOffset: 0)
                if offset > 0 { meter.add(-offset) }
            default:
                throw EngineDownloadError.badResponse(status)
            }
            completionHandler(.allow)
        } catch {
            lock.withLock { failure = error }
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try handle.write(contentsOf: data)
            meter.add(Int64(data.count))
        } catch {
            lock.withLock { failure = error }
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, failure) = lock.withLock {
            defer { self.continuation = nil }
            return (self.continuation, self.failure)
        }
        if let failure {
            continuation?.resume(throwing: failure)
        } else if let error {
            continuation?.resume(throwing: (error as? URLError)?.code == .cancelled ? CancellationError() : error)
        } else {
            continuation?.resume()
        }
    }
}
