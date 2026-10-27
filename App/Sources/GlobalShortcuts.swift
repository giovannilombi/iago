import AppKit
import Carbon.HIToolbox
import IAGOStore
import os

/// Keyboard shortcuts that work in any app (ADR-0072): mark a moment, mark it with a screenshot, start or stop the
/// recording. macOS's hot keys (`RegisterEventHotKey`) need no permission. Each can be changed or turned off in
/// Impostazioni › Registrazione; a combination another app already holds is reported there.
@MainActor
final class GlobalShortcuts {
    enum Action: String, CaseIterable, Identifiable {
        case bookmark, screenshot, record

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bookmark: String(localized: "Segna momento")
            case .screenshot: String(localized: "Segna momento con screenshot")
            case .record: String(localized: "Avvia / Stop registrazione")
            }
        }

        /// ⌃⌥M, ⌃⌥S, ⌃⌥R.
        var defaultShortcut: Shortcut {
            let modifiers = UInt32(controlKey | optionKey)
            switch self {
            case .bookmark: return Shortcut(keyCode: UInt32(kVK_ANSI_M), modifiers: modifiers)
            case .screenshot: return Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers)
            case .record: return Shortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: modifiers)
            }
        }

        var settingKey: String { "shortcut.\(rawValue)" }
    }

    /// A key and Carbon modifiers.
    struct Shortcut: Equatable, Sendable {
        var keyCode: UInt32
        var modifiers: UInt32

        init(keyCode: UInt32, modifiers: UInt32) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }

        /// From a key press in the settings: needs ⌃ or ⌥, so typing never triggers it and ⌘ shortcuts of other apps
        /// (⌘W, ⌘C…) are never taken over.
        init?(event: NSEvent) {
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard !flags.intersection([.control, .option]).isEmpty else { return nil }
            var modifiers = 0
            if flags.contains(.command) { modifiers |= cmdKey }
            if flags.contains(.control) { modifiers |= controlKey }
            if flags.contains(.option) { modifiers |= optionKey }
            if flags.contains(.shift) { modifiers |= shiftKey }
            self.init(keyCode: UInt32(event.keyCode), modifiers: UInt32(modifiers))
        }

        var stored: String { "\(keyCode):\(modifiers)" }

        init?(stored: String) {
            let parts = stored.split(separator: ":").compactMap { UInt32($0) }
            guard parts.count == 2 else { return nil }
            self.init(keyCode: parts[0], modifiers: parts[1])
        }

        /// "⌃⌥M".
        var display: String {
            var text = ""
            if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
            if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
            if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
            if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
            return text + Self.keyName(keyCode)
        }

        static func keyName(_ keyCode: UInt32) -> String {
            let special: [Int: String] = [
                kVK_Space: "Spazio", kVK_Return: "↩", kVK_Tab: "⇥", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
                kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
                kVK_F11: "F11", kVK_F12: "F12",
            ]
            if let name = special[Int(keyCode)] { return name }
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            else { return "#\(keyCode)" }
            let layout = unsafeBitCast(pointer, to: CFData.self)
            var dead: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = CFDataGetBytePtr(layout).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
                UCKeyTranslate(
                    $0, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
            }
            guard status == noErr, length > 0 else { return "#\(keyCode)" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }

    private let archive: Archive
    private let perform: (Action) -> Void
    private var registered: [Action: EventHotKeyRef] = [:]
    /// Shortcuts macOS refused, because another app holds them.
    private(set) var unavailable: Set<Action> = []
    private var handler: EventHandlerRef?
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "app")

    /// The one instance, for the C callback.
    private static weak var current: GlobalShortcuts?

    init(archive: Archive, perform: @escaping (Action) -> Void) {
        self.archive = archive
        self.perform = perform
    }

    /// The shortcut of an action: the user's, the default, or nil when turned off.
    func shortcut(_ action: Action) -> Shortcut? {
        guard let stored = (try? archive.setting(action.settingKey)).flatMap({ $0 }) else {
            return action.defaultShortcut
        }
        return stored == "off" ? nil : Shortcut(stored: stored)
    }

    func set(_ shortcut: Shortcut?, for action: Action) {
        try? archive.setSetting(action.settingKey, shortcut?.stored ?? "off")
        start()
    }

    func reset(_ action: Action) {
        try? archive.setSetting(action.settingKey, action.defaultShortcut.stored)
        start()
    }

    /// While the user types a new combination in the settings, so the old one does not fire.
    func suspend() {
        for ref in registered.values { UnregisterEventHotKey(ref) }
        registered = [:]
    }

    /// (Re)registers every shortcut.
    func start() {
        Self.current = self
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ in
                    var id = EventHotKeyID()
                    GetEventParameter(
                        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                        MemoryLayout<EventHotKeyID>.size, nil, &id)
                    let index = Int(id.id)
                    MainActor.assumeIsolated {
                        guard Action.allCases.indices.contains(index) else { return }
                        GlobalShortcuts.current?.perform(Action.allCases[index])
                    }
                    return noErr
                }, 1, &type, nil, &handler)
        }
        for ref in registered.values { UnregisterEventHotKey(ref) }
        registered = [:]
        unavailable = []
        for (index, action) in Action.allCases.enumerated() {
            guard let shortcut = shortcut(action) else { continue }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: 0x4941_474F, id: UInt32(index)),
                GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registered[action] = ref
            } else {
                unavailable.insert(action)
                logger.notice("Shortcut for \(action.rawValue, privacy: .public) unavailable (\(status))")
            }
        }
    }
}
