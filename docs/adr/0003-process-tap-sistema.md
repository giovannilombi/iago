# ADR-0003 — Traccia sistema via Core Audio process tap globale

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.2 (FR-11), 6.1, 17.3

## Contesto
Le alternative per catturare l'audio di sistema sono: driver virtuali (BlackHole, richiedono installazione e cambio dell'uscita), ScreenCaptureKit (permesso di registrazione schermo, semantica legata a schermi/app) e i process tap di Core Audio (macOS 14.2+).

## Decisione
Process tap globale (`CATapDescription` stereo globale che esclude il processo di IAGO) agganciato a un aggregate device privato. Il tap cattura il mixdown prima del dispositivo fisico, quindi il cambio di uscita (altoparlanti, cuffie, AirPods) non cambia il contenuto registrato. Se l'uscita di default cambia, l'aggregate viene ricostruito e l'eventuale buco riempito con silenzio allineato.

## Conseguenze
- Nessun driver da installare; permesso "Registrazione audio di sistema" (`NSAudioCaptureUsageDescription`).
- Non esiste un'API pubblica per leggere lo stato del permesso: va verificato empiricamente (test in onboarding + rilevamento silenzio, FR-16).
- API relativamente recente e poco documentata: rischio tecnico da eliminare nella fase 0.
- App non sandboxed in v1 per semplicità.
