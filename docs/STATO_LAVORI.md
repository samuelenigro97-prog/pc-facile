# Stato lavori — handoff

> Documento di passaggio di consegne. Aggiornato al **20 agosto 2026**.
> Scopo: permettere a chiunque (persona o assistente AI) di riprendere il lavoro
> senza ricostruire il contesto da zero. Va aggiornato quando cambia qualcosa di
> rilevante.

### Dove sta cosa

| Documento | Contiene |
|---|---|
| [`README.md`](../README.md) | Mappa del progetto: entrambi gli script, flusso, distribuzione, CI, roadmap |
| [`LEGGIMI.md`](../LEGGIMI.md) | **Manuale operativo** per chi usa lo script al banco: download, avvio, blocchi di Windows, dry-run |
| [`PARITA.md`](../PARITA.md) | Mappa passo-per-passo della parità Windows ↔ Mac |
| [`SECURITY.md`](../SECURITY.md) | Distribuzione, integrità, dati sensibili |
| **questo file** | Stato dei lavori, punti fragili, scelte fatte, prossimi passi |
| [`CHANGELOG.md`](../CHANGELOG.md) · [`RELEASE.md`](RELEASE.md) | Storico e checklist di rilascio |

---

## 1. A che punto è il progetto

**In produzione e usato davvero al banco.** Non è un prototipo: `setup-pc.ps1`
è arrivato alla versione **10.3** dopo ~38 pull request, ha una suite di test,
due pipeline di CI e un meccanismo di distribuzione con verifica di integrità.

| Componente | Stato |
|---|---|
| `setup-pc.ps1` (Windows) | ✅ Maturo — v10.3, 3400 righe, 11 passi, ripresa sessione, log strutturato |
| `setup-mac.sh` (macOS) | 🟡 Funzionante ma indietro — v1.1, 532 righe. Mancano log strutturato e trap errori |
| Launcher `PC Facile.bat` | ✅ Maturo — doppia fonte di download, verifica SHA256, copia di riserva, retry |
| Test Pester | 🟡 Solo funzioni pure (5 gruppi) |
| CI | ✅ Due workflow, incluso smoke test end-to-end su entrambi i sistemi |
| Release automatica | ❌ Manuale, serve il permesso `workflow` |

## 2. Le tre cose da sapere prima di toccare il codice

### a) L'hash va rigenerato, sempre

Dopo **qualsiasi** modifica a `setup-pc.ps1`:

```powershell
(Get-FileHash ./setup-pc.ps1 -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-pc.ps1.sha256
```

Se te lo dimentichi la CI fallisce — ed è la cosa giusta: con l'hash vecchio
tutti i launcher scartano lo script nuovo e continuano a usare la copia offline
sulla chiavetta. Il risultato sarebbe una modifica che *sembra* pubblicata ma
non arriva a nessuno.

Nello stesso commit va alzato anche `$SCRIPT_VERSION`: è il numero che compare
nella barra del titolo della finestra e che l'operatore usa per capire se la
chiavetta è aggiornata.

### b) La regola della parità Windows ↔ Mac

Una modifica al flusso di uno script va replicata sull'altro, o va scritto in
[`PARITA.md`](../PARITA.md) perché non si può. Quel file è la mappa: senza,
le due versioni divergono in fretta e diventa impossibile capire quale sia il
comportamento "giusto".

### c) L'ordine dei passi non è casuale

Due scelte contro-intuitive che sembrano riordinabili ma non lo sono:

- **La pulizia sta al passo 3, prima della lingua e delle app.** Un antivirus
  di prova preinstallato blocca le installazioni successive: va rimosso prima.
- **L'antivirus vero si installa per ultimo (passo 11).** Un AV appena
  attivato blocca le installazioni che verrebbero dopo.

Spostarli sembra una semplificazione e invece rompe il flusso sui PC reali.

## 3. Scelte fatte, e perché

- **Doppio click invece che menu.** Fino alla 9.x c'era un menu iniziale; ora
  il flusso è unico e chiede solo 5 cose (nome cliente, account, Office,
  profilo app, antivirus). Diagnostica e Test sono passate a parametri da riga
  di comando perché al banco non servivano e allungavano ogni sessione.
