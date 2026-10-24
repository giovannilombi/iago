# Checklist test di cattura (manuali)

Test di integrazione della cattura (spec 16.4, accettazione fase 0 in sez. 18). Da ripetere a ogni modifica di `IAGOCapture` e prima di chiudere una fase. Le registrazioni prodotte **non si committano**.

## Preparazione

- Build Debug firmata: `scripts/bootstrap.sh && xcodebuild -project IAGO.xcodeproj -scheme IAGO build`.
- Permessi concessi: Microfono e Registrazione audio di sistema (Impostazioni di Sistema › Privacy e sicurezza).
- Strumenti: `swift build -c release --product iago-spike` in `Packages/IAGOCapture`.
  - `iago-spike processes` — mostra quale microfono IAGO seguirebbe e perché.
  - `iago-spike levels <file>` — livelli RMS al secondo (traccia muta = `-120`).
  - `iago-spike make-beep beeps.wav <minuti>` e `iago-spike drift <cartella>` — misura della deriva.
- Le registrazioni finite sono in `~/Library/Application Support/IAGO/Recordings/<itemId>/` (`mic.m4a`, `system.m4a`, `mix.m4a`, `session.json`).

## Esito per ogni call

Il tap di sistema è globale (tutti i processi tranne IAGO): app native e browser sono catturati allo stesso modo. Le righe browser servono perché Meet esiste solo nel browser e i browser usano processi helper con bundle ID diversi, che il resolver del microfono deve riconoscere.

Per ogni riga: entrambe le tracce udibili (`levels` senza lunghi `-120` quando qualcuno parla), voce dell'utente presente in `mic.m4a`, voci remote in `system.m4a`, nessun buco.

