# ADR-0004 — Traccia mic = microfono in uso dall'app di call

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.2 (FR-12), 6.2, 17.4

## Contesto
L'input predefinito di sistema non coincide necessariamente con il microfono scelto nell'app di call (es. Teams su AirPods mentre il default è il microfono interno). Registrare il microfono sbagliato significa perdere la voce dell'utente.

## Decisione
IAGO individua il dispositivo di input effettivamente usato da altri processi tramite i process object di Core Audio (lista processi, "is running input", "devices" per processo), escludendo sé stesso e dando priorità alle app di call note (Teams, Zoom, Meet nei browser, Slack, FaceTime, Webex). Fallback: input predefinito di sistema. Override manuale dal menu. La scelta è rivalutata continuamente (listener Core Audio + polling ogni 2 s); al cambio si continua sulla stessa traccia con silenzio allineato e marcatore `deviceChange`.

## Conseguenze
- Da validare nella fase 0 per Teams nativo, Zoom, Meet in Chrome e Safari. Se un caso non funziona: nuovo ADR con fallback.
- La logica di scelta è una funzione pura, testabile con tabelle di processi finte.
