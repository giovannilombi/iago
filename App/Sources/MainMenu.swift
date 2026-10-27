import AppKit

/// The app's menus. IAGO lives in the menu bar and shows these only while a window is open, but they are needed
/// anyway: in macOS the keyboard shortcuts of text fields (⌘C, ⌘V, ⌘X, ⌘A, ⌘Z) and of windows (⌘W) are the key
/// equivalents of menu items. Without an Edit menu, pasting worked only with the right click.
@MainActor
enum MainMenu {
    static func make(openSettings: @escaping @MainActor () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu(String(localized: "IAGO"), app(openSettings: openSettings)))
        menu.addItem(submenu(String(localized: "Modifica"), edit()))
        let window = windowMenu()
        menu.addItem(submenu(String(localized: "Finestra"), window))
        NSApp.windowsMenu = window
        return menu
    }

    private static func app(openSettings: @escaping @MainActor () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            item(String(localized: "Informazioni su IAGO"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        let settings = ClosureMenuItem(title: String(localized: "Impostazioni…"), key: ",", action: openSettings)
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Nascondi IAGO"), #selector(NSApplication.hide(_:)), "h"))
        // Quitting while recording asks first (AppDelegate.applicationShouldTerminate).
        menu.addItem(item(String(localized: "Esci da IAGO"), #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func edit() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(String(localized: "Annulla"), Selector(("undo:")), "z"))
        menu.addItem(item(String(localized: "Ripeti"), Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Taglia"), #selector(NSText.cut(_:)), "x"))
        menu.addItem(item(String(localized: "Copia"), #selector(NSText.copy(_:)), "c"))
        menu.addItem(item(String(localized: "Incolla"), #selector(NSText.paste(_:)), "v"))
        menu.addItem(
            item(
                String(localized: "Incolla e adatta stile"), #selector(NSTextView.pasteAsPlainText(_:)), "v",
                [.command, .option, .shift]))
        menu.addItem(item(String(localized: "Elimina"), #selector(NSText.delete(_:))))
        menu.addItem(item(String(localized: "Seleziona tutto"), #selector(NSText.selectAll(_:)), "a"))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(String(localized: "Chiudi"), #selector(NSWindow.performClose(_:)), "w"))
        menu.addItem(item(String(localized: "Contrai"), #selector(NSWindow.performMiniaturize(_:)), "m"))
        return menu
    }

    private static func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        menu.title = title
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    /// An item sent to the first responder (the focused text field or window).
    private static func item(
        _ title: String, _ action: Selector, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}

/// A menu item that runs a closure (actions of IAGO's own, not of the focused view).
@MainActor private final class ClosureMenuItem: NSMenuItem {
    private let run: @MainActor () -> Void

    init(title: String, key: String, action: @escaping @MainActor () -> Void) {
        run = action
        super.init(title: title, action: #selector(runAction), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func runAction() { run() }
}
