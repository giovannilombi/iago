# ADR-0046 — Punti chiave: decisioni, attività e tappe

- Stato: accettato
- Data: 2026-10-15
- Riferimenti spec: sez. 3.16; ADR-0014 (modello `decision` generico con `kind`), ADR-0037; richiesta utente 2026-10-15

## Contesto
Oltre alle decisioni, l'utente vuole segnare in timeline altri due tipi di cose:
- le **attività**, cioè cose da fare o in corso, che possono restare lì o diventare una decisione;
- le **tappe**, cioè fatti importanti da ricordare ("piccole milestone").

Il nome "Momenti" si confonderebbe con "Segna momento", che crea i segnalibri.

## Decisione
- **Una sola famiglia, "Punti chiave"**, sulla tabella `decision` già esistente, distinta dal campo `kind` (ADR-0014):

  | Tipo | `kind` | Stati | Segno |
  |---|---|---|---|
  | Decisione | `decision` | Attiva · Superata · Annullata | sigillo verde |
  | Attività | `action` | Aperta (`active`) · Fatta (`done`, nuovo) · Superata · Annullata | cerchio tratteggiato arancione |
  | Tappa | `milestone` | Raggiunta (`active`) · Superata · Annullata | bandierina blu |

  Non servono migrazioni: `kind` e `status` sono testo.
- **Catene:** valgono per tutti i tipi. Un'attività "diventa decisione" quando una nuova decisione la supera, e la catena mostra attività → decisione. Nome della catena, persone, tag, stream e fonte sono comuni ai tre tipi.
- **Interfaccia:**
  - la vista "Decisioni" diventa **"Punti chiave"**, con un filtro per tipo; di default mostra gli attivi (decisioni valide, attività aperte, tappe);
  - in timeline, "Aggiungi" offre Nota, Attività, Tappa e Decisione;
  - dalle note, "Promuovi a…" offre i tre tipi;
  - un'attività ha "Segna come fatta", "Riapri" e "Diventa decisione…".
- **Export e Claude:**
  - l'export elenca i punti chiave con il tipo (`[Attività · Aperta]`, `[Tappa]`), mentre le decisioni restano `[Attiva]`;
  - MCP: `add_decision` e `list_decisions` hanno `kind` e lo stato `done`;
  - nel grafo le attività sono pentagoni e le tappe triangoli.

## Conseguenze
- Un solo registro con una sola logica di catene, senza tabelle nuove.
- Nel codice il nome `Decision` resta anche per attività e tappe. Nell'interfaccia il nome comune è "Punti chiave".
