import Foundation

/// The single lane of the Mac's heavy work (ADR-0069): transcription, language model and embedding share the GPU and
/// the memory, so they run one at a time. A chat answer (interactive) goes first: a background piece of work in
/// progress is interrupted and done again after it, from the same step (one block of a summary, one batch of an
/// index). A transcription cannot be interrupted: the chat waits for it, or on Macs with room runs beside it.
///
/// Work is interactive when its task runs inside `EngineLane.$interactive.withValue(true)`; callers deep down
/// (the engine, the embedder) need no parameter for it.
public actor EngineLane {
    public enum Priority: Int, Sendable, Comparable {
        case background, interactive

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Set around the chat and the other things the user is waiting for.
    @TaskLocal public static var interactive = false
    /// Cleared around interactive work that is small and frequent, like the search while typing: it goes before the
    /// next background block but does not interrupt the one in progress, which would otherwise start over at every key.
    @TaskLocal public static var preempts = true

    /// The priority of the calling task.
    public static var currentPriority: Priority { interactive ? .interactive : .background }

    private struct Holder {
        let id: UUID
        let priority: Priority
        let preemptible: Bool
        var cancel: (@Sendable () -> Void)?
    }

    private struct Waiter {
        let id: UUID
        let priority: Priority
        let preemptible: Bool
        let continuation: CheckedContinuation<Void, Never>
    }

    private var holders: [Holder] = []
    private var waiters: [Waiter] = []
    private var preempted: Set<UUID> = []
    private var pausedUntil: Date?
    private let chatBesideTranscription: Bool

    /// - Parameter chatBesideTranscription: an interactive answer may run while a transcription holds the lane.
    public init(chatBesideTranscription: Bool) {
        self.chatBesideTranscription = chatBesideTranscription
    }

    /// Runs `work` when the lane is free. Background work that gets interrupted for a chat runs again afterwards; an
    /// error or a cancellation of the caller ends it.
    public func run<T: Sendable>(
        _ priority: Priority = EngineLane.currentPriority, preemptible: Bool = true,
        preempts: Bool = EngineLane.preempts, _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        while true {
            try Task.checkCancellation()
            let id = UUID()
            await acquire(id, priority: priority, preemptible: preemptible, preempts: preempts)
            if Task.isCancelled {
                release(id)
                throw CancellationError()
            }
            let task = Task { try await work() }
            setCancel(id) { task.cancel() }
            let result = await withTaskCancellationHandler {
                await task.result
            } onCancel: {
                task.cancel()
            }
            let wasPreempted = preempted.remove(id) != nil
            release(id)
            if wasPreempted, !Task.isCancelled, case .failure = result { continue }
            return try result.get()
        }
    }

    /// macOS reports memory pressure: background work stops now and starts again after `duration`; interactive
    /// work is not touched.
    public func pauseBackground(for duration: Duration) {
        let (seconds, attoseconds) = duration.components
        let until = Date().addingTimeInterval(TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18)
        pausedUntil = max(pausedUntil ?? until, until)
        for holder in holders where holder.priority == .background && holder.preemptible {
            preempted.insert(holder.id)
            holder.cancel?()
        }
        Task {
            try? await Task.sleep(for: duration)
            self.resumeAfterPause()
        }
    }

    /// For the menu and the tests: how many are working and waiting.
    public var load: (working: Int, waiting: Int) { (holders.count, waiters.count) }

    // MARK: Lane

    private func acquire(_ id: UUID, priority: Priority, preemptible: Bool, preempts: Bool) async {
        if canStart(priority) {
            holders.append(Holder(id: id, priority: priority, preemptible: preemptible))
            return
        }
        // A caller cancelled while waiting (a chat stopped, a transcription cancelled) leaves at once, instead of
        // waiting for the lane only to give it back.
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume()
                    return
                }
                waiters.append(Waiter(id: id, priority: priority, preemptible: preemptible, continuation: continuation))
                if priority == .interactive, preempts { interruptBackground() }
            }
        } onCancel: {
            Task { await self.stopWaiting(id) }
        }
    }

    private func stopWaiting(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume()
        startWaiting()
    }

    private func canStart(_ priority: Priority) -> Bool {
        if priority == .background {
            if let pausedUntil, pausedUntil > Date() { return false }
            return holders.isEmpty && !waiters.contains { $0.priority == .interactive }
        }
        if holders.isEmpty { return true }
        // Beside a transcription (the only work that cannot be interrupted), when the Mac has room for both.
        return chatBesideTranscription && holders.allSatisfy { $0.priority == .background && !$0.preemptible }
    }

    private func interruptBackground() {
        for holder in holders where holder.priority == .background && holder.preemptible {
            preempted.insert(holder.id)
            holder.cancel?()
        }
    }

    private func setCancel(_ id: UUID, _ cancel: @escaping @Sendable () -> Void) {
        guard let index = holders.firstIndex(where: { $0.id == id }) else { return }
        holders[index].cancel = cancel
        // Interrupted before it even started.
        if preempted.contains(id) { cancel() }
    }

    private func release(_ id: UUID) {
        holders.removeAll { $0.id == id }
        startWaiting()
    }

    private func resumeAfterPause() {
        if let pausedUntil, pausedUntil <= Date() { self.pausedUntil = nil }
        startWaiting()
    }

    /// Interactive work first, then in order of arrival.
    private func startWaiting() {
        while let index = waiters.indices.max(by: { lhs, rhs in
            waiters[lhs].priority != waiters[rhs].priority
                ? waiters[lhs].priority < waiters[rhs].priority : lhs > rhs
        }) {
            let waiter = waiters[index]
            // A background waiter is next only when no interactive one is left, so only lane and pause count.
            guard canStart(waiter.priority) else { return }
            waiters.remove(at: index)
            holders.append(Holder(id: waiter.id, priority: waiter.priority, preemptible: waiter.preemptible))
            waiter.continuation.resume()
        }
    }
}
