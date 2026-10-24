# Installare IAGO

Guida per chi riceve IAGO. Bastano 10 minuti.

Serve:
- un Mac con Apple Silicon (M1 o successivi) e macOS 15 o più recente;
- circa 5 GB liberi: 1,6 GB per la trascrizione, da 2 a 7 GB se vuoi il motore per sintesi e Chiedi.

## 1. Copiare l'app
1. Apri il file ricevuto (`IAGO-x.y.z.zip`) e trascina **IAGO** nella cartella **Applicazioni**.
2. Apri IAGO da Applicazioni.

## 2. "Apri comunque" (solo la prima volta)
IAGO non è distribuito tramite l'App Store e non è notarizzato da Apple (serve un account a pagamento). Al primo avvio macOS lo blocca con un messaggio del tipo «Impossibile verificare…».
1. Premi **Fine** (non "Sposta nel cestino").
2. Apri **Impostazioni di Sistema › Privacy e sicurezza**, scorri fino a **Sicurezza** e premi **Apri comunque** accanto a IAGO.
3. Conferma con la password o con Touch ID, poi **Apri**.

Dopo la prima volta IAGO si apre normalmente.

## 3. Configurazione guidata
Al primo avvio IAGO ti guida:
- nome;
- microfono;
- prova dell'audio del Mac;
- notifiche;
- download dei modelli di trascrizione.

Poi un breve tour spiega come si usa. Lo ritrovi in **Aiuto di IAGO**.

## 4. Permessi
In **IAGO › Impostazioni › Permessi** trovi la lista di tutto ciò che serve, con lo stato. **Attiva quelli che mancano** ti accompagna una voce alla volta:
- **obbligatori:** Microfono e Registrazione dell'audio di sistema;
- **consigliati:** Notifiche e avvio al login;
- **facoltativi:**
  - Calendario, per il titolo delle riunioni;
  - Accessibilità, per seguire il mute di Teams;
  - motore locale, per sintesi, proposte e Chiedi.

## 5. Calendario di lavoro (consigliato)
Per avere il titolo delle riunioni e la proposta di registrare all'orario d'inizio:
1. **Impostazioni di Sistema › Account Internet** › aggiungi il tuo account di lavoro (**Microsoft Exchange**) e, se lo usi, **Google**. Attiva **Calendari**.
2. In IAGO: **Impostazioni › Audio › Riunioni › Usa il Calendario del Mac**.

## 6. Aggiornamenti
Vedi ADR-0056 (in via di decisione): con la cartella OneDrive aziendale, IAGO propone da solo le versioni nuove.

## Problemi comuni
- **"Nessun audio di sistema" nella prova:** Impostazioni di Sistema › Privacy e sicurezza › Registrazione dello schermo e dell'audio di sistema: attiva IAGO, poi riavvia IAGO.
- **Le voci degli altri si sentono anche sulla mia traccia:** usa le cuffie, oppure lascia attiva la cancellazione dell'eco (Impostazioni › Audio).
- **Teams in mute non viene seguito:** Impostazioni › Audio › Riunioni › attiva l'Accessibilità e consenti IAGO.
