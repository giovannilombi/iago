# ADR-0063 — Barra laterale e accesso trasversale a categorie e tag

- Stato: accettato
- Data: 2026-10-21
- Riferimenti: ADR-0035, ADR-0038 (gerarchia), ADR-0054; richieste dell'utente 2026-10-21

## Contesto
La barra laterale mescolava progetti, categorie e tag, e con molti progetti diventava ingestibile. Categorie e tag però servono, per le sintesi e per catalogare, e vanno raggiunti anche attraverso i progetti.

## Decisione
- **Tre parti, separate da linee sottili:**
  - in alto, fisse: Da classificare, Recenti, Punti chiave, Importa, Attività, Categorie e tag;
  - **PROGETTI**, l'unica parte che scorre, che contiene:
    - *In evidenza* (pin rosso), con progetti, categorie e tag fissati;
    - i **clienti come fisarmonica**, come in Teams: clic per aprire o chiudere, ⌥-clic per aprire solo quello, al passaggio "→" e "+";
    - *Senza cliente* (quadratino grigio), sempre ultimo, con *Non definito* in fondo;
  - in fondo, una barra fissa con "＋" (nuovo progetto o cliente) e il cestino con il conteggio.
- **Filtra progetti** compare oltre i 15 progetti.
- **Categorie e tag**, una vista con i conteggi. Un clic apre l'elenco su tutti i progetti; con il tasto destro si fissa in *In evidenza*.
- **Nella ricerca** `#` e `categoria:` suggeriscono tag e categorie; **nella scheda** un clic su un tag o sulla categoria apre l'elenco trasversale.

## Conseguenze
- Le sezioni Categorie e Tag non sono più nella barra laterale.
- La parte fissa in alto si misura sull'ultima riga, così segue la dimensione delle icone scelta in Impostazioni di Sistema.
