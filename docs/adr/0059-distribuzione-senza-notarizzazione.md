

## Modifica del 2026-10-27 (DMG e build da sorgente)
- **La prima installazione è un DMG** (`IAGO-x.y.z.dmg`) con IAGO e il collegamento ad Applicazioni, firmato con la stessa identità dell'app; lo zip resta per gli aggiornamenti di Sparkle. Il passaggio "Apri comunque" resta, una volta sola.
- **Le copie compilate dal codice sorgente non cercano aggiornamenti** (`IAGODistribution` in `Info.plist`, `YES` solo nelle build di `scripts/release.sh`): chi sviluppa si aggiorna con git. Altrimenti Sparkle sostituirebbe la sua build con quella pubblicata, firmata da un altro, e macOS chiederebbe di nuovo tutti i permessi.
- Chi sviluppa e vuole provare il DMG lo installa su un altro account utente o su un altro Mac: due copie di IAGO sullo stesso account si contendono permessi e archivio.
- **Da verificare prima della distribuzione:** "Apri comunque" una sola volta su un Mac pulito; aggiornamento con Sparkle senza un nuovo blocco e con i permessi conservati; durata del certificato gratuito e cosa succede alla scadenza.
