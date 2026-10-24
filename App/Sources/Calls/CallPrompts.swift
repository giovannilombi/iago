import AppKit
import SwiftUI

/// Proposals to record (ADR-0051, user request 2026-10-20): IAGO's own small panels at the top right instead of
/// system notifications, so the two buttons are always visible, the parrot shows, and a proposal stays until the
/// user answers (at most 5 minutes) or, if chosen in Settings, goes after 30 seconds. Overlapping meetings get one
/// panel each, stacked.
@MainActor
final class CallPrompts {
    struct Prompt {
        var id: String
        var title: String
        var message: String
        var primary: String
        var onPrimary: () -> Void
        var onIgnore: () -> Void
        /// Which meeting it is, when IAGO is not sure: one button each, in place of `primary`.
        var choices: [String] = []
        var onChoice: (String) -> Void = { _ in }
    }

    private var panels: [(id: String, panel: NSPanel, timer: Task<Void, Never>)] = []

    static let persistentKey = "calls.promptPersistent"
    static let persistentLifetime: Duration = .seconds(300)
    static let shortLifetime: Duration = .seconds(30)

    /// Persistent by default; Settings can make them go after 30 seconds.
    var persistent: Bool {
        get { UserDefaults.standard.object(forKey: Self.persistentKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.persistentKey) }
    }

    func show(_ prompt: Prompt) {
        if panels.contains(where: { $0.id == prompt.id }) { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        let id = prompt.id
        let view = CallPromptView(
            title: prompt.title, message: prompt.message, primary: prompt.primary,
            choices: prompt.choices,
            onPrimary: { [weak self] in
                prompt.onPrimary()
                self?.close(id)
            },
            onChoice: { [weak self] choice in
                prompt.onChoice(choice)
                self?.close(id)
            },
            onIgnore: { [weak self] in
                prompt.onIgnore()
                self?.close(id)
            })
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        panel.setContentSize(hosting.fittingSize)
        panel.contentView = hosting
        let lifetime = persistent ? Self.persistentLifetime : Self.shortLifetime
        let timer = Task { [weak self] in
            try? await Task.sleep(for: lifetime)
            guard !Task.isCancelled else { return }
            self?.close(id)
        }
        panels.append((id, panel, timer))
        layout()
        panel.orderFrontRegardless()
    }

    func close(_ id: String) {
        guard let index = panels.firstIndex(where: { $0.id == id }) else { return }
        panels[index].timer.cancel()
        panels[index].panel.orderOut(nil)
        panels.remove(at: index)
        layout()
    }

    func closeAll() { for entry in panels { close(entry.id) } }

    /// Stacked from the top right of the main screen, under the menu bar.
    private func layout() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        var top = screen.maxY - 12
        for entry in panels {
            let size = entry.panel.frame.size
            entry.panel.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 12, y: top - size.height))
            top -= size.height + 10
        }
    }
}

struct CallPromptView: View {
    let title: String
    let message: String
    let primary: String
    var choices: [String] = []
    let onPrimary: () -> Void
    var onChoice: (String) -> Void = { _ in }
    let onIgnore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IAGOMark(size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if choices.isEmpty {
                    HStack(spacing: 8) {
                        Button(action: onPrimary) {
                            Text(primary).fontWeight(.semibold).padding(.horizontal, 10)
                        }
                        .buttonStyle(.borderedProminent).tint(IAGOBrand.green)
                        Button(String(localized: "Ignora"), action: onIgnore).buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                            Button {
                                onChoice(choice)
                            } label: {
                                Text(choice).fontWeight(index == 0 ? .semibold : .regular).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(index == 0 ? IAGOBrand.green : nil)
                        }
                        Button(String(localized: "Ignora"), action: onIgnore).buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            Button(action: onIgnore) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 380, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.secondary.opacity(0.2)))
    }
}
