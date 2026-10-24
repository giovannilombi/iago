import Foundation
import GRDB

/// A persistent background job (spec 7.4): survives restarts, one heavy job runs at a time.
public struct Job: Codable, FetchableRecord, MutablePersistableRecord, Sendable, Hashable, Identifiable {
    public enum Status: String, Codable, Sendable { case queued, running, done, failed, cancelled }

    public static let databaseTableName = "job"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var itemId: String?
    public var type: String
    public var status: Status
    /// Higher runs first; ties run in creation order.
    public var priority: Int
    public var progress: Double
    public var attempts: Int
    public var error: String?
    /// JSON parameters of the job.
    public var payload: String?
    public var createdAt: Date
    public var updatedAt: Date

    public var isActive: Bool { status == .queued || status == .running }
}

extension Archive {
    @discardableResult
    public func enqueueJob(type: String, itemID: String?, payload: String? = nil, priority: Int = 0) throws -> Job {
        let now = self.now()
        var job = Job(
            id: newID(at: now), itemId: itemID, type: type, status: .queued, priority: priority, progress: 0,
            attempts: 0,
            payload: payload, createdAt: now, updatedAt: now)
        try database.writer.write { db in try job.insert(db) }
        return job
    }

    public func job(_ id: String) throws -> Job? {
        try database.writer.read { db in try Job.fetchOne(db, key: id) }
    }

    /// Queued and running jobs, in execution order.
    public func activeJobs() throws -> [Job] {
        try database.writer.read { db in
            try Job.filter([Job.Status.queued.rawValue, Job.Status.running.rawValue].contains(Column("status")))
                .order(Column("status").desc, Column("priority").desc, Column("created_at")).fetchAll(db)
        }
    }

    /// "Fai prima questo": a queued job goes ahead of the others.
    public func prioritizeJob(_ id: String) throws {
        let top = try database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT MAX(priority) FROM job WHERE status = 'queued'") ?? 0
        }
        try updateJob(id) { if $0.status == .queued { $0.priority = top + 1 } }
    }

    /// Jobs that ended (done, failed or cancelled) since `date`, newest first ("Attività", ADR-0055).
    public func finishedJobs(since date: Date, limit: Int = 50) throws -> [Job] {
        try database.writer.read { db in
            try Job.filter(
                [Job.Status.done.rawValue, Job.Status.failed.rawValue, Job.Status.cancelled.rawValue]
                    .contains(Column("status")) && Column("updated_at") >= date
            )
            .order(Column("updated_at").desc).limit(limit).fetchAll(db)
        }
    }

    public func jobs(itemID: String) throws -> [Job] {
        try database.writer.read { db in
            try Job.filter(Column("item_id") == itemID).order(Column("created_at").desc).fetchAll(db)
        }
    }

    /// Claims the next queued job, marking it running in the same transaction.
    func claimNextJob() throws -> Job? {
        let now = self.now()
        return try database.writer.write { db in
            guard
                var job = try Job.filter(Column("status") == Job.Status.queued.rawValue)
                    .order(Column("priority").desc, Column("created_at")).fetchOne(db)
            else { return nil }
            job.status = .running
            job.attempts += 1
            job.updatedAt = now
            try job.update(db)
            return job
        }
    }

    func updateJob(_ id: String, _ change: @Sendable (inout Job) -> Void) throws {
        let now = self.now()
        try database.writer.write { db in
            guard var job = try Job.fetchOne(db, key: id) else { return }
            change(&job)
            job.updatedAt = now
            try job.update(db)
        }
    }

    /// Jobs left running by a crash or quit go back to the queue (spec 7.4: resumed at restart).
    func requeueInterruptedJobs() throws {
        let now = self.now()
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE job SET status = 'queued', progress = 0, updated_at = ? WHERE status = 'running'",
                arguments: [now])
        }
    }
}

