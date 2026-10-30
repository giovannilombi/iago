# Trascrizione

Tutto avviene sul Mac (ADR-0005), nella coda dei lavori, un elemento alla volta.

## Pipeline
1. **Decodifica** delle tracce e ricampionamento a 16 kHz mono.
2. **VAD** Silero (via FluidAudio) e divisione in blocchi di parlato (ADR-0006).
3. **Riconoscimento** con il motore scelto.
4. **Diarizzazione** pyannote/WeSpeaker (FluidAudio) sulla traccia di sistema; la traccia del microfono è "Io". Il microfono viene diarizzato anch'esso: le voci della stanza con almeno 20 s di parlato si separano da sole se la traccia di sistema ha meno di 10 s di parlato (riunione in presenza), sempre con «Più persone nella stanza»; con una call restano su «Io» e il loro numero va in `Transcript.otherMicVoices`, che fa comparire *Separa le voci* (ADR-0031, `TranscriptionPipeline.RoomMode`).
5. **Segmentazione per speaker:** tempi per parola di whisper, segmenti divisi ai cambi di speaker e frasi spezzate ricucite.
6. **Unione** delle due tracce sulla linea del tempo e **filtro dell'eco:** le frasi del microfono che ripetono quelle della traccia di sistema vengono scartate.
7. **Indicizzazione** dei segmenti per la ricerca.
8. **Voci** (solo se attive in Impostazioni › Voci, ADR-0073): vedi sotto.

## Riconoscere le voci (ADR-0073)
- La diarizzazione dà per ogni speaker un'**impronta WeSpeaker** (256 numeri, `DiarizationResult.speakerDatabase`), rinumerata come gli speaker (`TranscriptPostProcessing.normalizeVoices`). La pipeline la restituisce in `Output.voices`, con i secondi di parlato, per la traccia di sistema, per il file importato e per le voci della stanza separate; il microfono dell'utente («Io») no.
- Dopo la trascrizione `TranscriptionService` la salva (`Archive.storeVoices`, almeno 10 s di parlato) e cerca le voci conosciute (`Archive.voiceMatches`): somiglianza del coseno ≥ 0,60 con la media delle impronte della persona, almeno 0,05 sopra la seconda voce, una persona per speaker. Le corrispondenze diventano proposte `person` con `origin = voice`.
- `Archive.renameSpeaker` lega l'impronta della call al nome (o la slega, se torna generico). Un errore nelle voci non fa fallire la trascrizione.
- **Nomi degli speaker** (`App/Sources/UI/ItemDetailView.swift`, `SpeakerNames`; `IAGOStore/SpeakerNames.swift`):
  - il nome si applica solo con Invio o ⏎; il testo non confermato sta in `AppModel.speakerDrafts` (in memoria, per elemento) e il campo è rosso;
  - prima di applicarlo, `Archive.similarPersonNames` cerca tra persone e speaker con un nome (`knownPersonNames`). Prima viene l'alias scelto dall'utente (`name_alias`, per forma normalizzata), poi `PersonNameMatcher`: errore di battitura sui nomi lunghi, un nome dentro l'altro, tabella dei diminutivi italiani, forma breve all'inizio o alla fine («Ale», «Sandro», «Nello»). Una parola in comune da sola non basta;
  - **Unisci** (`Archive.mergeSpeaker`): `item_speaker.merged_into` punta allo speaker della stessa call e il label diventa il suo. Così trascrizione, sintesi ed export restano invariati, e l'impronta va alla stessa voce. Rinominare lo speaker di arrivo rinomina anche quelli uniti. **Separa** (`separateSpeaker`) rimette il label della trascrizione. `transcript.json` non si riscrive mai;
  - prima di *Genera sintesi* e *Rigenera*, `AppModel.unnamedSpeakers` (label generici, escluso `me` e gli uniti) fa chiedere se dare prima i nomi; «Dai prima i nomi» (`AppModel.namingSpeakersFor`) apre la trascrizione, la porta in vista e mette il cursore nel primo campo senza nome.
- Costi: nessun modello in più, circa 1 KB per speaker, confronto sotto il millisecondo.

## Motori (ADR-0023)
| Motore | Implementazione | Velocità misurata | Note |
|---|---|---|---|
| **Whisper large-v3-turbo** (predefinito) | whisper.cpp 1.9.2, Metal, beam search 5, italiano forzato | 19× il tempo reale | più preciso su nomi e termini inglesi |
| **Parakeet TDT 0.6B v3** | FluidAudio, CoreML sul Neural Engine | 87× il tempo reale | più veloce, più errori sui nomi |

- La diarizzazione impiega pochi secondi per call (circa 300× il tempo reale).
- Misure su 2 h 44 min di call reali, M3 Pro: [benchmark fase 0](/benchmarks/2026-10-phase0).
- I modelli (circa 1,6 GB) si scaricano su richiesta da URL fissi con verifica SHA-256.

## Glossario (ADR-0062)
- Nomi di persone, clienti e termini del progetto diventano il **prompt iniziale** di Whisper (al massimo 200 caratteri).
- Parakeet non ha un prompt: il glossario vale solo per Whisper.
- Misura: [sintesi e glossario](/benchmarks/2026-10-21-sintesi-e-glossario).

## Strumenti
- `iago-bench` (pacchetto `IAGOTranscription`) confronta motori e opzioni su file audio locali; i risultati restano in `bench-out/`, mai nel repository.
- Le fixture dei test sono sintetiche (`scripts/make-fixtures.sh`, voci `say`).
