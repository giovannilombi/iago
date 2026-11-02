import AppKit
import SwiftUI

/// Light, dark or as the Mac (the default): chosen from the toolbar, next to Settings.
enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic, light, dark

    static let key = "appearance"
    var id: String { rawValue }

    static var current: AppAppearance {
        UserDefaults.standard.string(forKey: key).flatMap(AppAppearance.init) ?? .automatic
    }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automatico")
        case .light: String(localized: "Chiaro")
        case .dark: String(localized: "Scuro")
        }
    }

    var icon: String {
        switch self {
        case .automatic: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// Applies the choice to every window of IAGO.
    func apply() {
        switch self {
        case .automatic: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// The toolbar menu: Automatico, Chiaro, Scuro.
struct AppearanceMenu: View {
    @AppStorage(AppAppearance.key) private var stored = AppAppearance.automatic.rawValue

    private var selection: AppAppearance { AppAppearance(rawValue: stored) ?? .automatic }

    var body: some View {
        Menu {
            Picker(String(localized: "Aspetto"), selection: $stored) {
                ForEach(AppAppearance.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label(String(localized: "Aspetto"), systemImage: selection.icon)
        }
        .help(String(localized: "Aspetto: automatico (come il Mac), chiaro o scuro"))
        .onChange(of: stored, initial: true) { selection.apply() }
    }
}

/// The light palette (cool grey, L2): no full white, the sidebar darker than the pages. Dark keeps the system's.
enum IAGOColor {
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            })
    }

    private static func hex(_ value: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    /// Behind the content of every page.
    static let page = dynamic(light: hex(0xEDEFF2), dark: .clear)
    /// An opaque page: the inspector on the right.
    static let panel = dynamic(light: hex(0xEDEFF2), dark: .windowBackgroundColor)
    /// Boxes, cards and tiles on a page.
    static let card = dynamic(light: hex(0xF8F9FB), dark: .controlBackgroundColor)
    /// Over the sidebar's material, so it stays darker than the pages.
    static let sidebarTint = dynamic(light: hex(0xDEE1E6).withAlphaComponent(0.75), dark: .clear)
}

extension IAGOColor {
    /// The bars on top of the pages (where, views, tiles): between the sidebar and the page.
    static let bar = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .windowBackgroundColor
                : NSColor(srgbRed: 0xE6 / 255, green: 0xE9 / 255, blue: 0xED / 255, alpha: 1)
        })
    /// Sheets: no full white in light.
    static let sheet = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .windowBackgroundColor
                : NSColor(srgbRed: 0xF2 / 255, green: 0xF4 / 255, blue: 0xF7 / 255, alpha: 1)
        })
}

/// The bar on top of a page: the system's bar material in dark, the cool grey in light.
private struct IAGOBarBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if scheme == .dark {
            content.background(.bar)
        } else {
            content.background(IAGOColor.bar)
        }
    }
}

extension View {
    func iagoBar() -> some View { modifier(IAGOBarBackground()) }
}

extension IAGOColor {
    /// The thread between a box's title and its content (style T2): a little lighter than the box in dark, a little
    /// darker in light, never coloured.
    static let divider = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0x3B / 255, green: 0x3B / 255, blue: 0x40 / 255, alpha: 1)
                : NSColor(srgbRed: 0xCA / 255, green: 0xCF / 255, blue: 0xD7 / 255, alpha: 1)
        })
}

/// A thread from edge to edge of the box under its title: `padding` is the box's inner padding, crossed both ways.
struct BoxTitleDivider: View {
    let padding: CGFloat

    var body: some View {
        Rectangle().fill(IAGOColor.divider).frame(height: 1)
            .padding(.horizontal, -padding)
            .accessibilityHidden(true)
    }
}
