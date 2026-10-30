# IAGO — ClickUp (idea per più avanti)

Idea del 30 ottobre 2026, da riprendere in un secondo momento. Nessun ADR ancora: servirà prima di scrivere codice, perché IAGO oggi non parla con ClickUp (ADR-0058).

## In una frase
ClickUp ricorda **cosa** è cambiato in un ticket, IAGO **perché**: le call, le email, le decisioni. Collegarli mette il ticket e la sua storia accanto alla call in cui se n'è parlato.

## Già possibile, senza codice
Claude con il connettore di ClickUp e con IAGO (MCP) fa da ponte: crea ticket dalle attività confermate, confronta ticket e decisioni, commenta un ticket con la sintesi della call. Va provato su un progetto di prova; l'amministratore di ClickUp deve permettere il connettore.

## Da fare più avanti, in quest'ordine
1. **ADR «ClickUp»:** una chiamata di rete nuova verso le API di ClickUp, con il token personale nel Portachiavi, solo se l'utente la attiva, registrata nel registro accessi. Niente webhook (servirebbe una porta aperta): IAGO controlla ogni 15–30 minuti o a mano, e il controllo compare in Attività.
2. **«Manda a ClickUp»:** un'attività o una richiesta confermata diventa un ticket, con descrizione, responsabile, scadenza e la frase della call da cui nasce. Abbinamenti impostati una volta: cliente ↔ Space, progetto ↔ Folder o List, stream ↔ List, contatti ↔ membri. Dopo una call le proposte di attività si confermano e si sceglie se mandarle.
3. **Stato di ritorno:** un ticket chiuso in ClickUp chiude l'attività in IAGO, con esito «da ClickUp». Nell'Inbox anche i ticket assegnati all'utente, con un'icona propria.
4. **Registro delle liste seguite:** solo le liste scelte, in sola lettura. Ogni ticket è un elemento di tipo «ticket» con descrizione, campi e una cronologia (creazione, stato, responsabile, scadenza, commenti), con data e autore.
5. **Il ticket nella memoria:** ricerca e *Chiedi* su call, email e ticket insieme; collegamenti proposti tra una call e i ticket di cui parla; riepilogo di progetto e sintesi di stato con i movimenti di ClickUp; proposte incrociate («in call avete deciso X, il ticket dice ancora Y»), sempre da confermare.
6. **Prima di una call:** nella scheda i ticket aperti del progetto mossi di recente, in ritardo o con commenti senza risposta.
7. **Documenti di ClickUp** importati come documenti di IAGO, con la stessa ricerca.

Escluso: il tempo delle call registrato come tempo speso sui ticket.

## Confini
- Nessuna copia dell'intero spazio di lavoro e nessuna modifica dei ticket da IAGO in due direzioni: doppioni e conflitti farebbero di IAGO un secondo ClickUp.
- Da IAGO verso ClickUp solo azioni esplicite dell'utente: crea, commenta, chiudi.

## Domande aperte
- Come è organizzato ClickUp al lavoro (una List per progetto o per cliente) e con che piano: i limiti delle API dipendono dal piano.
- Se IAGO lo usano più colleghi, chi crea il ticket, per non avere due ticket uguali dalla stessa call.
- Cosa conta di più: le call che diventano ticket (punti 2–3) o i ticket nella memoria (punti 4–5).
