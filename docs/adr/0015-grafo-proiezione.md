# ADR-0015 — Grafo come proiezione calcolata, vista nativa centrata

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 3.17 (FR-160…165), 10.5; addendum H.15

## Contesto
La vista a grafo (fase 3) mostra relazioni tra progetti, elementi, persone, organizzazioni, argomenti, tag e decisioni. Tutte queste relazioni esistono già nelle tabelle del modello.

## Decisione
Nessuna tabella dedicata: il grafo è una proiezione calcolata in `IAGOIntelligence` (modelli `GraphNode`/`GraphEdge` in `IAGOCore`) a partire da `item`, `project`, `item_tag`, `item_entity`, `item_link`, `decision`, `decision_entity`, `decision_tag`, `note`. Vista nativa SwiftUI; modalità di default centrata sull'elemento selezionato con profondità 1. Libreria candidata Grape (da valutare licenza, manutenzione, prestazioni), alternativa layout force-directed proprio con `Canvas`.

## Conseguenze
- Nessuna duplicazione di dati né problemi di sincronizzazione tra grafo e modello.
- Le prestazioni dipendono dalle query: raggruppamento obbligatorio oltre 500 nodi visibili.
