# ADR-0026 — Clic sinistro apre il menu, clic destro avvia e mette in pausa

- Stato: accettato (richiesta dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: FR-02, FR-03

## Contesto
FR-02 assegna al clic sinistro avvio/pausa/ripresa e FR-03 il menu al clic destro. Nei test della fase 0 l'utente ha messo in pausa involontariamente la registrazione cinque volte cliccando l'icona per aprire il menu o per fermare: il clic sinistro è il gesto istintivo per "vedere" o "fermare", e una pausa involontaria durante una call fa perdere audio senza che l'utente se ne accorga.

## Decisione
- **Clic sinistro** → menu (stato, durata, microfono, Pausa/Riprendi, Stop, Nuova registrazione, Segna momento, …). Da inattivo il menu offre "Avvia registrazione".
- **Clic destro o ctrl-clic** → avvia / pausa / riprende.

## Conseguenze
- Deroga a FR-02 e FR-03 (comportamenti scambiati).
- Avviare una registrazione richiede un clic destro oppure due clic sinistri (menu › Avvia registrazione).
- Le scorciatoie globali previste (FR-05 e seguenti) non cambiano.
