import AppKit
import PDFKit
import Testing

@testable import IAGOIngest

/// Fixtures are generated here (spec 7.6): never real documents in the repository. Vision, PDFKit and AppKit's
/// importers run here: a time limit turns a hang on a CI runner into a failure that names the test.
@Suite(.timeLimit(.minutes(1))) struct ContentExtractorTests {
    /// Vision's text recognition hangs on the GitHub macOS runners (no error, no timeout): the OCR tests run on
    /// developers' Macs (`scripts/test-packages.sh`) and are skipped where `CI` is set.
    static let visionAvailable = ProcessInfo.processInfo.environment["CI"] == nil

    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("iago-ingest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func renderImage(_ lines: [String]) -> CGImage {
        let width = 1400
        let height = 140 + lines.count * 70
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for (index, line) in lines.enumerated() {
            NSAttributedString(
                string: line, attributes: [.font: NSFont.systemFont(ofSize: 40), .foregroundColor: NSColor.black]
            )
            .draw(at: NSPoint(x: 60, y: height - 100 - index * 70))
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    @Test(.enabled(if: Self.visionAvailable)) func ocrReadsItalianText() throws {
        let image = renderImage(["Riunione di avanzamento", "Consegna del progetto entro venerdì"])
        let result = try ContentExtractor.extract(image: image)
        #expect(result.method == .ocr)
        #expect(result.markdown.contains("Riunione di avanzamento"))
        #expect(result.markdown.contains("venerdì"))
        #expect((result.ocrConfidence ?? 0) > 0.5)
    }

    @Test(.enabled(if: Self.visionAvailable)) func pngFileIsRead() throws {
        let url = directory.appendingPathComponent("screen.png")
        let rep = NSBitmapImageRep(cgImage: renderImage(["Budget approvato"]))
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        #expect(try ContentExtractor.extract(url).markdown.contains("Budget approvato"))
    }

    @Test func docxKeepsHeadingsListsAndBold() throws {
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "Verbale\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 24)]))
        text.append(NSAttributedString(string: "Si decide di ", attributes: [.font: NSFont.systemFont(ofSize: 12)]))
        text.append(
            NSAttributedString(string: "spostare la demo", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))
        text.append(NSAttributedString(string: ".\n", attributes: [.font: NSFont.systemFont(ofSize: 12)]))
        let list = NSTextList(markerFormat: .disc, options: 0)
        let style = NSMutableParagraphStyle()
        style.textLists = [list]
        for item in ["Mario: preventivo", "Anna: design"] {
            text.append(
                NSAttributedString(
                    string: "\t•\t\(item)\n",
                    attributes: [.font: NSFont.systemFont(ofSize: 12), .paragraphStyle: style]))
        }
        let url = directory.appendingPathComponent("verbale.docx")
        try text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        .write(to: url)

        let markdown = try ContentExtractor.extract(url).markdown
        #expect(markdown.hasPrefix("# Verbale"))
        #expect(markdown.contains("**spostare la demo**"))
        #expect(markdown.contains("- Mario: preventivo\n- Anna: design"))
    }

    @Test(.enabled(if: Self.visionAvailable)) func pdfWithTextAndScannedPages() throws {
        let url = directory.appendingPathComponent("doc.pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        // Page 1: real text layer.
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSAttributedString(
            string: "Offerta economica per il portale clienti", attributes: [.font: NSFont.systemFont(ofSize: 18)]
        )
        .draw(at: NSPoint(x: 50, y: 760))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        // Page 2: only an image ("scanned").
        context.beginPDFPage(nil)
        context.draw(renderImage(["Firma del cliente"]), in: CGRect(x: 0, y: 600, width: 595, height: 120))
        context.endPDFPage()
        context.closePDF()

        let result = try ContentExtractor.extract(url)
        #expect(result.pageCount == 2)
        #expect(result.method == .pdfMixed)
        #expect(result.markdown.contains("## Pagina 1\n\nOfferta economica per il portale clienti"))
        #expect(result.markdown.contains("Firma del cliente"))
    }

    @Test func htmlAndPlainText() throws {
        let html = directory.appendingPathComponent("mail.html")
        try "<h1>Oggetto</h1><p>Testo con <b>grassetto</b> e <a href=\"https://example.com\">link</a>.</p>".write(
            to: html, atomically: true, encoding: .utf8)
        let markdown = try ContentExtractor.extract(html).markdown
        #expect(markdown.contains("# Oggetto"))
        #expect(markdown.contains("**grassetto**"))
        #expect(markdown.contains("[link](https://example.com)"))

        let txt = directory.appendingPathComponent("note.txt")
        try "riga 1\r\nriga 2".write(to: txt, atomically: true, encoding: .utf8)
        #expect(try ContentExtractor.extract(txt).markdown == "riga 1\nriga 2")
    }

    @Test func unsupportedFilesAreRejected() {
        #expect(!ContentExtractor.canExtract(URL(fileURLWithPath: "/tmp/x.zip")))
        #expect(throws: ExtractionError.self) { try ContentExtractor.extract(URL(fileURLWithPath: "/tmp/x.zip")) }
    }
}
