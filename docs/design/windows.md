# IAGO per Windows — Note per quando si parte

> Note di progetto, raccolte nella review board interna del 2026-11-02. Non è un piano: è ciò che va letto prima di iniziare.

## Perché
- Per chi riceve un computer non Apple quando l'hardware viene sostituito.

## Cosa sappiamo già
- **È una riscrittura, non un porting.** L'app di oggi usa SwiftUI e AppKit, il process tap per l'audio, MLX per il motore locale e il Portachiavi: niente di questo esiste su Windows.
- **Si riscrive bene, anche con l'aiuto dell'AI:** interfaccia, modello dei dati (SQLite), server MCP, export.
- **La sync è già pensata per tutti i client** (ADR-0082): un client Windows legge e scrive gli stessi spazi condivisi dei Mac, con gli stessi metadati di progetto (ADR-0083).

## Dove sta il tempo vero: le prove sul campo
Su macOS queste parti hanno richiesto settimane di prove. Su Windows vanno rifatte da capo e la stima va fatta su di loro, non sul codice:
- **audio di sistema:** cattura con WASAPI loopback, un'altra API, con i suoi casi limite (cuffie, cambio di dispositivo durante la call);
- **trascrizione locale senza MLX:** ONNX o DirectML, e la qualità va rimisurata sulle stesse call di prova;
- **deriva tra le due tracce** sotto i 50 ms su 2 ore, da riprovare;
- **riconoscimento delle riunioni** di Teams e permessi di Windows;
- distribuzione e aggiornamenti (firma del codice su Windows).

## Prima di iniziare
- Rileggere ADR-0082, ADR-0083 e la specifica del formato della sync.
- Ripartire dalle fixture sintetiche dei test audio (`scripts/make-fixtures.sh`) per avere gli stessi criteri di accettazione dei Mac.
