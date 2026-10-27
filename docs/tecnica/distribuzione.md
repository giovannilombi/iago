# Distribuzione e aggiornamenti

## Senza App Store e senza notarizzazione (ADR-0059)
- L'App Store richiede la sandbox, che non permette di registrare l'audio delle altre app.
- La notarizzazione richiede un account Apple a pagamento: IAGO è firmato con un Apple ID gratuito (Apple Development) e chi lo installa fa **"Apri comunque"** la prima volta.
- Cambiare firma o bundle ID farebbe richiedere di nuovo tutti i permessi: non si fa.
- **DMG** (modifica del 2026-10-27): la prima installazione è un DMG con IAGO e il collegamento ad Applicazioni; lo zip resta per Sparkle.
- **Build da sorgente senza aggiornamenti:** `IAGO_DISTRIBUTION` (in `Config/Base.xcconfig`, `NO`) finisce in `Info.plist` come `IAGODistribution`; solo `scripts/release.sh` compila con `YES`. `UpdateService` avvia Sparkle solo se è `YES`: una copia compilata da chi sviluppa si aggiorna con git e non viene sostituita da quella pubblicata, firmata da un altro, che farebbe richiedere tutti i permessi.

## Aggiornamenti con Sparkle (ADR-0056)
- **Sparkle 2.10** legge `https://github.com/giovannilombi/iago/releases/latest/download/appcast.xml`.
- Ogni release è un archivio firmato **EdDSA**; la chiave pubblica è nell'app (`SUPublicEDKey`), quella privata nel Portachiavi di chi pubblica. IAGO installa solo versioni firmate dalla stessa chiave.
- **Versioni maggiori obbligatorie:** l'appcast le segna come *critical*; finché non sono installate IAGO non avvia nuove registrazioni (una in corso continua).
- Funziona solo con il repository **pubblico**: oggi è privato, quindi il controllo non trova nulla.

## Fare una release
```sh
scripts/release.sh 1.0.0 --notes "Novità…" --github
```
1. Aggiorna versione e build in `project.yml` (`1.0.0`, oppure `1.0.0-beta.2` per una beta).
2. Compila la Release firmata e la verifica con `codesign`.
3. Crea lo zip, lo firma per Sparkle, scrive `appcast.xml`; crea il **DMG** e lo firma con la stessa identità dell'app.
4. Con `--github` pubblica la release con DMG, zip e appcast, e le istruzioni di installazione nelle note.

**Da verificare prima di distribuire** (prova su un Mac o un account utente pulito): "Apri comunque" una sola volta, aggiornamento con Sparkle senza un nuovo blocco e con i permessi conservati, durata del certificato gratuito e cosa succede alla scadenza.

Dopo ogni release si aggiorna la tabella **Versioni** del README.

## Repository e versioni (ADR-0060, ADR-0065)
- **1.0.0-beta** finché non si decide di distribuire; poi 1.0.0.
- `giovannilombi/iago` è privato e nato con un solo commit; la storia precedente è in un archivio privato separato.
- Il sito di documentazione va online con il repository pubblico (ADR-0068).
