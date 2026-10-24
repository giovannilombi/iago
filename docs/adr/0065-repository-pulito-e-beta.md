# ADR-0065 — Repository pulito, 1.0.0-beta e niente dati reali nei commit

- Stato: accettato
- Data: 2026-10-24
- Riferimenti: ADR-0060 (pubblicazione del repository, opzione B), ADR-0056 (aggiornamenti da GitHub Releases), ADR-0059 (distribuzione senza notarizzazione); indicazioni dell'utente del 2026-10-24

## Contesto
- L'utente vuole far vedere IAGO a un collega tecnico e poi decidere se distribuirlo.
- ADR-0060 prevede un repository nuovo con un solo commit, da fare quando l'utente è pronto. Ora serve prima della distribuzione, per la revisione.
- L'utente chiede tre regole permanenti:
  - Claude non compare mai come co-autore;
  - nessun commit porta mai dati delle registrazioni o altri dati reali: l'app deve restare sempre pulita;
  - la versione è **1.0.0-beta** finché non c'è una prima versione distribuibile.

## Decisione
- **Repository** (esecuzione di ADR-0060 in due tempi):
  - il repository di sviluppo diventa `giovannilombi/iago-archivio`, privato, con tutta la storia e le PR;
  - nasce `giovannilombi/iago`, **privato**, con un unico commit "IAGO 1.0.0-beta". I collaboratori (il collega per la revisione) si invitano lì;
  - diventa pubblico, con la prima release, solo quando l'utente decide di distribuire. Fino ad allora gli aggiornamenti automatici non funzionano, perché scaricano da un repository pubblico.
- **Versione:** `1.0.0-beta` in `project.yml`. Le beta successive sono `1.0.0-beta.2`, `.3`…; `scripts/release.sh` le accetta. La 1.0.0 sarà la prima versione distribuibile.
- **Nessuna attribuzione all'IA:** niente `Co-Authored-By` di Claude e niente "Generated with Claude Code" nei commit e nelle PR. Un hook `commit-msg` blocca i commit che li contengono.
- **Mai dati reali nei commit:** un hook `pre-commit` (`scripts/check-private-data.sh`) blocca:
  - audio, archivi cifrati, database, modelli, trascrizioni Teams ed email (`.vtt`, `.eml`), le cartelle delle registrazioni di prova, la specifica e l'handover locali;
  - le parole elencate in `Config/private-terms.local`: nomi reali di persone, clienti e domini. Il file è ignorato da git, quindi l'elenco stesso non esce dal Mac.
- `scripts/bootstrap.sh` installa gli hook (`core.hooksPath scripts/git-hooks`).
- L'autore del commit usa l'indirizzo email anonimo di GitHub (`…@users.noreply.github.com`), non quello personale.

## Conseguenze
- Il collega vede codice, ADR, guida e documenti senza la storia che conteneva dati reali.
- Gli hook sono locali: chi clona deve lanciare `scripts/bootstrap.sh`. La CI non conosce i nomi reali e non può fare lo stesso controllo.
- Le regole di ADR-0060 restano valide: nomi inventati negli esempi, screenshot solo dall'archivio dimostrativo.

## Modifica del 2026-10-24 (autori)
- **1.0.0-beta:** unico autore Giovanni Lombi.
- **Dalle versioni successive:** i diritti sono di **Giovanni Lombi e Gianluca Sestito**. Ogni commit nomina entrambi: chi lo fa è l'autore, l'altro compare come `Co-Authored-By`. L'hook `commit-msg` aggiunge da solo le righe mancanti leggendo `Config/team.txt`; un nuovo autore si aggiunge lì.
- Claude non compare mai, né come autore né come co-autore.
- L'esempio dell'archivio nuovo e il divieto di contenuti nell'app sono in ADR-0066.
