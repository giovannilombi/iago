import Foundation
import Testing

@testable import IAGOStore

actor Recorder {
    var order: [String] = []
    func add(_ value: String) { order.append(value) }
}

@Suite struct JobQueueTests {
    func waitUntil(_ condition: @Sendable () throws -> Bool) async throws {
        for _ in 0..<200 {
            if try condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out")
    }

    @Test func runsJobsOneAtATimeByPriority() async throws {
        let fixture = try ArchiveFixture()
        let recorder = Recorder()
        let queue = JobQueue(archive: fixture.archive)
        await queue.register("t") { job, progress in
            await recorder.add(job.payload ?? "")
            progress(0.5)
        }
        // Enqueued directly in the database first, so the order is decided by priority, not timing.
        try fixture.archive.enqueueJob(type: "t", itemID: nil, payload: "low")
        try fixture.archive.enqueueJob(type: "t", itemID: nil, payload: "high", priority: 10)
        try await queue.start()
        try await waitUntil { try fixture.archive.activeJobs().isEmpty }
        #expect(await recorder.order == ["high", "low"])
    }

    @Test func aQueuedJobCanGoFirstAndFinishedOnesAreListed() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let first = try archive.enqueueJob(type: "t", itemID: nil, priority: 5)
        let second = try archive.enqueueJob(type: "t", itemID: nil)
        try archive.prioritizeJob(second.id)
        #expect(try archive.activeJobs().map(\.id) == [second.id, first.id])
        try archive.updateJob(first.id) { $0.status = .failed }
        #expect(try archive.finishedJobs(since: .distantPast).map(\.id) == [first.id])
        #expect(try archive.finishedJobs(since: .distantFuture).isEmpty)
    }

    @Test func failuresAreRecorded() async throws {
        let fixture = try ArchiveFixture()
        let queue = JobQueue(archive: fixture.archive)
        struct Boom: Error {}
        await queue.register("t") { _, _ in throw Boom() }
        let job = try await queue.enqueue(type: "t", itemID: nil)
        try await waitUntil { try fixture.archive.job(job.id)?.status == .failed }
        #expect(try fixture.archive.job(job.id)?.error?.contains("Boom") == true)
        #expect(try fixture.archive.job(job.id)?.attempts == 1)
    }

    @Test func runningJobCanBeCancelled() async throws {
        let fixture = try ArchiveFixture()
        let queue = JobQueue(archive: fixture.archive)
        await queue.register("t") { _, _ in try await Task.sleep(for: .seconds(30)) }
        let job = try await queue.enqueue(type: "t", itemID: nil)
        try await waitUntil { try fixture.archive.job(job.id)?.status == .running }
        try await queue.cancel(job.id)
        try await waitUntil { try fixture.archive.job(job.id)?.status == .cancelled }
    }

    @Test func interruptedJobsResumeAtStart() async throws {
        let fixture = try ArchiveFixture()
        let job = try fixture.archive.enqueueJob(type: "t", itemID: nil)
        _ = try fixture.archive.claimNextJob()  // a previous run crashed while this was running
        #expect(try fixture.archive.job(job.id)?.status == .running)

        let queue = JobQueue(archive: fixture.archive)
        await queue.register("t") { _, _ in }
        try await queue.start()
        try await waitUntil { try fixture.archive.job(job.id)?.status == .done }
        #expect(try fixture.archive.job(job.id)?.attempts == 2)
    }

    @Test func waitsWhileNotAllowedToRun() async throws {
        let fixture = try ArchiveFixture()
        let allowed = Flag()
        let queue = JobQueue(archive: fixture.archive, retryInterval: .milliseconds(20)) { allowed.value }
        await queue.register("t") { _, _ in }
        let job = try await queue.enqueue(type: "t", itemID: nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(try fixture.archive.job(job.id)?.status == .queued)
        allowed.value = true
        try await waitUntil { try fixture.archive.job(job.id)?.status == .done }
    }
}

final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