/// Runs persistent jobs one at a time (spec 5.2, 7.4) at `.utility` priority. Handlers are registered by
/// job type; the app provides them (e.g. transcription), so this module stays independent of them.
public actor JobQueue {
    public typealias Progress = @Sendable (Double) -> Void
    public typealias Handler = @Sendable (Job, @escaping Progress) async throws -> Void

    public enum Event: Sendable {
        case started(Job)
        case progress(jobID: String, itemID: String?, fraction: Double)
        case finished(Job)
    }

    private let archive: Archive
    private var handlers: [String: Handler] = [:]
    private var worker: Task<Void, Never>?
    private var running: (job: Job, task: Task<Void, Error>)?
    private var cancelledJobIDs: Set<String> = []
    /// Checked before each job; e.g. "only on power" (spec 4.3). While false the queue waits.
    private let canRun: @Sendable () -> Bool
    private let retryInterval: Duration
    private let continuation: AsyncStream<Event>.Continuation
    public nonisolated let events: AsyncStream<Event>

    public init(
        archive: Archive, retryInterval: Duration = .seconds(60), canRun: @escaping @Sendable () -> Bool = { true }
    ) {
        self.archive = archive
        self.canRun = canRun
        self.retryInterval = retryInterval
        (events, continuation) = AsyncStream.makeStream(of: Event.self)
    }

    public func register(_ type: String, handler: @escaping Handler) {
        handlers[type] = handler
    }

    /// Requeues jobs interrupted by a previous run and starts processing.
    public func start() throws {
        try archive.requeueInterruptedJobs()
        wake()
    }

    @discardableResult
    public func enqueue(type: String, itemID: String?, payload: String? = nil, priority: Int = 0) throws -> Job {
        let job = try archive.enqueueJob(type: type, itemID: itemID, payload: payload, priority: priority)
        wake()
        return job
    }

    /// Cancels a queued job, or stops the running one (spec 7.4: cancellable from the UI).
    public func cancel(_ jobID: String) throws {
        if let running, running.job.id == jobID {
            cancelledJobIDs.insert(jobID)
            running.task.cancel()
        } else {
            try archive.updateJob(jobID) { if $0.status == .queued { $0.status = .cancelled } }
        }
    }

    public var runningJob: Job? { running?.job }

    private func wake() {
        guard worker == nil else { return }
        worker = Task(priority: .utility) { await self.drain() }
    }

    private func drain() async {
        defer { worker = nil }
        while !Task.isCancelled {
            if !canRun() {
                // Keep the jobs queued; check again later.
                guard (try? archive.activeJobs().isEmpty) == false else { return }
                try? await Task.sleep(for: retryInterval)
                continue
            }
            guard let job = try? archive.claimNextJob() else { return }
            await run(job)
        }
    }

    private func run(_ job: Job) async {
        continuation.yield(.started(job))
        guard let handler = handlers[job.type] else {
            finish(job.id, status: .failed, error: "No handler for job type \(job.type)")
            return
        }
        let archive = self.archive
        let continuation = self.continuation
        let progress: Progress = { fraction in
            let clamped = min(1, max(0, fraction))
            try? archive.updateJob(job.id) { $0.progress = clamped }
            continuation.yield(.progress(jobID: job.id, itemID: job.itemId, fraction: clamped))
        }
        let task = Task(priority: .utility) { try await handler(job, progress) }
        running = (job, task)
        let result = await task.result
        running = nil
        switch result {
        case .success:
            finish(job.id, status: .done, error: nil, progress: 1)
        case .failure(let error):
            let cancelled = cancelledJobIDs.remove(job.id) != nil || error is CancellationError
            finish(job.id, status: cancelled ? .cancelled : .failed, error: cancelled ? nil : "\(error)")
        }
    }

    private func finish(_ id: String, status: Job.Status, error: String?, progress: Double? = nil) {
        try? archive.updateJob(id) { job in
            job.status = status
            job.error = error
            if let progress { job.progress = progress }
        }
        if let job = try? archive.job(id) { continuation.yield(.finished(job)) }
    }
}
