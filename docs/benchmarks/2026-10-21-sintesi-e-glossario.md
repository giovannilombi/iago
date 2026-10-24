# Prova delle sintesi e del glossario — 2026-10-21

Mac dell'utente (36 GB). Call reali di circa 30 minuti; qui solo misure e osservazioni, nessun contenuto delle call.

## Sintesi (ADR-0054), dopo le correzioni
| Call | Modello di sintesi | Qwen 3.5 9B | Gemma 4 12B |
|---|---|---|---|
| Consulenza fondo pensione | Client/Sales | 97 s · 17 punti | 272 s · 31 punti |
| Preparazione proposta | Standard | 64 s · 10 punti | 167 s · 19 punti |
| Riunione interna | Standard | 87 s · 11 punti | 161 s · 10 punti |

- Qwen 3.5 4B: 26-38 s, ma da 1 a 8 punti; non adatto alle sintesi.
- Gemma: cifre, scadenze e nomi corretti nei punti verificati. Gli errori residui sono di significato:
  - un aneddoto presentato come decisione;
  - un fatto personale finito nei punti salienti;
  - un "prudente" al posto di "dinamico".

  Sono state aggiunte due regole: niente fatti personali, e le decisioni sono solo quelle prese nella riunione.
- **Problemi trovati e corretti durante la prova:**
  - il modello copiava la frase parlata invece di riassumerla;
  - il JSON troppo lungo veniva troncato;
  - Gemma chiude male le parentesi o inserisce `","` a caso.

  Ora la lettura è tollerante: sezione per sezione, e per schemi se il JSON non si legge.

## Glossario della trascrizione (Whisper)
- **Call di 65 minuti, con e senza glossario:** nessuna parola del glossario compare a caso, le allucinazioni scartate scendono da 4 a 2, i termini del glossario sono scritti giusti un po' più spesso.
- **Frase sintetica con quattro nomi di aziende difficili:** due corretti, due ancora sbagliati (pronunciati male dalla voce sintetica), e "kick-off" è peggiorato.

Aiuta, ma non risolve tutto: va verificato su call reali.
