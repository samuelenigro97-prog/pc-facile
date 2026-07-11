# PC Facile — `setup-pc.ps1`

Script PowerShell per configurare i PC Windows dei clienti (negozio informatica):
lingua italiana, nome cliente, Office, antivirus/protezione, browser, app base,
con **report finale** degli esiti.

---

## 0. Prima di iniziare — Lingua in Italiano

I PC installati da chiavetta USB spesso saltano la scelta lingua e partono in
**inglese**. Lo **STEP 0** dello script imposta tutto in `it-IT` (display, formati,
tastiera, language pack). La lingua di **sistema** si applica del tutto **dopo il
riavvio**.

> Se preferisci farlo a mano prima: Impostazioni → Ora e lingua → Lingua e area
> geografica → aggiungi **Italiano (Italia)** e impostalo come predefinito.

---

## 1. Scarica il launcher

Ti basta **UN file**: `PC Facile.bat`.

```
https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/PC%20Facile.bat
```

Tasto destro → **Salva con nome** → `PC Facile.bat`.
⚠️ Verifica che finisca in `.bat` e **non** `.bat.txt`.

`PC Facile.bat` da solo scarica ed esegue l'ultima versione dello script da GitHub
(serve Internet — sui PC da configurare c'è, serve anche per winget).

Il launcher scarica **sempre l'ultima versione** da GitHub, così è aggiornato da
solo (niente copie vecchie sulla chiavetta).

**Uso OFFLINE (fallback):** se vuoi poter lavorare senza Internet, scarica anche
`setup-pc.ps1` e mettilo **nella stessa cartella** di `PC Facile.bat`. Serve solo
se il download fallisce: in quel caso il launcher usa la copia accanto. Ricordati
di rinfrescarla ogni tanto, altrimenti offline resti a una versione vecchia.
```
https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1
```

---

## 2. Avvio FACILE (consigliato) — doppio click

**Doppio click su `PC Facile.bat`.** Fa tutto da solo:
- chiede i privilegi di amministratore (UAC → *Sì*)
- scarica ed esegue l'ultima versione da GitHub (copia accanto = fallback offline)
- avvia con ExecutionPolicy Bypass

Niente comandi da digitare.

> **Durante la configurazione:** all'inizio scegli **C** (Configura) / **D**
> (Diagnostica) / **T** (Test). Dentro un passo, digita **B** al prompt per
> tornare al passo precedente; altrimenti dopo ogni scelta si avanza da solo.

> Se Windows/SmartScreen avvisa sul `.bat`: *Ulteriori info → Esegui comunque*.
> Se **Smart App Control** blocca tutto → vedi punto 3.

---

## 2-bis. Avvio manuale da PowerShell (a prova di blocco)

Apri **Windows PowerShell** (NON la versione "(x86)") **come Amministratore**
(Start → scrivi `PowerShell` → tasto destro → *Esegui come amministratore*).

Usa questi comandi: eseguono lo script **in memoria** (come scriptblock), quindi
**non** danno l'errore "L'esecuzione di script è disabilitata" e accettano i
parametri. Non serve salvare file né toccare l'ExecutionPolicy.

```powershell
# CONFIGURA il PC (installa e imposta)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1)))

# DIAGNOSTICA (controlla ID pacchetti e ambiente, NON installa)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -Diagnostica

# TEST a vuoto (percorre tutto senza installare/modificare)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-pc.ps1))) -Test
```

Se invece hai il file salvato e vuoi lanciarlo da file:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\setup-pc.ps1"
```

> ⚠️ **Perché l'errore "esecuzione disabilitata"?** Windows blocca i file `.ps1`
> di default. Eseguire come scriptblock in memoria (comandi sopra) o con
> `-ExecutionPolicy Bypass` lo evita. Lo script non puo' risolverlo da dentro:
> il blocco avviene PRIMA che parta.
>
> **Nota percorso:** usa `$env:USERPROFILE` (es. `C:\Users\telef`) — NON un nome
> utente fisso come `oem`. Ogni PC ha un profilo diverso.

---

## 3. Se lo script NON parte proprio (Smart App Control)

Su alcuni PC il **Controllo intelligente delle app** (Smart App Control) blocca il
`.ps1` scaricato da Internet **senza** dare l'opzione "Esegui comunque".

Per disattivarlo:

**Sicurezza di Windows → Controllo app e browser → Controllo intelligente delle app → Disattivato**

> ⚠️ **IRREVERSIBILE:** una volta disattivato, Smart App Control **non si può più
> riattivare** senza reinstallare/resettare Windows. Valuta se il cliente lo vuole
> davvero spento. In alternativa, prepara lo script da una fonte considerata
> attendibile (es. copialo da chiavetta invece di scaricarlo).

Lo script, se riesce a partire, rileva da solo Smart App Control attivo e ti avvisa.

---

## 4. Cosa fa lo script (in ordine)

All'avvio lo script esegue alcuni **controlli**: privilegi admin, blocchi Windows
(Smart App Control/ExecutionPolicy), versione Windows/PowerShell, **riavvio in
sospeso**, **spazio disco**, **preflight di rete** (GitHub/Microsoft/CDN winget),
sincronizza l'**orologio** ed evita che il PC vada in **sospensione**.

| Step | Azione |
|------|--------|
| —  | **Punto di ripristino** (opzionale, consigliato): rete di sicurezza prima delle modifiche |
| 0  | Lingua/regione **Italiano (it-IT)** + tastiera + language pack + propagazione a login/nuovi utenti |
| 1  | Nome completo del cliente (cambia il "Nome visualizzato" dell'account) |
| 2  | **Installazione app Office** (Office 365, perpetuo, OpenOffice, LibreOffice via winget): la suite scelta si installa se manca |
| 3  | **Attivazione**: card con PIN da grattare → riscatto web (`microsoft365.com/setup` per M365, `office.com/setup` per il perpetuo) con l'account Microsoft del cliente, poi accesso in Word |
| 4  | **Antivirus**: McAfee, Norton, o Salta |
| 4c | **Unieuro Cyber Protection** (opzionale, skippabile) — solo sito + credenziali app |
| 5  | Browser: Chrome / Firefox |
| 6  | App: **profili** BASE / UFFICIO / GAMING / COMPLETO, oppure MANUALE (VLC, Adobe Reader, Spotify, 7-Zip, WhatsApp, Steam, AnyDesk, Discord, Zoom) |
| —  | **Report finale**: esito reale (OK / ERRORE / SALTATO / AVVISO) di ogni operazione + riavvio |

**Profili app (STEP 6):**
- **BASE** — VLC, Adobe Reader, 7-Zip, WhatsApp, AnyDesk
- **UFFICIO** — BASE + Zoom, Spotify
- **GAMING** — BASE + Steam, Discord
- **COMPLETO** — tutte · **MANUALE** — scegli i singoli numeri

Antivirus **Norton/McAfee**: lo script apre il sito, tu registri e scarichi
l'installer (nome variabile) → lo script trova l'`.exe` più recente in **Download o
Desktop** e lo avvia.
**Unieuro Cyber Protection**: solo apertura sito + promemoria di annotare le
credenziali per l'app mobile del cliente (nessun installer PC).

**Ripresa sessione**: se lo script si chiude a metà (crash, riavvio, blocco
antivirus), al lancio successivo propone di **riprendere da dove eri arrivato**:
i passi già completati vengono saltati. Il checkpoint si cancella da solo a
lavoro finito.

**Collegamenti sul Desktop**: dopo l'installazione di Office lo script crea i
collegamenti a **Word, Excel, PowerPoint, Outlook e OneNote** sul Desktop.

La pulizia toglie anche i **collegamenti promo dal menu Start** (Booking.com,
"Offerte Adobe", HP Documentation).

Alla fine, se hai cambiato la lingua, lo script **propone il riavvio** (serve per
applicare display language e schermata di login).

All'avvio lo script fa un **preflight di rete**: controlla se GitHub, Microsoft e il
CDN winget sono raggiungibili e avvisa subito se la rete (aziendale/proxy) blocca
qualcosa.

---

## 4-bis. Rete aziendale / con firewall o proxy

I PC nuovi **non sono nel dominio** aziendale: usano solo la connessione. Le policy
aziendali (Group Policy, AppLocker) **non** si applicano al PC fresco. Il rischio è
solo che il **firewall/proxy blocchi i download**:

- **GitHub bloccato** → usa la modalità **offline**: tieni `setup-pc.ps1` accanto ad
  `PC Facile.bat` (niente download).
- **Winget/CDN Microsoft bloccati** → le app non si installano (il report lo segnala).
  Rimedio: **hotspot del telefono** per la fase installazioni, o installa dopo su rete
  senza filtri.
- **Proxy con login** → i download automatici possono fallire; usa hotspot.

Il preflight all'avvio ti dice **subito** cosa è raggiungibile, così non scopri il
blocco a metà lavoro.

---

## 5. File generati (log e report)

Al termine, sul **Desktop** trovi due file datati:

- `setup-pc_log_<data>.txt` — log completo di tutta la sessione (prova di cosa è
  stato fatto su quel PC).
- `setup-pc_report_<data>.txt` — riepilogo pulito degli esiti (OK / ERRORE / SALTATO).

Utili da archiviare o allegare alla scheda cliente.

---

## 6. Compatibilità Windows 10 / 11

| | Windows 11 | Windows 10 |
|---|---|---|
| Lingua base (tastiera, formati, regione) | ✅ | ✅ |
| Language pack automatico (`Install-Language`) | ✅ | ❌ solo Win11 — su Win10 lo script apre Impostazioni lingua per aggiungerlo a mano |
| Lingua di sistema/login/nuovi utenti (`Copy-UserInternationalSettingsToSystem`) | ✅ | ❌ solo Win11 |
| Rilevamento Smart App Control | ✅ | non presente (ignorato) |
| Office, antivirus, browser, app (winget) | ✅ | ✅ (serve "App Installer" dallo Store) |

Le parti solo-Win11 sono protette da controllo: su Windows 10 vengono **saltate senza
errori**, il resto funziona.

---

## 7. Prima prova sicura (dry-run)

Per vedere il flusso senza installare nulla, rispondi:
Punto di ripristino `N` · STEP 0 `N` · STEP 2 `N` · STEP 3 `4` poi attivazione
perpetuo `N` · STEP 4 `3` · STEP 4c `N` · Browser `N`/`N` · STEP 6 `S`.
Arrivi al report finale senza toccare il PC.
