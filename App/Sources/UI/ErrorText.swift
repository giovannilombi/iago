import Foundation
import IAGOCapture
import IAGOIngest
import IAGOStore
import IAGOTranscription
import Security

/// The text shown to the user for an error: Italian, without internal case names. The packages' own
/// descriptions stay technical and in English (logs); unknown errors keep their detail, labelled as such.
enum ErrorText {
    static func describe(_ error: Error) -> String {
        switch error {
        case let error as DecisionError: decision(error)
        case MCPChangeError.alreadyUndone: String(localized: "Questa modifica è già stata annullata.")
        case MCPChangeError.changedSince:
            String(
                localized:
                    "La sintesi è stata cambiata dopo questa modifica di Claude: annullarla farebbe perdere quel lavoro."
            )
        case let error as ArchiveError: archive(error)
        case let error as Backup.BackupError: error.description
        case is EncryptedFile.Error:
            String(localized: "Un file cifrato dell'archivio è danneggiato o illeggibile.")
        case let error as KeyStoreError: keychain(error)
        case let error as CaptureError: capture(error)
        case let error as AudioFileConverter.ConversionError: conversion(error)
        case let error as ExtractionError: extraction(error)
        case EmailParserError.notAnEmail: String(localized: "Il file non è un'email.")
        case let error as TranscriptionError: transcription(error)
        case let error as ModelManager.ModelError: model(error)
        default: unknown(error)
        }
    }

    private static func decision(_ error: DecisionError) -> String {
        switch error {
        case .supersedeCycle:
            String(
                localized:
                    "Una voce non può superare sé stessa né una voce che la supera già. Scegli un'altra voce nel campo «Supera»."
            )
        case .emptyText: String(localized: "Il titolo non può essere vuoto.")
        }
    }

    private static func archive(_ error: ArchiveError) -> String {
        switch error {
        case .notFound: String(localized: "L'elemento non esiste più: forse è stato eliminato.")
        case .keyDeleted:
            String(localized: "I contenuti di questo elemento sono stati eliminati e non si possono più leggere.")
        case .checksumMismatch:
            String(localized: "Un file dell'archivio è danneggiato: il contenuto non corrisponde a quello salvato.")
        case .duplicateEmail: String(localized: "Email già in archivio.")
        }
    }

    private static func keychain(_ error: KeyStoreError) -> String {
        switch error {
        case .keychain(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? ""
            return String(localized: "Errore del Portachiavi (\(Int(status))): \(detail)")
        case .corruptKey: return String(localized: "La chiave dell'archivio nel Portachiavi non è valida.")
        }
    }

    private static func capture(_ error: CaptureError) -> String {
        switch error {
        case .coreAudio(let status, let operation):
            String(localized: "Errore audio di macOS (\(Int(status))). Dettaglio tecnico: \(operation)")
        case .fileSystem(let message):
            String(localized: "Errore nella scrittura dei file. Dettaglio tecnico: \(message)")
        case .unsupportedFormat(let message): String(localized: "Formato audio non supportato: \(message)")
        case .noInputDevice: String(localized: "Nessun microfono disponibile.")
        case .invalidState(let message):
            String(localized: "Operazione non possibile in questo momento. Dettaglio tecnico: \(message)")
        }
    }

    private static func conversion(_ error: AudioFileConverter.ConversionError) -> String {
        switch error {
        case .noAudioTrack(let name): String(localized: "\(name) non contiene audio.")
        case .exportFailed(let message):
            String(localized: "Conversione dell'audio non riuscita. Dettaglio tecnico: \(message)")
        }
    }

    private static func extraction(_ error: ExtractionError) -> String {
        switch error {
        case .unsupported(let name): String(localized: "Tipo di file non supportato: \(name)")
        case .unreadable(let name): String(localized: "Impossibile leggere \(name).")
        }
    }

    private static func transcription(_ error: TranscriptionError) -> String {
        switch error {
        case .modelNotFound: String(localized: "Mancano i modelli di trascrizione.")
        case .engineFailure(let message):
            String(localized: "Trascrizione non riuscita. Dettaglio tecnico: \(message)")
        case .audio(let message):
            String(localized: "L'audio non si può trascrivere. Dettaglio tecnico: \(message)")
        }
    }

    private static func model(_ error: ModelManager.ModelError) -> String {
        switch error {
        case .missing: String(localized: "Mancano i modelli di trascrizione.")
        case .checksumMismatch(let name):
            String(localized: "Il modello \(name) è danneggiato: scaricalo di nuovo da Impostazioni.")
        }
    }

    /// System errors (files, network) carry a localized text; anything else shows its detail as technical.
    private static func unknown(_ error: Error) -> String {
        if String(reflecting: type(of: error)).hasPrefix("GRDB.") {
            return String(
                localized: "Errore del database: la modifica non è stata salvata. Dettaglio tecnico: \(error)")
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSURLErrorDomain
            || nsError.domain == NSOSStatusErrorDomain || nsError.domain == NSPOSIXErrorDomain
        {
            return nsError.localizedDescription
        }
        return String(localized: "Operazione non riuscita. Dettaglio tecnico: \(error)")
    }
}
