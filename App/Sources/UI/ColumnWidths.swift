import AppKit
import SwiftUI

/// The width of the middle column, remembered per place (ADR-0087): «Inbox», «Elementi da classificare», «Recenti»,
/// «Punti chiave» and the others each keep their own; projects, clients, streams, categories and tags share one per
/// view. The first time a place opens, the middle column and the right one are half and half.
struct ContentColumnWidth: NSViewRepresentable {
    let key: String

    static let defaultsKey = "columns.contentWidth"

    func makeNSView(context: Context) -> Probe { Probe() }

    func updateNSView(_ view: Probe, context: Context) { view.key = key }

    final class Probe: NSView {
        var key = "" {
            didSet { if key != oldValue { scheduleApply() } }
        }
        private weak var split: NSSplitView?
        private var applying = false
        /// The split view's width at the last look: a resize of the window is not a choice of the user.
        private var lastWidth: CGFloat = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard window != nil else { return }
            split = findSplit()
            if let split {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(resized), name: NSSplitView.didResizeSubviewsNotification, object: split)
            }
            scheduleApply()
        }

        /// The divider between the middle and right columns stops under the toolbar: the toolbar stays one piece, with
        /// only the sidebar's line across it.
        private func trimDivider(_ split: NSSplitView, after content: NSView) {
            guard let window = split.window else { return }
            let top = window.frame.height - window.contentLayoutRect.maxY
            for divider in split.subviews where String(describing: type(of: divider)).contains("Divider") {
                guard abs(divider.frame.midX - content.frame.maxX) < 8 else { continue }
                divider.wantsLayer = true
                guard let layer = divider.layer else { continue }
                let mask = layer.mask ?? CALayer()
                mask.backgroundColor = NSColor.black.cgColor
                // The layer's y grows upwards: the mask covers everything up to the toolbar's bottom edge.
                mask.frame = CGRect(x: -50, y: 0, width: 100, height: max(divider.bounds.height - top, 0))
                layer.mask = mask
            }
        }

        /// The window's three columns: the nearest vertical split view with three panes.
        private func findSplit() -> NSSplitView? {
            var view = superview
            while let current = view {
                if let split = current as? NSSplitView, split.isVertical, split.arrangedSubviews.count == 3 {
                    return split
                }
                view = current.superview
            }
            return nil
        }

        /// Where the middle column starts on screen: the sidebar floats over the start of its pane.
        private func visibleStart(_ split: NSSplitView, _ content: NSView, _ index: Int) -> CGFloat {
            guard index > 0 else { return content.frame.minX }
            let sidebar = split.arrangedSubviews[index - 1]
            guard !split.isSubviewCollapsed(sidebar), !sidebar.isHidden else { return content.frame.minX }
            return max(content.frame.minX, sidebar.frame.maxX)
        }

        /// The middle pane: the one holding this probe.
        private func contentPane(_ split: NSSplitView) -> (view: NSView, index: Int)? {
            guard let index = split.arrangedSubviews.firstIndex(where: { isDescendant(of: $0) }), index < 2 else {
                return nil
            }
            return (split.arrangedSubviews[index], index)
        }

        /// Twice on the next turns: SwiftUI sets its own widths when the column changes, then ours applies.
        private func scheduleApply() {
            DispatchQueue.main.async { [weak self] in
                self?.apply()
                DispatchQueue.main.async { self?.apply() }
            }
        }

        private func apply() {
            guard let split, let (content, index) = contentPane(split), !key.isEmpty else { return }
            let start = visibleStart(split, content, index)
            let available = split.bounds.width - start - split.dividerThickness
            guard available > 0 else { return }
            let width = min(storedWidth ?? (available / 2).rounded(), available - 280)
            lastWidth = split.bounds.width
            defer { trimDivider(split, after: content) }
            guard abs(content.frame.maxX - start - width) > 1 else { return }
            applying = true
            split.setPosition(start + width, ofDividerAt: index)
            applying = false
        }

        /// A divider dragged by the user (the mouse is down and the window kept its size): the new width is this
        /// place's.
        @objc private func resized(_ notification: Notification) {
            guard !applying, let split, let (content, index) = contentPane(split), !key.isEmpty else { return }
            trimDivider(split, after: content)
            if abs(split.bounds.width - lastWidth) >= 0.5 {
                lastWidth = split.bounds.width
                // Until the user picks a width here, the two columns stay half and half.
                if storedWidth == nil { scheduleApply() }
                return
            }
            guard !DemoMode.isActive, NSEvent.pressedMouseButtons & 1 != 0 else { return }
            var widths =
                UserDefaults.standard.dictionary(forKey: ContentColumnWidth.defaultsKey) as? [String: Double] ?? [:]
            widths[key] = Double((content.frame.maxX - visibleStart(split, content, index)).rounded())
            UserDefaults.standard.set(widths, forKey: ContentColumnWidth.defaultsKey)
        }

        /// This place's width, if the user chose one (never in the demo tour, which shares the user's defaults).
        private var storedWidth: CGFloat? {
            guard !DemoMode.isActive,
                let width =
                    (UserDefaults.standard.dictionary(forKey: ContentColumnWidth.defaultsKey)
                    as? [String: Double])?[key]
            else { return nil }
            return CGFloat(width)
        }
    }
}