| # | Scenario | Come | Atteso | Esito | Data | Note |
|---|---|---|---|---|---|---|
| 1 | Teams (app nativa) 10 min | call di prova, registrazione da menu bar | due tracce udibili; `processes` mostra `com.microsoft.teams*` con il mic giusto | ✅ | 2026-10-12 | call reale 10 min 42 s (item `01a12f34…`): traccia sistema senza buchi; mic a -120 solo 5 s isolati con cuffie BT in silenzio; 2 `deviceChange` corretti |
| 2 | Zoom (app nativa) 10 min | idem | `processes` mostra `us.zoom.*` | ✅ | 2026-10-12 | app (`us.zoom.xos`) 5 min 48 s: mic 0 s a -120; cuffie collegate/tolte seguite (callApp), mute ok. Anche Zoom nel browser (1 min 56 s) ok. Durata di 10 min verificata su Teams e Meet Chrome (accordo con l'utente). Zoom manda zeri veri nei silenzi |
| 3 | Meet in Chrome 10 min | idem | `processes` mostra un processo `com.google.Chrome*` | ✅ | 2026-10-12 | 10 min 20 s: processo `com.google.Chrome.helper`; mic senza buchi; mute ok; cuffie scelte in Meet e tolte seguite (togliendole IAGO passa subito al MacBook, Meet resta senza mic ~5 s). **Bug**: con Meet su "predefinito" e cuffie appena collegate Chrome elenca 2 input e IAGO prende il primo (MacBook) invece delle cuffie usate → proposta ADR-0025. Silenzi nella traccia sistema = nessun audio remoto |
| 4 | Meet in Safari 10 min | idem | `processes` mostra `com.apple.WebKit*`/Safari | ✅ | 2026-10-12 | 3 min 41 s (durata 10 min verificata su Teams e Meet Chrome, accordo con l'utente): processo `com.apple.WebKit.GPU`; mute: Safari tiene il mic, voce registrata; cuffie scelte in Meet e tolte: seguite. Collegando le cuffie (predefinite del Mac) IAGO oscilla 2 volte in 4 s tra cuffie e MacBook; ~2 s di mic a -120 togliendo le cuffie (anche Meet era senza mic) |
| 4b | Teams nel browser 10 min (facoltativo) | idem, da teams.microsoft.com | come riga 3/4 | | | |
| 4c | Mute nell'app di call | durante una call (righe 1–4) silenziare il microfono nell'app per ~30 s parlando, poi riattivarlo | voce dell'utente presente in `mic.m4a` anche durante il mute; annotare se `session.json` ha un `deviceChange` (l'app ha rilasciato il microfono) | ✅ Teams | 2026-10-12 | Teams tiene aperto il mic durante il mute; voce registrata; nessun cambio di mic. Da ripetere su Zoom e Meet |
| 5 | Cambio mic AirPods ↔ interno a metà call | cambiare l'input nell'app di call | `session.json` ha un marcatore `deviceChange`; voce dell'utente presente prima e dopo | ✅ Teams | 2026-10-12 | CMF Buds Pro 2 ↔ mic MacBook: due `deviceChange`, nessun buco al passaggio |
| 6 | Cambio uscita altoparlanti ↔ cuffie | cambiare l'output di sistema durante la call | audio remoto continuo in `system.m4a` | ✅ Teams | 2026-10-12 | uscita Teams cuffie → altoparlanti → cuffie: traccia sistema continua, nessuna ricostruzione del tap |
| 7 | Override manuale microfono | menu › Microfono › dispositivo | traccia mic dal dispositivo scelto | ✅ | 2026-10-12 | MacBook ↔ CMF Buds in manuale: `deviceChange` "(manual)"; Automatico torna al mic di Teams |
| 8 | Pausa / ripresa | clic destro due volte (prima del 2026-10-12: clic sinistro) | marcatori `pause`/`resume`; nessun audio durante la pausa | ✅ | 2026-10-12 | involontaria su call reale (item `01a12f27…`): due coppie `pause`/`resume` a 62,5 s e 67,4 s, pause escluse dalla timeline; 2026-10-12 verificati dal vivo i clic invertiti (ADR-0026): sinistro → menu, destro → avvia/pausa/riprendi |
| 9 | Nuova registrazione | menu › Nuova registrazione | due righe; la seconda inizia dove finisce la prima, senza buchi | ✅ | 2026-10-12 | due righe, la seconda parte all'istante della prima (08:41:01) |
| 10 | Sleep | chiudere il coperchio durante la registrazione | marcatore `autoPauseSleep`; al risveglio la richiesta "Riprendi" | ✅ | 2026-10-12 | `autoPauseSleep` a 66 s; al risveglio finestra "Registrazione in pausa" (Riprendi / Stop e salva / Lascia in pausa); scelto Stop e salva → finalizzata |
| 11 | Crash | `pkill -9 -x IAGO` durante la registrazione, poi riaprire | notifica "Recuperata una registrazione interrotta"; persi ≤ 2 s | ✅ | 2026-10-12 | kill -9 a ~25 s: recuperati 25,07 s. Bug trovato e corretto: traccia di sistema vuota (nessuna app in riproduzione) non veniva creata nel recupero; ora è riempita di silenzio |
| 12a | Permesso mic negato | disattivare IAGO in Privacy e sicurezza › Microfono, poi avviare | avviso "Accesso al microfono negato", nessuna registrazione avviata | ✅ | 2026-10-12 | avviso con "Apri Impostazioni" e "Annulla", registrazione non avviata; icona generica nell'avviso (manca l'AppIcon, fase 1) |
| 12b | Traccia mic muta | volume di ingresso a 0 con audio di sistema attivo, registrare 40 s | dopo 30 s icona di attenzione e avviso nel menu; torna normale quando il mic riprende | ✅ | 2026-10-12 | icona di attenzione dopo ~30 s, nessuna interruzione della registrazione; tornata normale rialzando il volume di ingresso |
| 14 | Segna momento | durante la registrazione: menu › Segna momento; con ⌥ › Segna momento con nota… | icona segnalibro per 1 s; marcatori `bookmark` in `session.json` 5 s prima del clic (ADR-0024), con `detail` = nota | ✅ | 2026-10-12 | segnalibro semplice e con nota salvati (prima di ADR-0024: al momento del clic) |
| 13 | Deriva 2 ore | `afplay beeps.wav` (120 min) dagli altoparlanti durante una registrazione | `iago-spike drift` < 50 ms | | | |

## Risultati automatici già verificati (fase 0)

| Data | Test | Risultato |
|---|---|---|
| 2026-10-11 | Registrazione scriptata 20 s con `say` + "Nuova registrazione" a 10 s | due righe, tracce allineate al ms, parlato continuo a cavallo dello split |
| 2026-10-11 | `kill -9` dopo ~8,5 s | recuperati 8,44 s, sessione finalizzata al riavvio |
| 2026-10-11 | Deriva su 3 min (beep ogni 10 s, altoparlanti integrati) | offset costante ~47 ms (latenza acustica + dispositivi), deriva 3,1 ms |
| 2026-10-11 | Nessun audio in riproduzione | il tap non consegna buffer finché nessuna app suona: buco = silenzio, tracce di uguale durata, nessuna ricostruzione spuria (dopo correzione) |
| 2026-10-11 | Segna momento scriptato a 3 s | marcatore `bookmark` a 3,17 s con nota |

## Avvio scriptato (solo build Debug)

```bash
open IAGO.app --args -IAGOAutoRecordSeconds 600            # registra 10 min ed esce
open IAGO.app --args -IAGOAutoRecordSeconds 20 -IAGOAutoSplitAt 10
```
