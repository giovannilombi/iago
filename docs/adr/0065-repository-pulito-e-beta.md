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

## Modifica del 2026-10-25 (indirizzi email)
- **Contesto:** l'indirizzo personale di un autore era finito in `Config/team.txt` e, tramite l'hook, nei `Co-Authored-By`; quello di un altro era l'autore dei merge fatti dal sito di GitHub. La storia è stata riscritta e il repository ricreato, perché le PR chiuse conservano i vecchi commit.
- **Nessun indirizzo email personale nel repository**, né nei file né nei commit (autore, committer, messaggio). Gli autori usano solo l'indirizzo anonimo di GitHub (`<id>+<utente>@users.noreply.github.com`), anche in `Config/team.txt`; negli esempi si usano domini inventati.
- **Controlli, su tre livelli:**
  - `pre-commit` (`scripts/check-private-data.sh`): blocca un autore o un committer che non usa l'indirizzo anonimo e, nei file, gli indirizzi dei servizi di posta personali (Gmail, iCloud, Outlook, Libero…); i domini di lavoro reali vanno in `Config/private-terms.local`;
  - `commit-msg`: blocca un messaggio con un indirizzo email che non sia quello anonimo di GitHub;
  - `pre-push` (`scripts/check-commit-emails.sh`): ricontrolla ogni commit che sta per uscire, anche quelli fatti con `--no-verify`, da un merge o da un altro programma;
  - su GitHub, il workflow `privacy.yml` (Ubuntu, pochi secondi) fa gli stessi controlli su ogni PR e ogni push su `main`, perché gli hook locali si possono saltare e un clone nuovo non li ha finché non lancia `scripts/bootstrap.sh`.
- **Account GitHub di ogni autore:** in Settings › Emails, "Keep my email addresses private" (i merge fatti dal sito usano l'indirizzo anonimo) e "Block command line pushes that expose my email".

## Modifica del 2026-10-29 (diritti)
- I diritti sono di **Giovanni Lombi fino alla 1.3.x-beta** e di **Giovanni Lombi e Gianluca Sestito dalla 1.4.0-beta**. Sostituisce il «dalle versioni successive alla 1.0.0-beta» della modifica del 2026-10-24.
- I commit continuano a nominare entrambi (`Co-Authored-By` aggiunto dall'hook `commit-msg`).
- Impostazioni › Informazioni mostra Giovanni Lombi fino alla 1.3.x-beta; il sito nomina entrambi e rimanda ai crediti del README.
