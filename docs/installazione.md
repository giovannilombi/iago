# Installare IAGO

Bastano una decina di minuti, compresa la configurazione guidata.

## Requisiti

| | Minimo | Consigliato |
|---|---|---|
| Mac | Apple Silicon (M1 o successivi) | M2 o successivi |
| macOS | 15 Sequoia | l'ultima versione |
| Memoria (RAM) | 8 GB | 16 GB per le sintesi, 32 GB per il motore più grande |
| Spazio libero | 2 GB (app e trascrizione) | da 5 a 10 GB con il motore locale |

- **Trascrizione:** i modelli occupano circa 1,6 GB e si scaricano durante la configurazione guidata.
- **Motore locale** (facoltativo, per sintesi, proposte e Chiedi): da 2 a 7 GB a seconda del modello. Le sintesi richiedono almeno Qwen 3.5 9B.
- **Cuffie:** non obbligatorie, ma senza cuffie il microfono sente anche le casse.

## 1. Copiare l'app
1. Scarica **[IAGO.dmg](https://github.com/giovannilombi/iago/releases/latest/download/IAGO.dmg)**, l'ultima versione (le altre sono nella [pagina delle release](https://github.com/giovannilombi/iago/releases)), e aprilo.
2. Nella finestra che si apre, trascina **IAGO** sulla cartella **Applicazioni**, seguendo le frecce.
3. Nella stessa finestra c'è **Leggimi - Read me**: spiega, in italiano e in inglese, i passi qui sotto.

Chi sviluppa IAGO usa la propria build compilata dal codice: non installa il DMG sullo stesso account utente, perché due copie di IAGO si contendono permessi e archivio.

## 2. "Apri comunque" (Gatekeeper, solo la prima volta)
IAGO non è distribuito tramite l'App Store e non è notarizzato da Apple, perché la notarizzazione richiede un account a pagamento. L'app è comunque firmata. Al primo avvio macOS la blocca con un messaggio del tipo «Impossibile verificare che "IAGO" non contenga malware».

1. Premi **Fine**, non "Sposta nel cestino".
2. Apri **Impostazioni di Sistema › Privacy e sicurezza**, scorri fino a **Sicurezza** e premi **Apri comunque** accanto a IAGO.
3. Conferma con la password o con Touch ID, poi premi **Apri**.

Dopo la prima volta IAGO si apre normalmente, anche dopo gli aggiornamenti.

**In alternativa, con il Terminale.** Dopo aver trascinato IAGO in Applicazioni, apri Terminale e scrivi:

```sh
sudo xattr -dr com.apple.quarantine /Applications/IAGO.app
```

Poi inserisci la password del Mac: mentre la scrivi non si vede niente, è normale. Il comando toglie a IAGO il segno di «scaricato da Internet», che fa scattare il controllo; vale solo per IAGO. Usalo solo per app di cui ti fidi.

::: tip Perché non è nell'App Store
Le app dell'App Store devono stare in una sandbox, che non permette di registrare l'audio delle altre app. IAGO ha bisogno di sentire l'audio di Teams, Zoom e Meet per registrare la tua call.
:::

## 3. Configurazione guidata
Al primo avvio IAGO ti chiede:
- il tuo nome, che nelle trascrizioni diventa "Io";
- il microfono, con una prova;
- una prova dell'audio del Mac;
- le notifiche;
- il download dei modelli di trascrizione.

Poi si apre l'introduzione, che ritrovi in **Impostazioni › Aiuto**. Nella barra laterale trovi i progetti di esempio di un'agenzia inventata (Poldo S.p.A., Sanna TheBest s.r.l., Atoms) da esplorare; li togli con **Impostazioni › Progetti › Rimuovi l'esempio**.

## 4. Permessi di macOS
In **IAGO › Impostazioni › Permessi** trovi l'elenco con lo stato di ogni voce. **Attiva quelli che mancano** ti accompagna una voce alla volta.

| Permesso | A cosa serve | Livello |
|---|---|---|
| Microfono | la tua traccia | obbligatorio |
| Registrazione dell'audio di sistema | la traccia degli altri partecipanti | obbligatorio |
| Notifiche | fine trascrizione, sintesi pronte, proposta di registrare | consigliato |
| Avvio al login | essere pronto a ogni call | consigliato |
| Calendario | il titolo delle riunioni e la proposta all'orario d'inizio | facoltativo |
| Accessibilità | seguire il mute di Teams | facoltativo |
| Registrazione schermo | *Segna momento con screenshot* (cattura solo quando lo chiedi) | facoltativo |
| Motore locale | sintesi, proposte e Chiedi a IAGO | facoltativo |

Se un permesso è stato negato, si riattiva in **Impostazioni di Sistema › Privacy e sicurezza**, nella voce corrispondente; poi si riavvia IAGO.

## 5. Calendario di lavoro (consigliato)
Per avere il titolo delle riunioni e la proposta di registrare all'orario d'inizio:
1. **Impostazioni di Sistema › Account Internet**: aggiungi il tuo account di lavoro (per esempio **Microsoft Exchange**) e, se lo usi, **Google**. Attiva **Calendari**.
2. In IAGO: **Impostazioni › Audio › Riunioni › Usa il Calendario del Mac**.

## 6. Aggiornamenti
IAGO controlla una volta al giorno se c'è una versione nuova sulla pagina delle release e te la propone. Gli aggiornamenti sono firmati. Una nuova versione **maggiore** è obbligatoria: finché non la installi, IAGO non avvia nuove registrazioni. Il controllo si fa anche a mano, dal menu dell'icona di IAGO › **Controlla aggiornamenti…**. Vale per IAGO installato dal DMG; una copia compilata dal codice sorgente si aggiorna con git.

## Disinstallare
1. Esci da IAGO (menu dell'icona › **Esci**) e trascina l'app dal Finder nel Cestino.
2. I tuoi dati restano in `~/Library/Application Support/IAGO`: cancella quella cartella solo se vuoi eliminarli davvero. Prima puoi farne un backup cifrato da **Impostazioni › Backup e trasferimento**.
