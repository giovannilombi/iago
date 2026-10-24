import AppKit
import SwiftUI

/// Opens the main window and the post-recording panel. IAGO is a menu bar app: while a window is open
/// it gets a Dock icon and appears in ⌘-Tab, then goes back to the menu bar only.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    let model: AppModel
    private var mainWindow: NSWindow?
    private var panels: [String: NSPanel] = [:]
    private var recordingAccessory: NSTitlebarAccessoryViewController?
    private var playbackAccessory: NSTitlebarAccessoryViewController?
    private var settingsWindow: NSWindow?
    private var accessoryTimer: Timer?

    init(model: AppModel) {
        self.model = model
        super.init()
        model.openItem = { [weak self] id in self?.showMain(selecting: id) }
        model.openSettings = { [weak self] in self?.showSettings() }
        model.openHelp = { [weak self] in self?.showHelp() }
        model.openTour = { [weak self] in self?.showTour(force: true) }
    }

    func showMain(selecting itemID: String? = nil) {
        if let itemID {
            if model.item(itemID)?.projectId == nil {
                model.select(.library(.unclassified))
            } else {
                model.select(.library(.recent))
            }
            model.selectedItemID = itemID
        }
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered,
                defer: false)
            window.title = "IAGO"
            window.contentView = NSHostingView(rootView: MainView(model: model))
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("IAGOMainWindow")
            if !window.setFrameUsingName("IAGOMainWindow") { window.center() }
            window.delegate = self
            mainWindow = window
            addRecordingAccessory(to: window)
            playbackAccessory = Self.accessory(PlaybackBarHost(model: model), in: window)
        }
        present(mainWindow!)
    }

    static let onboardingKey = "onboarding_done"
    private var onboardingWindow: NSWindow?

    /// First launch (spec 14). Marked done when the user finishes it.
    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 520), styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            window.title = String(localized: "Benvenuto in IAGO")
            window.contentView = NSHostingView(
                rootView: OnboardingView(model: model) { [weak self] in
                    self?.model.perform { try self?.model.archive.setSetting(Self.onboardingKey, "1") }
                    self?.onboardingWindow?.close()
                    self?.showTour()
                })
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            onboardingWindow = window
        }
        present(onboardingWindow!)
    }

    static let tourHiddenKey = "help.tourHidden"
    private var helpWindow: NSWindow?
    private var tourWindow: NSWindow?

    /// "Aiuto di IAGO": topics on how to use the app.
    func showHelp() {
        if helpWindow == nil {
            // Full page: as big as the screen allows.
            let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            let window = NSWindow(
                contentRect: frame.insetBy(dx: frame.width * 0.04, dy: frame.height * 0.04),
                styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = String(localized: "Guida di IAGO")
            window.contentView = NSHostingView(
                rootView: HelpView(model: model) { [weak self] in self?.showTour(force: true) })
            window.isReleasedWhenClosed = false
            window.delegate = self
            helpWindow = window
        }
        present(helpWindow!)
    }

    /// The welcome tour: at launch until "Non mostrare più", or on request from Aiuto.
    func showTour(force: Bool = false) {
        guard force || (try? model.archive.setting(Self.tourHiddenKey)) != "1" else { return }
        if tourWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 400), styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            window.title = String(localized: "Benvenuto in IAGO")
            window.contentView = NSHostingView(
                rootView: WelcomeTour(
                    onClose: { [weak self] hide in
                        if hide { self?.model.perform { try self?.model.archive.setSetting(Self.tourHiddenKey, "1") } }
                        self?.tourWindow?.close()
                    }, openHelp: { [weak self] in self?.showHelp() }))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            tourWindow = window
        }
        present(tourWindow!)
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 540), styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            window.title = String(localized: "Impostazioni di IAGO")
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        present(settingsWindow!)
    }

    /// "Nota vocale…" from the menu bar (FR-216): a small floating panel that starts listening at once.
    func showVoiceNote() {
        let key = "voice-note"
        if let panel = panels[key] {
            present(panel)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360), styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered, defer: false)
        panel.title = String(localized: "Nota vocale")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.contentView = NSHostingView(
            rootView: VoiceNotePanel(model: model) { [weak self, weak panel] in
                panel?.close()
                self?.panels[key] = nil
            })
        panel.delegate = self
        panels[key] = panel
        panel.center()
        present(panel)
    }

    /// FR-20: small, non-modal, closable.
    func showPostRecording(itemID: String) {
        if let panel = panels[itemID] {
            present(panel)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420), styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered, defer: false)
        panel.title = String(localized: "Nuova registrazione")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.contentView = NSHostingView(
            rootView: PostRecordingView(model: model, itemID: itemID) { [weak self, weak panel] in
                panel?.close()
                self?.panels[itemID] = nil
            })
        panel.delegate = self
        panels[itemID] = panel
        panel.center()
        present(panel)
    }

    /// The recording bar sits under the toolbar as a titlebar accessory, shown only while recording.
    /// The playback bar (an audio being listened to) goes under it, in the same way.
    private func addRecordingAccessory(to window: NSWindow) {
        recordingAccessory = Self.accessory(RecordingBarHost(model: model), in: window)
        accessoryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let recording = (self.model.recording?.state ?? .idle) != .idle
                if let accessory = self.recordingAccessory, accessory.isHidden == recording {
                    accessory.isHidden = !recording
                }
                let playing = self.model.player.isActive
                if let accessory = self.playbackAccessory, accessory.isHidden == playing {
                    accessory.isHidden = !playing
                }
            }
        }
    }

    private static func accessory(_ bar: some View, in window: NSWindow) -> NSTitlebarAccessoryViewController {
        let accessory = NSTitlebarAccessoryViewController()
        let host = NSHostingView(rootView: bar)
        host.frame = NSRect(x: 0, y: 0, width: window.frame.width, height: 34)
        host.autoresizingMask = [.width]
        host.sizingOptions = []
        accessory.view = host
        accessory.layoutAttribute = .bottom
        accessory.isHidden = true
        window.addTitlebarAccessoryViewController(accessory)
        return accessory
    }

    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // The bar goes away with the window: the audio stops too, so nothing keeps playing out of reach.
        if (notification.object as? NSWindow) === mainWindow { model.player.close() }
        if let panel = notification.object as? NSPanel, let key = panels.first(where: { $0.value === panel })?.key {
            panels[key] = nil
        }
        Task { @MainActor in
            let ours: [NSWindow] =
                [self.mainWindow, self.settingsWindow, self.onboardingWindow, self.helpWindow, self.tourWindow]
                .compactMap { $0 }
                + Array(self.panels.values)
            let visible = ours.contains { $0.isVisible }
            if !visible { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
