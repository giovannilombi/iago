import Foundation
import IAGOCore
import IAGOExport
import IAGOStore

/// Regenerates `transcript.txt` and `transcript.md` from `transcript.json` and the database (FR-51):
/// after a transcription, an imported transcript, or changes to metadata, speakers and notes.
enum TextAssets {
    static func render(archive: Archive, itemID: String, transcript: Transcript? = nil) throws {
        let document = try ItemDocument.load(itemID, from: archive, transcript: transcript)
        guard document.transcript != nil else { return }
        try archive.storeAsset(
            Data(TranscriptRenderer.text(document).utf8), itemID: itemID, kind: .transcriptTXT,
            fileName: "transcript.txt")
        try archive.storeAsset(
            Data(TranscriptRenderer.markdown(document).utf8), itemID: itemID, kind: .transcriptMD,
            fileName: "transcript.md")
    }
}
