import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision

/// Result of turning a file into Markdown (spec 7.6): the text plus how it was obtained.
public struct Extraction: Sendable, Equatable {
    public enum Method: String, Codable, Sendable {
        case plainText = "text"
        case richText = "attributed"
        case pdfText = "pdf_text"
        case ocr
        /// PDF with some pages as text and some through OCR.
        case pdfMixed = "pdf_mixed"
    }

    public var markdown: String
    public var method: Method
    public var pageCount: Int?
    /// Mean OCR confidence (0…1), nil when no OCR was needed.
    public var ocrConfidence: Double?
}

public enum ExtractionError: Error, Sendable, CustomStringConvertible {
    case unsupported(String)
    case unreadable(String)

    public var description: String {
        switch self {
        case .unsupported(let name): "Unsupported file type: \(name)"
        case .unreadable(let name): "Cannot read \(name)"
        }
    }
}

/// Local text extraction and OCR (ADR-0019): images through Vision, PDF through PDFKit (OCR for pages
/// without text), DOCX/RTF/HTML through `NSAttributedString`, TXT/MD as they are. No network.
public enum ContentExtractor {
    /// Languages for OCR (spec 7.6).
    static let ocrLanguages = ["it-IT", "en-US"]

    public static func canExtract(_ url: URL) -> Bool { kind(of: url) != nil }

    enum Kind { case image, pdf, html, rich, plain }

    static func kind(of url: URL) -> Kind? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .pdf) { return .pdf }
        // HTML without a web engine: AppKit's HTML import loads WebKit, which can hang off the main thread.
        if type.conforms(to: .html) { return .html }
        if type.conforms(to: .rtf) || type.conforms(to: .rtfd)
            || ["docx", "doc", "odt", "webarchive"].contains(url.pathExtension.lowercased())
        {
            return .rich
        }
        if type.conforms(to: .plainText) || ["md", "markdown"].contains(url.pathExtension.lowercased()) {
            return .plain
        }
        return nil
    }

    public static func extract(_ url: URL) throws -> Extraction {
        switch kind(of: url) {
        case .image:
            guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw ExtractionError.unreadable(url.lastPathComponent)
            }
            return try extract(image: image)
        case .pdf: return try extractPDF(url)
        case .html:
            let data = try Data(contentsOf: url)
            let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            return Extraction(markdown: HTMLToMarkdown.convert(html), method: .richText)
        case .rich:
            let text = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            return Extraction(markdown: MarkdownWriter.markdown(from: text), method: .richText)
        case .plain:
            let data = try Data(contentsOf: url)
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            return Extraction(markdown: text.replacingOccurrences(of: "\r\n", with: "\n"), method: .plainText)
        case nil:
            throw ExtractionError.unsupported(url.lastPathComponent)
        }
    }

    /// OCR of an image (screenshots, photos of documents).
    public static func extract(image: CGImage) throws -> Extraction {
        let (text, confidence) = try recognize(image)
        return Extraction(markdown: text, method: .ocr, ocrConfidence: confidence)
    }

    // MARK: PDF

    static func extractPDF(_ url: URL) throws -> Extraction {
        guard let document = PDFDocument(url: url) else { throw ExtractionError.unreadable(url.lastPathComponent) }
        var sections: [String] = []
        var ocrPages = 0
        var confidences: [Double] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // A scanned page has no text layer (or almost none): read it with OCR.
            if text.count < 20, let image = render(page) {
                let (ocr, confidence) = try recognize(image)
                if !ocr.isEmpty {
                    text = ocr
                    ocrPages += 1
                    confidences.append(confidence ?? 0)
                }
            }
            sections.append(document.pageCount > 1 ? "## Pagina \(index + 1)\n\n\(paragraphs(text))" : paragraphs(text))
        }
        let method: Extraction.Method =
            ocrPages == 0 ? .pdfText : ocrPages == document.pageCount ? .ocr : .pdfMixed
        return Extraction(
            markdown: sections.joined(separator: "\n\n"), method: method, pageCount: document.pageCount,
            ocrConfidence: confidences.isEmpty ? nil : confidences.reduce(0, +) / Double(confidences.count))
    }

    /// PDF text has a line break at every visual line: lines are joined into paragraphs.
    static func paragraphs(_ text: String) -> String {
        text.components(separatedBy: "\n\n").map { block in
            block.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }.joined(separator: " ")
        }
        .filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    static func render(_ page: PDFPage, scale: CGFloat = 2) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0,
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    // MARK: OCR

    /// Recognized lines, grouped into paragraphs by vertical gaps; mean confidence.
    static func recognize(_ image: CGImage) throws -> (String, Double?) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ocrLanguages
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map {
                (box: observation.boundingBox, text: $0.string, confidence: Double($0.confidence))
            }
        }
        guard !observations.isEmpty else { return ("", nil) }
        // Top to bottom (Vision's origin is bottom left), then left to right.
        let lines = observations.sorted { a, b in
            abs(a.box.midY - b.box.midY) > min(a.box.height, b.box.height) / 2
                ? a.box.midY > b.box.midY : a.box.minX < b.box.minX
        }
        var output = ""
        var previous: CGRect?
        for line in lines {
            if let previous {
                let sameRow = abs(previous.midY - line.box.midY) < min(previous.height, line.box.height) / 2
                let gap = previous.minY - line.box.maxY
                output += sameRow ? "  " : gap > line.box.height * 0.9 ? "\n\n" : "\n"
            }
            output += line.text
            previous = line.box
        }
        let confidence = observations.map(\.confidence).reduce(0, +) / Double(observations.count)
        return (output, confidence)
    }
}
