# 🖥️ PC Facile

[![Licenza MIT](https://img.shields.io/github/license/samuelenigro97-prog/pc-facile)](LICENSE.md)
[![CI](https://github.com/samuelenigro97-prog/pc-facile/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/samuelenigro97-prog/pc-facile/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/samuelenigro97-prog/pc-facile?display_name=tag&sort=semver)](https://github.com/samuelenigro97-prog/pc-facile/releases)

Automazione per la **configurazione dei computer nuovi dei clienti** in negozio:
lingua italiana, nome cliente, account, Office, antivirus, browser e app, con
report finale degli esiti e credenziali pronte da consegnare.

Due script, stesso flusso, due sistemi operativi:

| | Script | Versione | Righe | Avvio |
|---|---|---|---|---|
| 🪟 **Windows** | `setup-pc.ps1` | **10.3** (2026-08-14) | 3400 | doppio click su `PC Facile.bat` |
| 🍎 **macOS** | `setup-mac.sh` | **1.1** (2026-07-08) | 532 | `PC Facile.command` |

> 📖 **Istruzioni operative complete** (download, avvio, risoluzione problemi,
> compatibilità Windows 10/11): **[LEGGIMI.md](./LEGGIMI.md)**
> 📌 **Riprendi da qui** (stato, cose fragili, prossimi passi):
> **[docs/STATO_LAVORI.md](./docs/STATO_LAVORI.md)**

---

## Indice

1. [Avvio rapido](#avvio-rapido)
2. [Cosa fa lo script](#cosa-fa-lo-script)
3. [Windows e Mac: la regola della parità](#windows-e-mac-la-regola-della-parità)
4. [File del repository](#file-del-repository)
5. [Come è distribuito (e perché conta l'hash)](#come-è-distribuito-e-perché-conta-lhash)
6. [Sviluppo e qualità](#sviluppo-e-qualità)
7. [Prossime modifiche](#prossime-modifiche)

---

## Avvio rapido

### Windows

1. Scarica **`PC Facile.bat`**
   ([link diretto](https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/PC%20Facile.bat)).
2. Doppio click → conferma i privilegi di amministratore (UAC → *Sì*).
3. Il launcher scarica ed esegue **l'ultima versione** di `setup-pc.ps1` da
   GitHub, verificandone l'integrità.

Serve solo quel file. Tutto il resto è automatico.

### macOS

Doppio click su **`PC Facile.command`**, che avvia `setup-mac.sh`.

### Modalità tecniche (solo da riga di comando)

| Modalità | Windows | Mac | Cosa fa |
|---|---|---|---|
| **Test** | `-Test` | `--test` | Percorre tutto il flusso **senza installare né modificare nulla**. È anche lo smoke test della CI |
| **Diagnostica** | `-Diagnostica` | `--diagnostica` | Controlla ambiente e valida gli ID dei pacchetti, senza installare |
| **Veloce** | `-Veloce` | `--veloce` | Su Windows è ormai il comportamento predefinito; il parametro resta per compatibilità |
| **Salta ripristino** | `-skipRestore` | — | Salta il punto di ripristino (utile se la protezione sistema è disattivata) |

Comandi completi, anche per aggirare i blocchi di ExecutionPolicy, in
[LEGGIMI.md § 2-bis](./LEGGIMI.md).

## Cosa fa lo script

Flusso Windows in sintesi — il dettaglio passo per passo è in
[LEGGIMI.md § 4](./LEGGIMI.md).

Prima di partire esegue dei **controlli preliminari**: privilegi di
amministratore, blocchi di Windows (Smart App Control, ExecutionPolicy),
versione di Windows e PowerShell, riavvio in sospeso, spazio su disco,
**preflight di rete** (GitHub, Microsoft, CDN winget), sincronizzazione
dell'orologio e blocco della sospensione.

| Step | Azione |
|---|---|
| 1 | **Nome cliente** — cambia nome visualizzato dell'account e nome del PC, e genera le credenziali suggerite |
| 2 | **Account Microsoft** — col cliente davanti, così Office e antivirus non chiederanno altri OTP |
| 3 | **Pulizia e ottimizzazione** — antivirus di prova, bloatware OEM, promo dal menu Start, OneDrive. Sta **prima** della lingua e delle app, così un AV di prova non blocca i passi successivi |
| 4 | **Lingua italiana** (it-IT) — display, formati, tastiera, language pack, propagazione a login e nuovi utenti |
| 5 | **Punto di ripristino** — rete di sicurezza prima delle modifiche |
| 6 | **Office** — installa la suite scelta e gestisce l'attivazione (card PIN → riscatto web), poi crea i collegamenti sul Desktop |
| 7 | **Unieuro Cyber Protection** — apertura portale e credenziali per l'app del cliente |
| 8 | **App + browser** — profilo a scelta; il browser si installa da solo (Chrome, o Opera GX per GAMING) |
| 9 | **Aggiornamenti** — `winget upgrade --all` più gli aggiornamenti di sicurezza di Windows |
| 10 | **Driver** — tool del produttore se la GPU è dedicata, poi driver generici da Windows Update |
| 11 | **Antivirus** — McAfee, Norton o Salta. È l'ultimo passo, così un AV appena attivato non blocca le installazioni precedenti |
| — | **Report finale** — chiave BitLocker e due file sul Desktop, poi riavvio |

**Profili app:** BASE (VLC, Adobe Reader, 7-Zip, WhatsApp, Spotify, Zoom,
AnyDesk, AIMP) · UFFICIO (BASE + GIMP, Sumatra PDF) · GAMING (BASE + Steam,
Epic, Discord, qBittorrent) · COMPLETO · MANUALE.

Tre comportamenti che rendono lo script usabile al banco:

- **Ripresa della sessione** — se lo script si interrompe (crash, riavvio,
  blocco dell'antivirus), al lancio successivo propone di riprendere da dove
  era arrivato. Il checkpoint è un JSON in `ProgramData\PCFacile` e si cancella
  da solo a lavoro finito.
- **Bip di richiamo** — quando serve una risposta fa un bip; se non rispondi
  entro 2 minuti inizia a bipare a intervalli, così te ne accorgi da lontano.
- **Barra di avanzamento** — durante download e installazioni, al posto
  dell'output tecnico di winget.

### File prodotti

| File | Dove | Contenuto |
|---|---|---|
| `Il tuo nuovo PC - <cliente>.txt` | Desktop | Riepilogo per il cliente, **credenziali in cima** |
| `Credenziali - <cliente>.txt` | Desktop | Solo le credenziali, file dedicato |
| `setup-pc_log_<data>.txt` | Desktop | Log completo della sessione |
| `setup-pc_report_<data>.txt` | Desktop | Esiti puliti: OK / ERRORE / SALTATO |
| Log JSON + CSV | `ProgramData\PCFacile\log` | Log strutturato, per analisi |

> ⚠️ Riepilogo e file credenziali contengono **intenzionalmente** password in
> chiaro e la chiave di ripristino BitLocker: restano col PC del cliente. Non
> vanno mai allegati a issue, commit o log pubblici — vedi
> [SECURITY.md](./SECURITY.md).

## Windows e Mac: la regola della parità

**Una modifica a una versione va replicata sull'altra.** La mappa completa
passo-per-passo — cosa è pari, cosa esiste solo su Windows, cosa solo su Mac —
è in **[PARITA.md](./PARITA.md)**, che va letto *prima* di toccare uno dei due
script.

In sintesi, oggi:

- **Pari su entrambi:** lingua, orario, nome cliente, punto di ripristino
  (Checkpoint / snapshot Time Machine), account e credenziali, Cyber
  Protection, browser, app per profilo, aggiornamenti, chiave di cifratura
  disco (BitLocker / FileVault), avviso sonoro, pulizia finale.
- **Solo Windows:** Office, antivirus, debloat OEM e barra di Win11, barra di
  attesa, bip ricorrente, ripresa sessione, icone sul Desktop, log strutturato,
  `trap` di sicurezza sugli errori.
- **Solo Mac:** installazione di Rosetta 2 su Apple Silicon.

Le voci marcate *TODO* in `PARITA.md` (log strutturato e trap su Mac) sono
lavoro aperto: vedi [Prossime modifiche](#prossime-modifiche).

## File del repository

```
pc-facile/
├── PC Facile.bat            # launcher Windows: UAC, download, verifica hash, avvio
├── PC Facile.command        # launcher macOS
├── setup-pc.ps1             # 🪟 lo script principale (3400 righe, v10.3)
├── setup-pc.ps1.sha256      # impronta dello script, verificata dal launcher
├── setup-mac.sh             # 🍎 versione macOS (532 righe, v1.1)
├── tests/PcFacile.Tests.ps1 # test Pester sulle funzioni pure
├── PSScriptAnalyzerSettings.psd1
├── .github/workflows/
│   ├── ci.yml               # qualità: sintassi + analyzer + Pester + hash
│   └── test.yml             # smoke test end-to-end Windows + Mac
├── docs/
│   ├── STATO_LAVORI.md      # 📌 handoff: stato, cose fragili, prossimi passi
│   └── RELEASE.md           # checklist di rilascio manuale
├── LEGGIMI.md               # 📖 manuale operativo completo
├── PARITA.md                # mappa della parità Windows ↔ Mac
├── SECURITY.md              # distribuzione, integrità, dati sensibili
└── CHANGELOG.md · LICENSE.md · README.md
```

## Come è distribuito (e perché conta l'hash)

`PC Facile.bat` è pensato per vivere su una chiavetta USB e restare aggiornato
da solo. A ogni avvio:

1. Scarica `setup-pc.ps1` da `main` su GitHub — e se GitHub è bloccato, riprova
   dal **CDN jsDelivr** come seconda fonte.
2. Ne verifica lo **SHA256** contro `setup-pc.ps1.sha256`. Se non combacia
   (download corrotto o troncato) scarta il file e usa la copia locale sulla
   chiavetta.
3. Dopo un download riuscito **salva la copia sulla chiavetta**, che diventa la
   riserva offline per la volta successiva.
4. Usa un nome file temporaneo unico e fino a 3 tentativi, per non inciampare
   in "Access is denied".

> L'hash rileva le corruzioni ma, essendo pubblicato nello stesso repository,
> **non sostituisce una firma digitale**. Il passaggio a una firma Authenticode
> è descritto in [SECURITY.md](./SECURITY.md).

## Sviluppo e qualità

### Regola d'oro: dopo ogni modifica a `setup-pc.ps1`, rigenera l'hash

```powershell
(Get-FileHash ./setup-pc.ps1 -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-pc.ps1.sha256
```

Se l'hash è disallineato **la CI fallisce** — ed è voluto: un hash vecchio
significa che tutti i launcher scartano lo script nuovo e continuano a usare la
copia offline.

### Le due pipeline

| Workflow | Quando | Cosa fa |
|---|---|---|
| **`ci.yml`** | ogni push e PR, su qualsiasi branch | Controllo sintassi col parser PowerShell · PSScriptAnalyzer (solo gli **errori** bloccano, i warning no) · test Pester · verifica che lo SHA256 sia aggiornato. Il token ha `contents: read`, privilegio minimo |
| **`test.yml`** | push su `main` e avvio manuale | **Windows:** sintassi, presenza di winget, smoke test `-Test` end-to-end, PSScriptAnalyzer con retry. **Mac:** `zsh -n` e smoke test `--test` |

Lo smoke test è la parte che cattura di più: `-Test` rende lo script non
interattivo e non distruttivo, quindi percorre tutto il flusso e trova gli
errori di **runtime**, non solo quelli statici.

### Test in locale

```powershell
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Path ./setup-pc.ps1 -Settings ./PSScriptAnalyzerSettings.psd1
```

I test Pester coprono le **funzioni pure** (quelle senza effetti sul sistema):
generazione password e email del cliente secondo la convenzione del negozio,
riconoscimento di nomi simili, collegamenti spazzatura, comando "indietro", più
un controllo che la sorgente sia sintatticamente valida.

### Rilascio

Checklist in **[docs/RELEASE.md](./docs/RELEASE.md)**. In sintesi: Pester +
analyzer → rigenera l'hash → verifica che il launcher scarichi la versione
attesa → tag semver → GitHub Release con `setup-pc.ps1`,
`setup-pc.ps1.sha256` e il launcher.

Il numero di versione va alzato in `$SCRIPT_VERSION` dentro `setup-pc.ps1`
(compare nell'header e **nella barra del titolo della finestra**, così
l'operatore vede al volo se la chiavetta è aggiornata).

## Prossime modifiche

| # | Intervento | Priorità | Nota |
|---|---|---|---|
| 1 | **Parità Mac: log strutturato e `trap` sugli errori** | 🟠 | Sono le due voci ancora marcate *TODO* in `PARITA.md`. Su Windows ci sono già (JSON + CSV in `ProgramData\PCFacile\log`, `trap` a livello script) |
| 2 | **Firma Authenticode dello script** | 🟠 Sicurezza | Sostituirebbe davvero l'hash e toglierebbe di mezzo gli avvisi SmartScreen. Serve un certificato aziendale di code signing; la chiave privata non deve mai finire nel repository |
| 3 | **Workflow di release automatica** | 🟡 | `release.yml` su tag `v*`: test, artifact (`setup-pc.ps1`, hash, launcher) e pubblicazione. Richiede il permesso `workflow` sul token |
| 4 | **Estendere i test Pester** | 🟡 | Oggi coprono solo le funzioni pure. Restano scoperte le parti a effetti collaterali, che però richiedono mock su registro e filesystem |
| 5 | **Ripresa sessione anche su Mac** | 🟢 | Su Windows il checkpoint JSON esiste ed è molto utile; su Mac le sessioni sono più corte, quindi vale meno |
| 6 | **Generazione del changelog da commit/PR** | 🟢 | Oggi il changelog si scrive a mano |

---

Licenza [MIT](LICENSE.md). Per le segnalazioni di sicurezza usa una
**Security advisory privata**, non una issue pubblica — vedi
[SECURITY.md](./SECURITY.md).
