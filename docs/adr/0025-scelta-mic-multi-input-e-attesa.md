# ADR-0025 — Scelta del microfono: più ingressi per app e attesa prima del ripiego

- Stato: accettato (test della fase 0 con l'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: sez. 6.2; ADR-0004; `docs/testing/capture-checklist.md` righe 3–5

## Contesto
ADR-0004 fa seguire a IAGO il microfono usato dall'app di call, ripiegando sull'ingresso predefinito del Mac quando nessuna app usa il microfono. I test con call reali (Teams, Zoom app e browser, Meet in Safari e Chrome) hanno mostrato due casi non coperti:

1. **Più ingressi per lo stesso processo.** Con Meet in Chrome impostato su "predefinito", collegando le cuffie Chrome apre il nuovo ingresso predefinito ma tiene aperto anche il precedente. Core Audio elenca entrambi (`Microfono MacBook Pro, CMF Buds Pro 2`); IAGO prendeva il primo e ha registrato per circa un minuto dal microfono sbagliato (verificato con `kAudioDevicePropertyDeviceIsRunningSomewhere`: le cuffie erano usate solo da Chrome).
2. **Assestamenti di un attimo.** Collegando o scollegando dispositivi, Safari e Teams risultano per 1–5 s senza microfono. IAGO ripiegava subito sull'ingresso predefinito e poi tornava indietro: con Meet in Safari due andate e ritorno in 4 s.

Il mute dell'app di call non rilascia il microfono in nessuna delle app provate: non serve un comportamento speciale per il mute.

## Decisione
- **Più ingressi:** se il processo dell'app di call elenca più ingressi disponibili si sceglie, nell'ordine: l'ingresso predefinito del Mac se è tra quelli; altrimenti il microfono che IAGO sta già usando; altrimenti il primo.
- **Attesa prima del ripiego:** quando l'app seguita (call o altra app) smette di usare il microfono e il resolver proporrebbe l'ingresso predefinito, IAGO resta sul microfono attuale per **3 s** (`MicFallbackHold.interval`), **solo se quel microfono è ancora collegato**. Se il microfono è stato scollegato, o se l'app passa a un altro microfono, il cambio è immediato. Con il controllo periodico ogni 2 s il ripiego avviene entro ~5 s.
- L'attesa non si applica alla scelta manuale né quando il microfono attuale è già l'ingresso predefinito.

## Conseguenze
- Meno cambi di microfono spuri nei marcatori `deviceChange`, nessuna registrazione dal microfono sbagliato nel caso di Chrome.
- Se l'app di call passa davvero all'ingresso predefinito dopo un'interruzione, IAGO lo segue con fino a ~5 s di ritardo, registrando nel frattempo dal microfono precedente (ancora collegato, quindi la voce è comunque presente).
- Logica pura e testata (`MicDeviceResolver.preferredDevice`, `MicFallbackHold`).
