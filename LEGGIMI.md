# Avvio PC Pro — `setup-pc.ps1`

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

## 1. Scarica lo script

Dal PC cliente apri questo link e salva il file:

```
https://raw.githubusercontent.com/samuelenigro97-prog/test-setup-pc/main/setup-pc.ps1
```

Tasto destro → **Salva con nome** → salva come `setup-pc.ps1`.
⚠️ Verifica che il nome finisca in `.ps1` e **non** `.ps1.txt`.

Puoi salvarlo sul Desktop o su una chiavetta USB.

---

## 2. Avvio robusto (gestisce i blocchi di Windows)

Apri **PowerShell come Amministratore**
(Start → scrivi `PowerShell` → tasto destro → *Esegui come amministratore*).

Poi esegui, **sostituendo il percorso** con quello reale del file
(usa `$env:USERPROFILE` per l'utente corrente, qualunque sia il suo nome):

```powershell
# 1) consenti l'esecuzione script solo per questa sessione
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 2) rimuovi il blocco "file scaricato da Internet" (mark-of-the-web)
Unblock-File -Path "$env:USERPROFILE\Desktop\setup-pc.ps1"

# 3) avvia lo script
& "$env:USERPROFILE\Desktop\setup-pc.ps1"
```

In alternativa, in un colpo solo:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\setup-pc.ps1"
```

Se il file è su chiavetta (es. `D:`), usa `D:\setup-pc.ps1` al posto del percorso Desktop.

> **Nota percorso:** usa `$env:USERPROFILE` (es. `C:\Users\telef`) — NON un nome
> utente fisso come `oem`. Ogni PC può avere un profilo diverso.

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

| Step | Azione |
|------|--------|
| 0  | Lingua/regione **Italiano (it-IT)** + tastiera + language pack |
| 1  | Nome completo del cliente (cambia il "Nome visualizzato" dell'account) |
| 2  | Riscatto licenza **Office 365 abbonamento** (`setup.office.com`) |
| 3  | Installazione suite **Office / OpenOffice / LibreOffice** (winget) + subito dopo **attivazione Office perpetuo** con product key (`ospp.vbs`) |
| 4  | **Antivirus**: McAfee, Norton, o Salta |
| 4c | **Unieuro Cyber Protection** (opzionale, skippabile) — solo sito + credenziali app |
| 5  | Browser: Chrome / Firefox |
| 6  | App base: VLC, Adobe Reader, Spotify, 7-Zip, WhatsApp, Steam, AnyDesk, Discord, Zoom |
| —  | **Report finale**: esito reale (OK / ERRORE / SALTATO) di ogni operazione |

Antivirus **Norton/McAfee**: lo script apre il sito, tu registri e scarichi
l'installer (nome variabile) → lo script trova l'`.exe` più recente in **Download o
Desktop** e lo avvia.
**Unieuro Cyber Protection**: solo apertura sito + promemoria di annotare le
credenziali per l'app mobile del cliente (nessun installer PC).

Alla fine, se hai cambiato la lingua, lo script **propone il riavvio** (serve per
applicare display language e schermata di login).

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
| Language pack automatico (`Install-Language`) | ✅ | ❌ solo Win11 — su Win10 aggiungi il pacchetto ITA a mano |
| Lingua di sistema/login/nuovi utenti (`Copy-UserInternationalSettingsToSystem`) | ✅ | ❌ solo Win11 |
| Rilevamento Smart App Control | ✅ | non presente (ignorato) |
| Office, antivirus, browser, app (winget) | ✅ | ✅ (serve "App Installer" dallo Store) |

Le parti solo-Win11 sono protette da controllo: su Windows 10 vengono **saltate senza
errori**, il resto funziona.

---

## 7. Prima prova sicura (dry-run)

Per vedere il flusso senza installare nulla, rispondi:
STEP 0 `N` · STEP 2 `N` · STEP 3 `4` poi attivazione perpetuo `N` · STEP 4 `3` ·
STEP 4c `N` · Browser `N`/`N` · STEP 6 `S`. Arrivi al report finale senza toccare il PC.
