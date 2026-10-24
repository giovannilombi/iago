import AppKit

/// "Aggiungi a IAGO" in the Services menu of every app (ADR-0049): the selected text becomes a document to classify,
/// opened in the main window to choose its project. Declared with `NSServices` in the Info.plist.
@MainActor
final class ServiceProvider: NSObject {
    let model: AppModel
    weak var windows: WindowManager?

    init(model: AppModel, windows: WindowManager) {
        self.model = model
        self.windows = windows
    }

    @objc func addToIAGO(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            error.pointee = String(localized: "Non c'è testo da aggiungere a IAGO.") as NSString
            return
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let title = firstLine.count > 60 ? String(firstLine.prefix(60)) + "…" : firstLine
        Task {
            if await model.importText(text, title: title) { windows?.showMain(selecting: model.selectedItemID) }
        }
    }
}
