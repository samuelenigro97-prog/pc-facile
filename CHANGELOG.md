# Changelog

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/).

Versione corrente: **`setup-pc.ps1` 10.3** (2026-08-14) · **`setup-mac.sh` 1.1**
(2026-07-08).

> ⚠️ **Due regole del progetto a ogni modifica:**
> 1. alzare `$SCRIPT_VERSION` in `setup-pc.ps1` (si vede nella barra del titolo:
>    serve a capire se la chiavetta è aggiornata);
> 2. rigenerare `setup-pc.ps1.sha256`, altrimenti i launcher scartano lo script
>    nuovo e la CI fallisce.

## [Non rilasciato]

### Modificato
- README riscritto come mappa completa del progetto: ora documenta **entrambi**
  gli script (Windows e Mac), il flusso a 11 passi, i file prodotti, il
  meccanismo di distribuzione del launcher, le due pipeline di CI e la roadmap.
  Prima parlava solo della versione Windows e non menzionava `setup-mac.sh`.
- Changelog riorganizzato con lo storico reale delle versioni, ricostruito dai
  commit.

### Aggiunto
- `docs/STATO_LAVORI.md`: documento di handoff con stato, punti fragili,
  scelte fatte e prossimi passi.

---

## [10.x] — flusso al banco e robustezza del launcher

### Aggiunto
- **Aggiornamenti di Windows in background**: scaricano mentre lo script
  prosegue e si installano a fine sessione.
- **Launcher: seconda fonte di download** (CDN jsDelivr) quando GitHub è
  bloccato dalla rete del negozio.
- **Launcher: copia di riserva sulla chiavetta** dopo ogni download riuscito,
  così la modalità offline resta aggiornata da sola.
- **Launcher: nome file temporaneo unico e 3 tentativi**, per non fallire con
  "Access is denied".
- **Versione sempre visibile nella barra del titolo** della finestra: resta a
  video in qualsiasi schermata, a differenza dell'header che scorre via.
- Flag `-skipRestore` per saltare il punto di ripristino, con timeout di 90 s e
  fallimento non bloccante.

### Modificato
- **Pulizia (debloat + rimozione antivirus di prova) spostata prima della
  lingua**: un antivirus di prova attivo bloccava i passaggi successivi.
- **Lingua**: il pacchetto viene installato se il *display* non è italiano, non
  solo se manca; il forzamento si applica anche a PC già "italiani"; timeout
  alzato a 12 minuti con messaggio d'errore più chiaro; retry di rete.
- **Riavvio sempre chiesto** alla fine, con spiegazione del perché serve.
- Debloat: copertura ASUS più ampia (MyASUS e simili).
- Credenziali: convenzione del negozio, email cognome+nome, provider corretto,
  un solo file, assist copia-incolla sulle pagine web.

## [9.x] — semplificazione del flusso

### Modificato
- **Flusso super semplice**: avvio diretto senza menu, solo 5 domande
  essenziali (nome cliente, account, Office, profilo app, antivirus). Le
  modalità Diagnostica e Test restano disponibili solo da riga di comando.
- **Aggiornamenti unificati**: un solo "sì" copre app e sicurezza di Windows.
- **Ripresa della sessione anche dentro il passo App**: ricorda il profilo
  scelto e riparte esattamente dall'app dove si era interrotto.

### Aggiunto
- Aggiornamenti di sicurezza di Windows nel passo update.
- Debloat della barra di Windows 11 (Widget, Chat, Vista attività, Ricerca).
- AIMP nel profilo BASE.

## [Infrastruttura del repository]

### Aggiunto
- Licenza MIT (`LICENSE.md`).
- `SECURITY.md`: distribuzione, integrità, gestione dei dati sensibili.
- Privilegio minimo (`contents: read`) per il token della CI.
- Template GitHub per bug report, feature request e pull request.
- Runbook di rilascio manuale in `docs/RELEASE.md`.
- Test Pester sulle funzioni pure e workflow `ci.yml` (sintassi,
  PSScriptAnalyzer, Pester, verifica SHA256).
- Workflow `test.yml` con smoke test end-to-end su Windows **e** Mac.

### Corretto
- CI: registrazione di PSGallery quando manca sul runner, con retry — evitava
  fallimenti casuali indipendenti dal codice.

### Da automatizzare quando il permesso `workflow` sarà attivo
- Generazione del changelog da commit/PR.
- Release GitHub con artifact `setup-pc.ps1`, `setup-pc.ps1.sha256` e launcher.
