# Privacy e rete

## Il principio (ADR-0058)
**Niente lascia il Mac a meno che l'utente non lo voglia.** I livelli sono tre, tutti scelti dall'utente:
1. **Sul Mac**, sempre: archivio cifrato, trascrizione e motore locali.
2. **Con Claude**, progetto per progetto (vedi [Claude e MCP](./claude-mcp)).
3. **In uno spazio condiviso** che controlla l'utente o l'azienda (fase 4, ADR-0057 proposto).

## Connessioni ammesse
Le uniche uscite di rete, tutte esplicite e registrate nel registro accessi:

| # | Connessione | Quando |
|---|---|---|
| 1 | Download dei modelli da URL fissi (Hugging Face, commit fissato) con verifica SHA-256 | solo su azione dell'utente |
| 2 | API locale di Teams su `127.0.0.1:8124` | solo se l'utente la attiva (ADR-0051) |
| 3 | MCP solo stdio | nessuna porta: non è rete |
| 4 | Sincronizzazione | fase 4, da decidere (ADR-0012 / ADR-0057) |
| 5 | Controllo e download degli aggiornamenti da GitHub Releases (Sparkle, firma EdDSA) | una volta al giorno o a mano (ADR-0056) |

`scripts/check-network-apis.sh` gira in CI e fallisce se nel codice compare un'API di rete fuori da questi punti.

## Nessuna telemetria
- Niente analytics, crash reporter remoti o telemetria: se una libreria la fa, va spenta o sostituita.
- I **log** di sistema (`subsystem com.giovannilombi.iago`) non contengono contenuti delle trascrizioni, dei documenti o delle note.

## Contenuti e repository
- L'app **non contiene contenuti**: un archivio nuovo ha solo l'esempio di struttura (ADR-0066).
- Il repository non contiene **mai** dati reali: un controllo prima di ogni commit blocca audio, archivi, trascrizioni, email e i nomi reali elencati localmente (ADR-0065). Test ed esempi usano nomi inventati.
