# Fase 0 — Spike cattura: stato

Obiettivo (spec 18): eliminare il rischio tecnico su cattura a due tracce, microfono "in uso dall'app di call", robustezza e scelta del motore ASR.

## Cosa c'è

| Componente | Dove | Note |
|---|---|---|
| Menu bar (`NSStatusItem`) | `App/Sources/StatusItemController.swift` | clic sinistro: menu con stato; clic destro (o ctrl-clic) avvia/pausa/riprendi; menu: stato + durata + mic, Pausa/Riprendi, Stop, Nuova registrazione, Microfono (automatico/manuale), Apri cartella registrazioni, Esci con conferma; icona di attenzione per traccia muta (FR-16) |
| Process tap di sistema | `IAGOCapture/SystemAudioTap.swift` | tap globale che esclude IAGO, aggregate privato **senza sotto-dispositivi fisici** (indipendente dall'uscita). **Il tap non consegna buffer mentre nessuna app riproduce audio**: il buco diventa silenzio e la traccia viene completata allo stop; il tap è ricostruito solo se resta fermo mentre un altro processo sta riproducendo |
| Microfono che segue la call | `MicDeviceResolver.swift` (logica pura) + `CaptureEngine.swift` | process object Core Audio (`IsRunningInput`, `Devices` input, bundle ID), priorità app di call, fallback input di default, override manuale; listener + polling 2 s |
| Allineamento | `TrackAligner.swift`, `SessionTimeline.swift` | host time comune; buchi → silenzio, sovrapposizioni tagliate, pause escluse dalla timeline; resampling a 48 kHz |
| Scrittura incrementale | `CAFFileWriter.swift`, `TrackWriter.swift` | CAF Float32 con data size −1 durante la registrazione; scrittura ogni 0,5 s, `fsync` ogni 2 s, flush periodico anche senza buffer |
| Finalizzazione e recovery | `SessionFinalizer.swift` | AAC mono per traccia + mix; idempotente; sessioni interrotte finalizzate all'avvio con notifica. **Non cifrato** (fase 1) e in `Recordings/` invece di `Items/` |
| Controller | `RecordingController.swift` | actor, macchina a stati; "Nuova registrazione" scambia la sessione allo stesso host time senza fermare la cattura |
| Sleep | `AppDelegate.swift` | pausa automatica + richiesta al risveglio (FR-15) |
| Segna momento (addendum, FR-05) | menu bar | segnalibro 5 s prima del clic, ADR-0024 (⌥ per aggiungere una nota), feedback sull'icona; salvato in `session.json` come marcatore `bookmark`, da importare nella tabella `marker` in fase 1 |
| Trascrizione (benchmark) | `IAGOTranscription` | protocollo `TranscriptionEngine`, `WhisperCppEngine`, `ParakeetEngine`, VAD + diarizzazione FluidAudio, pipeline sez. 7.2 (chunking VAD, filtro allucinazioni, filtro eco, assegnazione speaker), `transcript.json` |
| Strumenti | `iago-spike`, `iago-bench`, `scripts/` | livelli, deriva, tabella processi audio; benchmark ASR; fixture `say`; download modelli con SHA-256 |

Test automatici: 43 in `IAGOCapture`, 8 in `IAGOCore`, 22 in `IAGOTranscription` (`scripts/test-packages.sh`).

## Criteri di accettazione

| Criterio (spec 18) | Stato | Evidenza |
|---|---|---|
| Call di prova 10 min su Teams, Zoom, Meet: entrambe le tracce presenti e udibili | ✅ | Teams 10:42, Meet Chrome 10:20, Meet Safari 3:41, Zoom app 5:48 e browser 1:56 (2026-10-12; durata ridotta per Zoom/Safari concordata con l'utente). Checklist righe 1–4 |
| AirPods ↔ microfono interno a metà call senza perdere la voce | ✅ | cuffie Bluetooth ↔ microfono integrato su tutte le app (2026-10-12), ADR-0025. Checklist riga 5 |
| Altoparlanti ↔ cuffie senza perdere l'audio remoto | ✅ | Teams, uscita cuffie → altoparlanti → cuffie senza buchi (2026-10-12). Checklist riga 6 |
| Deriva tra le tracce < 50 ms | 🟡 parziale | 3,1 ms su 3 min con `iago-spike drift`; prova di 2 ore rimandata dall'utente (checklist riga 13, `beeps.wav` pronto) |
| `kill -9` → sessione recuperata al riavvio | ✅ | 8,44 s recuperati su ~8,5 s (2026-10-11); dal vivo 25,07 s (2026-10-12) |
| Report benchmark + ADR B | ✅ | `docs/benchmarks/2026-10-phase0.md`, ADR-0023 accettato (2026-10-12) |

## Questioni aperte

1. **Cancellazione d'eco in tempo reale (spec 6.3)** non ancora provata. La cattura mic usa un IOProc HAL diretto, mentre il voice processing di Apple richiede `AVAudioEngine`/VPIO sul dispositivo di input, con l'effetto noto di abbassare il volume delle altre app ("ducking"). Proposta: in fase 0 ci si affida al filtro eco in trascrizione (verificato sulle fixture con eco simulata); VPIO valutato in uno spike dedicato, eventualmente come opzione.
2. **Microfono tenuto aperto in pausa.** In pausa la cattura continua (scartando i buffer) per riprendere senza latenza: l'indicatore arancione del microfono resta acceso. Da decidere se rilasciare i dispositivi in pausa.
3. **Fallback all'input predefinito con AirPods.** Se nessuna app usa il microfono e l'input predefinito sono gli AirPods, aprirli forza il profilo Bluetooth "chiamata" (qualità audio ridotta). Da valutare: preferire il microfono integrato quando nessuna call è attiva.
4. **Allocazioni nel thread real-time.** Chiusa nella fase 1: gli IOProc sono creati con una coda dispatch, quindi i callback non girano sul thread real-time e l'allocazione è ammessa.
5. **FluidAudio scarica modelli in automatico** da HuggingFace. Nell'app va sempre attivato `ModelHub.offlineMode` e i modelli vanno gestiti dal `ModelManager` (spec 7.5).
6. **Mute nell'app di call.** IAGO apre il microfono direttamente (IOProc HAL), quindi il mute software di Teams, Zoom o Meet non silenzia la traccia mic: la voce dell'utente viene registrata anche da silenziato. Il mute hardware (tasto della cuffia, volume di ingresso a zero) invece la silenzia. Rischio: se durante il mute l'app di call rilascia il microfono, il resolver ripiega sull'input predefinito, che può essere un dispositivo diverso. Proposta: per tutta la sessione restare sull'ultimo microfono usato dalla call (nuovo ADR che estende ADR-0004). Verifica: checklist riga 4c.
