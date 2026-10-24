# ADR-0001 — App nativa Swift/SwiftUI, nessun fork

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 1, 4.1, 17.1

## Contesto
IAGO deve integrarsi a fondo con macOS: Core Audio (process tap, dispositivi), menu bar con clic sinistro/destro distinti, Portachiavi, permessi di sistema. Esistono progetti open source simili (Meetily, Hyprnote) basati su Tauri/Electron o con architetture diverse dai nostri requisiti di privacy e modello dati.

## Decisione
App nativa in Swift 6 (strict concurrency) con SwiftUI per le viste e AppKit dove serve (`NSStatusItem`, finestre di servizio). Nessuna webview per la UI principale. Nessun fork di app esistenti: Meetily, Hyprnote e il sample AudioCap sono solo riferimenti, rispettandone le licenze.

## Conseguenze
- Accesso diretto alle API di sistema senza bridge; footprint ridotto.
- Tutto il codice è nostro: più lavoro iniziale, nessun debito ereditato.
- Solo macOS. Client web/mobile (fase 4) saranno un progetto separato.
