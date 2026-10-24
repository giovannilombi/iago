# ADR-0022 — macOS minimo 15

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 4.1, 17.A

## Contesto
I process tap sono disponibili da macOS 14.2 e le proprietà dei process object usate per individuare il microfono in uso da macOS 14. La spec propone 15 come default e 14.4 come alternativa. Lo sviluppo avviene su macOS 27; i potenziali colleghi utenti sono su versioni recenti.

## Decisione
Deployment target **macOS 15.0**, solo Apple Silicon.

## Conseguenze
- API di Core Audio e SwiftUI più mature, meno rami `if #available`.
- Esclusi i Mac fermi a macOS 14: accettabile per un uso personale e di team.
- API introdotte dopo la 15 (es. SpeechAnalyzer) richiedono controlli di disponibilità.
