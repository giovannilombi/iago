<!-- icona: tray.and.arrow.down -->
# Email e documenti

## Importare
- **Trascina** file nella finestra o in *Importa*: PDF, Word, testi, immagini (con riconoscimento del testo), email (.eml, .msg), audio e video, trascrizioni di Teams, file JSON, CSV e altri file di testo.
- **Incolla** un testo o un'email da *Importa*. Un JSON incollato o importato si vede in ordine, un valore per riga.
- **Aggiungi a IAGO** da qualsiasi app: seleziona un testo › tasto destro › *Servizi* › *Aggiungi a IAGO*.
- Dal menu dell'icona di IAGO {{icona}}: **Importa file…**.

Le email vengono riconosciute (mittente, destinatari, conversazione) e IAGO propone il progetto in base alle persone.

## Cartelle sorvegliate
In **Impostazioni › Email e persone › Aggiungi cartella** scegli una cartella: IAGO importa da solo, una volta sola, le email che ci finiscono. Gli inviti alle riunioni vengono scartati, e puoi aggiungere **regole** per escludere o assegnare a un progetto.

### Salvare la posta di Outlook in automatico (Power Automate)
1. Apri **Power Automate** con l'account di lavoro e crea un flusso automatico *Quando arriva un nuovo messaggio di posta (V3)*.
2. Aggiungi l'azione *Esporta messaggio di posta (V2)* e poi *Crea file* in **OneDrive**, nella cartella che IAGO sorveglia, con nome che finisce in `.eml`.
3. Ripeti con *Posta inviata* per le email in uscita.

OneDrive porta i file sul Mac e IAGO li importa.
