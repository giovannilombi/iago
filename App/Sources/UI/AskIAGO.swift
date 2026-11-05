import SwiftUI

/// The colours of the logo, for the "Chiedi a IAGO" entry points.
enum IAGOBrand {
    static let yellow = Color(red: 0xFD / 255, green: 0xC2 / 255, blue: 0x01 / 255)
    static let red = Color(red: 0xDA / 255, green: 0x21 / 255, blue: 0x24 / 255)
    static let green = Color(red: 0x09 / 255, green: 0x26 / 255, blue: 0x20 / 255)
}

/// The logo in a yellow ring, like the mark of a voice assistant.
struct IAGOMark: View {
    var size: CGFloat = 26

    var body: some View {
        Image("Logo").resizable().scaledToFit().padding(size * 0.12)
            .frame(width: size, height: size)
            .background(Circle().fill(.white))
            .overlay(Circle().strokeBorder(IAGOBrand.yellow, lineWidth: size * 0.09))
    }
}

/// "Chiedi a IAGO" floating at the bottom right of the window (ADR-0049): a quiet pill, Gemini-like, that opens the
/// panel. Its X hides it and the entry moves to the sidebar, so it is never lost.
struct AskIAGOButton: View {
    @Bindable var model: AppModel
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.showsChat = true
            } label: {
                HStack(spacing: 8) {
                    IAGOMark(size: 24)
                    Text(String(localized: "Chiedi a IAGO")).font(.callout.weight(.medium))
                }
                .padding(.leading, 6).padding(.trailing, 10).padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .help(String(localized: "Fai una domanda sui tuoi contenuti (⌘K)"))
            Divider().frame(height: 18)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 26, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "Nascondi: «Chiedi a IAGO» resta nella barra laterale"))
        }
        .padding(.trailing, 4)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.2)))
        .shadow(color: .black.opacity(hovering ? 0.25 : 0.15), radius: hovering ? 12 : 8, y: 3)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// "Chiedi a IAGO" in the sidebar, under Importa, when the floating button is hidden: it opens the panel.
struct AskIAGOSidebarRow: View {
    @Bindable var model: AppModel
    let onRestore: () -> Void

    var body: some View {
        Button {
            model.showsChat.toggle()
        } label: {
            HStack(spacing: 8) {
                IAGOMark(size: 18)
                Text(String(localized: "Chiedi a IAGO")).fontWeight(.medium)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(
                    model.showsChat ? IAGOBrand.yellow.opacity(0.25) : Color.secondary.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .contextMenu {
            Button(String(localized: "Mostra il pulsante in basso a destra")) { onRestore() }
        }
    }
}

/// The right pane with its draggable left edge, for «Chiedi a IAGO» or «Ricerca semplice» (ADR-0092): at least 300
/// points, and the detail keeps at least 320.
struct ChatPane: View {
    @Bindable var model: AppModel
    @Binding var width: Double
    let available: CGFloat
    @State private var dragStart: Double?

    static let minimum: Double = 300
    static let detailMinimum: Double = 320

    static func width(stored: Double, available: CGFloat) -> CGFloat {
        let maximum = max(minimum, Double(available) - detailMinimum)
        return CGFloat(min(max(stored, minimum), maximum))
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.secondary.opacity(0.18)).frame(width: 1)
                .overlay {
                    // A wider invisible handle than the line, with the resize cursor.
                    Color.clear.frame(width: 8).contentShape(Rectangle())
                        .onHover { inside in
                            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let start = dragStart ?? width
                                    dragStart = start
                                    width = Double(
                                        Self.width(stored: start - value.translation.width, available: available))
                                }
                                .onEnded { _ in dragStart = nil })
                }
            if model.showsSearch { SearchPanel(model: model) } else { ChatPanel(model: model) }
        }
    }
}