- **Il launcher scarica sempre da GitHub.** Evita che sulle chiavette restino
  versioni vecchie. La copia locale è solo la riserva per quando la rete del
  negozio blocca il download.
- **PSScriptAnalyzer: solo gli errori bloccano.** I warning sono tantissimi
  (`Write-Host` è usato ovunque, ed è voluto: l'output colorato serve
  all'operatore). Bloccare sui warning avrebbe reso la CI inutile.
- **I test coprono solo le funzioni pure.** Il resto dello script tocca
  registro, servizi e installazioni: testarlo richiederebbe mock pesanti. Il
  ruolo di "test di integrazione" lo fa lo **smoke test `-Test`** in CI, che
  percorre tutto il flusso senza modificare nulla.
- **Le credenziali in chiaro nei file sul Desktop sono volute.** Servono al
  flusso del negozio e restano col PC del cliente. È documentato in
  `SECURITY.md` e non va "corretto" per prudenza.
- **Smart App Control non si aggira.** Se blocca lo script, la disattivazione è
  **irreversibile** senza reinstallare Windows: è una scelta che spetta al
  cliente, non allo script.

## 4. Manutenzione ordinaria

- **Niente commit diretti su `main`**: branch dedicato + PR (la CI gira su
  qualsiasi branch, quindi il riscontro arriva subito).
- Prima di ogni push, in locale:
  ```powershell
  Invoke-Pester ./tests
  Invoke-ScriptAnalyzer -Path ./setup-pc.ps1 -Settings ./PSScriptAnalyzerSettings.psd1
  ```
- Interfaccia, commenti e documentazione **in italiano**.
- I messaggi a video usano simboli costruiti a runtime con `[char]` invece di
  caratteri Unicode letterali: PowerShell 5.1 legge il file senza BOM e li
  storpierebbe. Non sostituirli con emoji o caratteri diretti.
- Per provare il flusso senza rischi c'è il **dry-run** descritto in
  [`LEGGIMI.md` § 7](../LEGGIMI.md): si arriva al report finale senza toccare
  il PC.

## 5. Prossimi passi

In ordine di utilità reale.

### A. Portare il Mac alla parità — log strutturato e trap errori

Sono le due voci ancora marcate *TODO* in `PARITA.md`. Su Windows esistono già:

- **log strutturato** JSON + CSV in `ProgramData\PCFacile\log`;
- **`trap` a livello script** con lista degli imprevisti, che evita che un
  errore non gestito chiuda tutto senza spiegazioni.

Su Mac servirebbero l'equivalente con `set -e` / `trap` e un file di log in una
directory dedicata. È il divario più concreto tra le due versioni.

### B. Firma Authenticode

L'hash SHA256 rileva le corruzioni, ma essendo pubblicato **nello stesso
repository** non protegge da una manomissione a monte, e non toglie gli avvisi
di SmartScreen. La firma con un certificato aziendale di code signing
risolverebbe entrambe le cose.

Vincolo: la chiave privata non deve mai finire nel repository né nei workflow
senza un archivio segreti dedicato. Finché non c'è un certificato, non c'è
niente da implementare.

### C. Release automatica

`release.yml` su tag `v*`: test, artifact (`setup-pc.ps1`, l'hash, il launcher)
e pubblicazione della release. Richiede il permesso `workflow` sul token, oggi
non disponibile — per questo `docs/RELEASE.md` è una checklist manuale.

### D. Migliorie minori

- **Estendere i test Pester** oltre le funzioni pure (serve mock su registro e
  filesystem).
- **Ripresa sessione su Mac**: su Windows è molto utile, su Mac le sessioni
  sono più corte e vale meno.
- **Changelog generato da commit/PR** invece che scritto a mano.

### E. Da non fare

- **Non riordinare i passi 3 e 11** (pulizia e antivirus): vedi §2-c.
- **Non bloccare la CI sui warning** di PSScriptAnalyzer.
- **Non rimuovere le credenziali in chiaro** dai file di riepilogo: sono parte
  del flusso di consegna al cliente.
- **Non aggirare Smart App Control** da dentro lo script.
