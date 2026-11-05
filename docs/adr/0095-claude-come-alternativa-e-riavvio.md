# ADR-0095 — Claude come alternativa su ogni Mac, con i passi, e riavvio di Claude Desktop

- Stato: accettato
- Data: 2026-11-05
- Modifica: ADR-0078 (Claude consigliato sui Mac lenti)
- Riferimenti: ADR-0043 (server MCP), ADR-0071 (sintesi e proposte fatte da Claude); richiesta dell'utente del 2026-11-05

## Contesto
- Il riquadro che propone Claude per sintesi e proposte compariva solo sui Mac fino a 16 GB (ADR-0078). Su Mac con più memoria non c'era, anche se Claude resta un'alternativa utile.
- Nella sintesi il riquadro stava sopra il pulsante *Genera sintesi*, e spesso l'unico pulsante utile era *Usa il motore del Mac*: non si capiva come arrivare a farla con Claude.
- Claude Desktop avvia il server MCP di IAGO solo quando si apre. Un progetto appena reso consultabile non si vede finché Claude Desktop non viene riavviato, e nessuno lo diceva.

## Decisione
- **Ogni Mac:** fino a 16 GB il riquadro resta un *Consiglio*, in arancione. Con più memoria diventa un'*Alternativa*, con colori neutri, pulsanti normali e il testo «Il motore del Mac va bene su questo Mac».
- **Posizione:** nella sintesi il riquadro sta in fondo, dopo *Genera sintesi* e gli avvisi del motore. Prima c'è la strada con il motore del Mac, poi Claude.
- **Passi:** sotto *Per farla con Claude* il riquadro elenca quattro passi, ciascuno con il segno di fatto e il pulsante che serve:
  1. elemento in un progetto;
  2. Claude collegato a IAGO, e a questo progetto (*Collega Claude…*);
  3. progetto consentito a Claude (*Consenti*);
  4. *Chiedi a Claude la sintesi*.

  *Non qui: uso il motore del Mac* e *Non mostrare più* diventano due link in fondo. Le proposte restano in una riga sola.
- **Riquadro nascosto:** dopo *Non mostrare più* o *Non qui* resta una striscia sottile, «Alternativa: puoi fare la sintesi anche con Claude.» (o le proposte), con *Vedi come*, che riapre il riquadro intero per quell'elemento.
- **Riavvio di Claude Desktop:** quando un progetto diventa consultabile da Claude e Claude Desktop è aperto, IAGO mostra l'avviso *Riavvia Claude Desktop*, con *Riavvia Claude* (IAGO lo chiude e lo riapre) e *Più tardi*. Vale in ogni punto da cui si consente: Impostazioni › Claude, impostazioni di progetto o cliente, il riquadro, *Copia per Claude*. Se Claude Desktop è chiuso non serve, e l'avviso non compare.

## Conseguenze
- Su ogni Mac si vede come fare la sintesi con Claude, senza che sembri l'unica strada.
- Chi consente un progetto sa subito perché Claude non lo vede ancora, e può risolvere con un clic.
