import AppKit

/// Menu bar icon from the logo (the parrot's outline): the dark silhouette minus the coloured regions.
/// Idle it is a template image (macOS tints it); otherwise a small coloured badge marks the state.
enum MenuBarIcon {
    enum Badge {
        case none, recording, paused, attention, busy

        var color: NSColor? {
            switch self {
            case .none: nil
            case .recording: .systemRed
            case .paused: .systemOrange
            case .attention: .systemYellow
            case .busy: .systemBlue
            }
        }
    }

    static let size = NSSize(width: 18, height: 18)

    private static let outline: NSImage? = {
        guard let dark = NSImage(named: "MenuBarDark"), let colors = NSImage(named: "MenuBarColors") else { return nil }
        return NSImage(size: size, flipped: false) { rect in
            dark.draw(in: rect)
            colors.draw(in: rect, from: .zero, operation: .destinationOut, fraction: 1)
            return true
        }
    }()

    static func image(_ badge: Badge, accessibility: String) -> NSImage? {
        guard let outline else { return nil }
        guard let color = badge.color else {
            let image = outline.copy() as? NSImage
            image?.isTemplate = true
            image?.accessibilityDescription = accessibility
            return image
        }
        // Drawn at display time, so the outline follows the menu bar appearance (light or dark).
        let image = NSImage(size: size, flipped: false) { rect in
            let tinted = NSImage(size: rect.size, flipped: false) { inner in
                outline.draw(in: inner)
                NSColor.labelColor.set()
                inner.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: rect)
            let diameter = rect.width * 0.42
            let dot = NSRect(x: rect.maxX - diameter, y: rect.minY, width: diameter, height: diameter)
            NSColor.clear.set()
            NSBezierPath(ovalIn: dot.insetBy(dx: -1.2, dy: -1.2)).fill(with: .clear)
            color.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibility
        return image
    }
}

private extension NSBezierPath {
    /// Clears a ring around the badge so it stays readable over the outline.
    func fill(with operation: NSCompositingOperation) {
        NSGraphicsContext.current?.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = operation
        fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}
