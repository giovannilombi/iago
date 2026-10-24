# ADR-0034 — Licenza di IAGO: Creative Commons BY-NC-SA 4.0

- Stato: accettato (scelta dell'utente, 2026-10-12)
- Data: 2026-10-12

## Contesto
L'utente vuole una licenza copyleft, che vieti l'uso commerciale e obblighi a citare l'autore.

## Decisione
- IAGO è distribuito con licenza **Creative Commons Attribuzione - Non commerciale - Condividi allo stesso modo 4.0 Internazionale (CC BY-NC-SA 4.0)**, © 2026 Giovanni Lombi. Testo integrale in `LICENSE`.
- Nell'app: piè di pagina delle Impostazioni "Giovanni Lombi · CC BY-NC-SA 4.0".

## Conseguenze
- Non è una licenza open source approvata OSI (la clausola NC lo esclude) e Creative Commons sconsiglia le sue licenze per il software: è comunque l'unica diffusa che unisce copyleft, divieto d'uso commerciale e attribuzione, come richiesto.
- Le dipendenze (MIT, Apache-2.0) e i modelli (MIT, CC-BY-4.0) sono compatibili con la ridistribuzione non commerciale; le loro licenze restano valide e vanno riportate (`docs/licenses.md`, sezione "Informazioni" dell'app).
