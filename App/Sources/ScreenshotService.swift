import AppKit
import IAGOIngest
import IAGOStore
import ScreenCaptureKit
import os

/// "Segna momento con screenshot" (ADR-0072): the screen under the pointer (or every screen) without IAGO's own
/// windows, as PNG, with the text read on it by Apple's OCR on the Mac. Needs "Registrazione schermo" in macOS.
@MainActor
enum ScreenshotService {
    /// Archive setting: capture every screen instead of the one under the pointer.
    static let allScreensKey = "screenshots.all_screens"

    struct Shot: Sendable {
        var png: Data
        var text: String?
    }

    enum Failure: LocalizedError {
        case permission, nothingCaptured

        var errorDescription: String? {
            switch self {
            case .permission:
                String(
                    localized:
                        "IAGO non ha il permesso di registrare lo schermo: concedilo in Impostazioni di Sistema › Privacy e sicurezza › Registrazione schermo e audio di sistema."
                )
            case .nothingCaptured: String(localized: "Nessuna schermata catturata.")
            }
        }
    }

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows macOS's request the first time; afterwards macOS only allows it from System Settings.
    @discardableResult
    static func requestPermission() -> Bool { CGRequestScreenCaptureAccess() }

    static func openSystemSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        {
            NSWorkspace.shared.open(url)
        }
    }

    static func capture(allScreens: Bool) async throws -> [Shot] {
        guard hasPermission else {
            requestPermission()
            throw Failure.permission
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let pointer = NSEvent.mouseLocation
        let underPointer = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
        let wanted: Set<CGDirectDisplayID> =
            allScreens
            ? Set(content.displays.map(\.displayID))
            : Set([underPointer.flatMap(displayID) ?? CGMainDisplayID()])
        let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        var shots: [Shot] = []
        for display in content.displays where wanted.contains(display.displayID) {
            let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            let scale = CGFloat(filter.pointPixelScale)
            configuration.width = Int(CGFloat(display.width) * scale)
            configuration.height = Int(CGFloat(display.height) * scale)
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                continue
            }
            // Read on the Mac, off the main thread; a screenshot without text is still kept.
            let text = await Task.detached { try? ContentExtractor.extract(image: image).markdown }.value
            shots.append(Shot(png: png, text: text))
        }
        guard !shots.isEmpty else { throw Failure.nothingCaptured }
        Logger(subsystem: "com.giovannilombi.iago", category: "capture").notice(
            "Screenshot taken: \(shots.count) screen(s)")
        return shots
    }

    private static func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { $0.uint32Value }
    }
}
