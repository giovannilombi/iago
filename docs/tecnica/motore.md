# Motore locale

## Scelta (ADR-0048)
- **MLX Swift dentro l'app** (`App/Sources/Engine`): nessun server locale, nessuna porta aperta, niente Ollama o simili. Apple Intelligence non si usa per i contenuti.
- Modelli **quantizzati a 4 bit** da `mlx-community` su Hugging Face, **fissati a un commit** e verificati con **SHA-256** di ogni file; il download parte solo su richiesta dell'utente.
- Il catalogo (`IAGOEngine/EngineCatalog.swift`) si genera con `scripts/make-engine-catalog.py`.

## Catalogo
| Modello | Parametri | Memoria | Consigliato | Uso |
|---|---|---|---|---|
| Qwen 3.5 4B | 4B | circa 3,5 GB | sotto i 16 GB | Riordina testo, proposte, Chiedi; **non** le sintesi |
| Qwen 3.5 9B | 9B | circa 6 GB | 16 GB | tutto, sintesi discrete (64-97 s per 30 minuti di call) |
| Gemma 4 12B | 12B | circa 12,5 GB | 32 GB o più | tutto, sintesi più ricche (161-272 s) |
| Qwen3 Embedding 0.6B | 0,6B | 0,35 GB | sempre, con il primo motore | ricerca per significato |

- `EngineCatalog.recommended(forRAMGB:)` propone Gemma da 32 GB in su, il 9B da 16 GB, il 4B sotto.
- `EngineCatalog.minimumBillions` fissa il minimo per funzione: le sintesi vogliono almeno 9B.
- **In valutazione:** MiniCPM al posto del 4B o in aggiunta (ADR-0067, proposto).

## Come si prova un modello
- `open /Applications/IAGO.app --args -IAGOEngineBench "<titolo di un elemento>"` fa girare ogni modello scaricato su quell'elemento (Riordina testo, proposte, Chiedi) e scrive tempi e risultati in locale.
- La prova delle sintesi su call reali è descritta in [sintesi e glossario](/benchmarks/2026-10-21-sintesi-e-glossario): solo numeri e osservazioni, mai contenuti.
- `scripts/test-engine.sh` compila l'app con MLX e gli shader Metal; la CI non lo fa (costa troppi minuti), quindi va lanciato prima di ogni PR che tocca il motore.
