import AVFoundation
import AppKit
import IAGOCapture
import IAGOCore
import IAGOStore
import os

/// Debug-only scripted runs for capture smoke tests, e.g.
/// `open IAGO.app --args -IAGOAutoRecordSeconds 20 -IAGOAutoSplitAt 10`
/// records 20 s, starts a new recording at 10 s, waits for finalization and quits.
/// `-IAGOAutoBookmarkAt N` adds a "Segna momento" bookmark at N s instead.
enum DebugAutomation {
    /// True for scripted runs, which must not open windows.
    static var isActive: Bool {
        #if DEBUG
            UserDefaults.standard.double(forKey: "IAGOAutoRecordSeconds") > 0
        #else
            false
        #endif
    }

    @MainActor
    static func runIfRequested(controller: RecordingController) async {
        #if DEBUG
            let defaults = UserDefaults.standard
            let seconds = defaults.double(forKey: "IAGOAutoRecordSeconds")
            guard seconds > 0 else { return }
            let splitAt = defaults.double(forKey: "IAGOAutoSplitAt")
            let bookmarkAt = defaults.double(forKey: "IAGOAutoBookmarkAt")
            let logger = Logger(subsystem: "com.giovannilombi.iago", category: "debug")
            guard await MicrophonePermission.ensure() else {
                logger.error("Auto record: microphone permission denied")
                return
            }
            do {
                try await controller.start()
                logger.notice("Auto record: started for \(seconds) s")
                if bookmarkAt > 0, bookmarkAt < seconds, splitAt == 0 {
                    try await Task.sleep(for: .seconds(bookmarkAt))
                    let position = await controller.addBookmark(note: "auto")
                    logger.notice("Auto record: bookmark at \(position ?? -1)")
                    try await Task.sleep(for: .seconds(seconds - bookmarkAt))
                } else if splitAt > 0, splitAt < seconds {
                    try await Task.sleep(for: .seconds(splitAt))
                    try await controller.newRecording()
                    logger.notice("Auto record: new recording at \(splitAt) s")
                    try await Task.sleep(for: .seconds(seconds - splitAt))
                } else {
                    try await Task.sleep(for: .seconds(seconds))
                }
                let snapshot = await controller.snapshot()
                logger.notice("Auto record: mic=\(snapshot.micName ?? "none") error=\(snapshot.lastError ?? "none")")
                await controller.stop()
                await controller.waitForFinalizations()
                logger.notice("Auto record: done")
            } catch {
                logger.error("Auto record failed: \(error)")
            }
            // Not from inside this main-actor job: `.terminateLater` needs the main queue free.
            RunLoop.main.perform { MainActor.assumeIsolated { NSApp.terminate(nil) } }
        #endif
    }
}
