import Foundation
import Testing

@testable import IAGOEngine

/// ADR-0069: one heavy piece of work at a time; the chat goes first.
@Suite(.timeLimit(.minutes(1))) struct EngineLaneTests {
    /// Records the order things happen in.
    actor Log {
        var events: [String] = []
        var running = 0
        var maxRunning = 0
        func add(_ event: String) { events.append(event) }
        func enter() {
            running += 1
            maxRunning = max(maxRunning, running)
        }
        func exit() { running -= 1 }
    }

    @Test func backgroundWorkRunsOneAtATime() async throws {
        let lane = EngineLane(chatBesideTranscription: false)
        let log = Log()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<5 {
                group.addTask {
                    try await lane.run(.background) {
                        await log.enter()
                        try await Task.sleep(for: .milliseconds(20))
                        await log.exit()
                        await log.add("block \(index)")
                    }
                }
            }
            try await group.waitForAll()
        }
        #expect(await log.maxRunning == 1)
        #expect(await log.events.count == 5)
    }

    @Test func theChatInterruptsABlockThatIsThenDoneAgain() async throws {
        let lane = EngineLane(chatBesideTranscription: false)
        let log = Log()
        let attempts = Log()
        let summary = Task {
            try await lane.run(.background) {
                await attempts.add("attempt")
                try await Task.sleep(for: .seconds(5))
                await log.add("summary block")
            }
        }
        try await Task.sleep(for: .milliseconds(100))
        let started = Date()
        try await EngineLane.$interactive.withValue(true) {
            try await lane.run {
                await log.add("chat")
            }
        }
        // The chat did not wait for the block of 5 seconds.
        #expect(Date().timeIntervalSince(started) < 2)
        // The interrupted block starts again after the chat.
        try await Task.sleep(for: .milliseconds(200))
        summary.cancel()
        _ = await summary.result
        #expect(await log.events.first == "chat")
        #expect(await attempts.events.count == 2)
    }

    @Test func theSearchWaitsForTheBlockButGoesBeforeTheNextOne() async throws {
        let lane = EngineLane(chatBesideTranscription: false)
        let log = Log()
        let attempts = Log()
        let summary = Task {
            for block in 1...2 {
                try await lane.run(.background) {
                    await attempts.add("block \(block)")
                    try await Task.sleep(for: .milliseconds(200))
                    await log.add("block \(block)")
                }
            }
        }
        try await Task.sleep(for: .milliseconds(50))
        try await EngineLane.$interactive.withValue(true) {
            try await EngineLane.$preempts.withValue(false) {
                try await lane.run { await log.add("search") }
            }
        }
        try await summary.value
        #expect(await log.events == ["block 1", "search", "block 2"])
        #expect(await attempts.events == ["block 1", "block 2"])
    }

    @Test func aTranscriptionIsNeverInterrupted() async throws {
        let lane = EngineLane(chatBesideTranscription: false)
        let log = Log()
        let transcription = Task {
            try await lane.run(.background, preemptible: false) {
                try await Task.sleep(for: .milliseconds(300))
                await log.add("transcription")
            }
        }
        try await Task.sleep(for: .milliseconds(50))
        try await EngineLane.$interactive.withValue(true) {
            try await lane.run { await log.add("chat") }
        }
        try await transcription.value
        #expect(await log.events == ["transcription", "chat"])
    }

    @Test func onARoomyMacTheChatRunsBesideATranscription() async throws {
        let lane = EngineLane(chatBesideTranscription: true)
        let log = Log()
        let transcription = Task {
            try await lane.run(.background, preemptible: false) {
                try await Task.sleep(for: .milliseconds(300))
                await log.add("transcription")
            }
        }
        try await Task.sleep(for: .milliseconds(50))
        try await EngineLane.$interactive.withValue(true) {
            try await lane.run { await log.add("chat") }
        }
        try await transcription.value
        #expect(await log.events == ["chat", "transcription"])
    }

    @Test func aCallerCancelledWhileWaitingLeavesAtOnce() async throws {
        let lane = EngineLane(chatBesideTranscription: false)
        let transcription = Task {
            try await lane.run(.background, preemptible: false) { try await Task.sleep(for: .seconds(3)) }
        }
        try await Task.sleep(for: .milliseconds(50))
        let chat = Task {
            try await EngineLane.$interactive.withValue(true) { try await lane.run { "answer" } }
        }
        try await Task.sleep(for: .milliseconds(100))
        let cancelled = Date()
        chat.cancel()
        await #expect(throws: CancellationError.self) { try await chat.value }
        #expect(Date().timeIntervalSince(cancelled) < 1)
        #expect(await lane.load.waiting == 0)
        transcription.cancel()
    }

    @Test func errorsAreNotRetried() async {
        struct Broken: Error {}
        let lane = EngineLane(chatBesideTranscription: false)
        let attempts = Log()
        await #expect(throws: Broken.self) {
            try await lane.run(.background) {
                await attempts.add("attempt")
                throw Broken()
            }
        }
        #expect(await attempts.events.count == 1)
        #expect(await lane.load.working == 0)
    }

    @Test func memoryPressurePausesBackgroundWork() async throws {
        let lane = EngineLane(chatBesideTranscription: false)
        let log = Log()
        await lane.pauseBackground(for: .milliseconds(300))
        let started = Date()
        try await lane.run(.background) { await log.add("background") }
        #expect(Date().timeIntervalSince(started) >= 0.25)
        // Interactive work is not paused.
        await lane.pauseBackground(for: .seconds(5))
        let chatStarted = Date()
        try await EngineLane.$interactive.withValue(true) {
            try await lane.run { await log.add("chat") }
        }
        #expect(Date().timeIntervalSince(chatStarted) < 1)
    }
}
