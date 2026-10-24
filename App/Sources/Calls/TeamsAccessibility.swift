import AppKit
import ApplicationServices
import IAGOStore
import Observation
import os

/// Teams' mute read through macOS Accessibility (ADR-0051, amended 2026-10-20): where the local API is blocked by
/// IT, IAGO looks for the microphone button in Teams' meeting window and reads its label ("Riattiva microfono" means
/// muted). Switched on and off by the user; the labels are editable in Settings, so a change in Teams needs no new
/// build. Needs the Accessibility permission. Reads labels only, never content.
@MainActor
@Observable
final class TeamsAccessibility {
    private let archive: Archive
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "teams")
    /// The microphone button was found: Teams is in a meeting.
    private(set) var buttonFound = false
    private(set) var isMuted: Bool?
    /// The label read last, shown in Settings to help when Teams changes its wording.
    private(set) var lastLabel: String?
    @ObservationIgnored private var cached: AXUIElement?
    @ObservationIgnored private var lastSearch = Date.distantPast

    static let enabledKey = "teams.accessibility"
    static let mutedKey = "teams.accessibility.muted"
    static let unmutedKey = "teams.accessibility.unmuted"
    static let defaultMuted = "riattiva microfono, riattiva l'audio, riattiva audio, unmute"
    static let defaultUnmuted = "disattiva microfono, disattiva l'audio, disattiva audio, mute"
    static let teamsBundles = ["com.microsoft.teams2", "com.microsoft.teams"]

    init(archive: Archive) {
        self.archive = archive
    }

    var enabled: Bool {
        get { (try? archive.setting(Self.enabledKey)) == "1" }
        set {
            try? archive.setSetting(Self.enabledKey, newValue ? "1" : nil)
            if newValue { requestPermission() }
            reset()
        }
    }

    var mutedLabels: String {
        get { (try? archive.setting(Self.mutedKey)).flatMap { $0 } ?? Self.defaultMuted }
        set { try? archive.setSetting(Self.mutedKey, newValue) }
    }

    var unmutedLabels: String {
        get { (try? archive.setting(Self.unmutedKey)).flatMap { $0 } ?? Self.defaultUnmuted }
        set { try? archive.setSetting(Self.unmutedKey, newValue) }
    }

    static var trusted: Bool { AXIsProcessTrusted() }

    /// Shows macOS's request for the Accessibility permission (it opens the right page of System Settings).
    func requestPermission() {
        // The value of kAXTrustedCheckOptionPrompt, written out: the global is not concurrency-safe in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func reset() {
        cached = nil
        buttonFound = false
        isMuted = nil
    }

    /// One reading; cheap while the button stays the same, a fresh search at most every 3 seconds otherwise.
    func poll() {
        guard enabled, Self.trusted,
            let app = NSWorkspace.shared.runningApplications.first(where: {
                Self.teamsBundles.contains($0.bundleIdentifier ?? "")
            })
        else {
            if buttonFound { reset() }
            return
        }
        if let cached, let label = Self.label(of: cached), let state = state(of: label) {
            apply(label, state)
            return
        }
        guard Date().timeIntervalSince(lastSearch) > 3 else { return }
        lastSearch = Date()
        let root = AXUIElementCreateApplication(app.processIdentifier)
        // Chromium-based apps build their accessibility tree only when asked.
        AXUIElementSetAttributeValue(root, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(root, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        if let (element, label, state) = search(root) {
            cached = element
            apply(label, state)
        } else {
            cached = nil
            if buttonFound { logger.notice("Teams microphone button not found any more") }
            buttonFound = false
            isMuted = nil
        }
    }

    /// The titles of Teams' windows, only to tell which calendar meeting a call is (ADR-0051, amended
    /// 2026-10-20); empty when the Accessibility source is off.
    func windowTitles() -> [String] {
        guard enabled, Self.trusted,
            let app = NSWorkspace.shared.runningApplications.first(where: {
                Self.teamsBundles.contains($0.bundleIdentifier ?? "")
            })
        else { return [] }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        return Self.children(of: root, attribute: kAXWindowsAttribute).compactMap {
            Self.string($0, kAXTitleAttribute)
        }
        .filter { !$0.isEmpty }
    }

    private func apply(_ label: String, _ muted: Bool) {
        if !buttonFound { logger.notice("Teams microphone button found") }
        buttonFound = true
        lastLabel = label
        isMuted = muted
    }

    /// Breadth-first through the windows, at most 6 000 elements.
    private func search(_ root: AXUIElement) -> (AXUIElement, String, Bool)? {
        var queue: [AXUIElement] = Self.children(of: root, attribute: kAXWindowsAttribute)
        var visited = 0
        while !queue.isEmpty, visited < 6_000 {
            let element = queue.removeFirst()
            visited += 1
            if let role = Self.string(element, kAXRoleAttribute),
                ["AXButton", "AXCheckBox", "AXToggle", "AXMenuButton"].contains(role),
                let label = Self.label(of: element), let state = state(of: label)
            {
                return (element, label, state)
            }
            queue += Self.children(of: element, attribute: kAXChildrenAttribute)
        }
        return nil
    }

    /// true: the label is the one shown while muted; false: while speaking; nil: not the microphone button.
    func state(of label: String) -> Bool? {
        let text = label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        func matches(_ list: String) -> Bool {
            list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                .contains {
                    text.contains($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
                }
        }
        // "Unmute" contains "mute": the muted labels are checked first.
        if matches(mutedLabels) { return true }
        if matches(unmutedLabels) { return false }
        return nil
    }

    static func label(of element: AXUIElement) -> String? {
        for attribute in [kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute] {
            if let value = string(element, attribute), !value.isEmpty { return value }
        }
        return nil
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let array = value as? [AXUIElement]
        else { return [] }
        return array
    }
}
