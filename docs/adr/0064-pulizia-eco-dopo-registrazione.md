# ADR-0064 — Pulizia dell'eco dopo la registrazione

- Stato: rifiutato (2026-10-21)
- Data: 2026-10-21
- Riferimenti spec: sez. 6 (cattura), 7 (trascrizione); ADR-0002 (due tracce), ADR-0053 (ritirato); richiesta dell'utente 2026-10-21

## Contesto
- Senza cuffie il microfono sente le casse: le voci degli altri tornano sulla traccia dell'utente, in ritardo.
- La cancellazione dell'eco di macOS durante la call (ADR-0053) è stata ritirata, perché lasciava Teams senza microfono.
- IAGO ha però un vantaggio che le app di call non hanno: la **traccia di sistema**, cioè esattamente ciò che è uscito dalle casse, registrata sullo stesso orologio del microfono. Il riferimento per togliere l'eco è perfetto e già allineato.

## Decisione proposta
- **Quando:** a registrazione finita, la traccia del microfono viene pulita usando la traccia di sistema come riferimento. È un lavoro della coda (QoS `.utility`, uno alla volta, mai durante una registrazione), prima della trascrizione.
- **Mai durante la call:** il microfono dell'app di call non viene toccato.
- **L'originale resta:** la traccia pulita è una copia. Si usa per trascrivere e per ascoltare, e si può sempre tornare all'originale.
- **Motore del prototipo:** il cancellatore d'eco di **SpeexDSP** (MDF a blocchi in frequenza, più la soppressione dell'eco residua), licenza BSD, incluso come sorgente C.
  - Se la qualità non basta, si passa a **WebRTC AEC3**, più efficace ma C++ con dipendenze pesanti.
- **Attivabile e disattivabile** in Impostazioni › Audio, come richiesto dall'utente. Il valore predefinito si decide dopo le misure.

## Da misurare con il prototipo
- **Quanta eco toglie** su una registrazione reale senza cuffie: livello della voce degli altri sulla traccia del microfono, prima e dopo.
- **Quanto rispetta la voce dell'utente** quando si parla insieme (prova sintetica con voce vicina e voce lontana).
- **Tempo e carico per un'ora di call.** Stima: da qualche secondo a circa un minuto, su un core, contro circa 3 minuti della trascrizione Whisper.

## Conseguenze
- Nessun rischio per la call in corso: tutto avviene dopo, sui file.
- Una dipendenza nuova, da registrare in `docs/licenses.md`.

## Prima misura del prototipo (2026-10-21)
- **Prova sintetica** (test automatico `EchoCleanerTests`, con eco a 47 ms più due riflessioni e un tratto in cui si parla insieme):
  - eco ridotta di **19 dB**;
  - voce vicina conservata al **95%**;
  - 20 s puliti in 0,09 s.
- **Call reale di 31 minuti** senza cuffie (la traccia del microfono dell'utente, con la traccia di sistema come riferimento):
  - pulita in **7,9 s**, cioè circa 15 s per un'ora e 234 volte più veloce del tempo reale;
  - un solo core, circa 490 MB di picco;
  - quanto il microfono segue l'audio delle casse scende da 0,74 a 0,32 (0 = nessuna eco).
- **Ascolto:** su uno spezzone di 40 secondi, originale e pulito, l'utente ha preferito l'originale (vedi sotto).
- **Strumenti** usati per la prova (`iago-bench --aec`, estrazione delle tracce in Debug): tolti insieme al prototipo.

## Esito: rifiutato (2026-10-21)
- **All'ascolto** dello stesso spezzone, originale e pulito, l'utente ha trovato **molto migliore l'originale**. I numeri (meno eco) non bastano se la voce dell'utente peggiora.
- **Decisione:**
  - la pulizia non si fa;
  - SpeexDSP, `EchoCleaner`, la prova `iago-bench --aec` e l'estrazione delle tracce sono stati tolti dal codice;
  - per l'eco resta il **filtro in trascrizione**, che scarta le frasi della traccia di sistema ripetute sul microfono (ADR-0002), più il consiglio delle cuffie.
- **Motivo per non insistere:** non è una priorità, e ogni tentativo richiede prove d'ascolto dell'utente. Un'eventuale prova con WebRTC AEC3 resta possibile in futuro, ma solo con una richiesta nuova.
