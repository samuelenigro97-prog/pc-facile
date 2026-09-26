# Changelog

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/).

## [Unreleased]

### Corretto
- `PC Facile.bat`: se `setup-pc.ps1.sha256` non si scarica il download viene
  scartato (prima veniva eseguito senza verifica); la copia sulla chiavetta si
  aggiorna solo dopo una verifica riuscita.
- `PC Facile.bat`: argomenti utente ricostruiti correttamente dopo l'elevazione
  (il marcatore interno `elevated` non arriva più allo script); controllo
  Internet via HTTP con fallback invece del solo ping a 8.8.8.8.
- `PC Facile.bat` salvato con fine riga CRLF anche nel repository
  (`.gitattributes`: `*.bat -text`), così GitHub raw serve un .bat valido.
- Connessione Wi-Fi da `wifi.txt`/`wifi.ini`/`wifi.conf` in `setup-pc.ps1`
  (array di `Join-Path` errato: falliva sempre in silenzio).
- Pannello operatore (web e locale): la sincronizzazione automatica non
  partiva (`telefono` non definito); pulsante "Scarica PC Facile.bat" ora
  scarica davvero il file; comando Win+R corretto e sotto il limite della
  finestra Esegui.
- Escape HTML/XML/sed dei valori inseriti nel pannello, nella scheda di
  consegna Mac e nei profili Wi-Fi.
- Pulizia: file credenziali `pcfacile-cred*.json` e pannelli temporanei con la
  password cancellati; impostazioni della console (colori/font) ripristinate
  dal backup originale a fine lavoro.
- `setup-mac.sh`: rimosso `eval` sui dati letti dal pannello.
- `PC Facile.command`: file temporaneo con `mktemp` e verifica SHA256 tramite
  il nuovo `setup-mac.sh.sha256` (controllato dai test Pester in CI).

### Aggiunto
- Licenza MIT (`LICENSE.md`).
- Template GitHub per bug report, feature request e pull request.
- Runbook release manuale in `docs/RELEASE.md`.

### Da automatizzare quando il permesso `workflow` sarà attivo
- Generazione changelog da commit/PR.
- Release GitHub con artifact `setup-pc.ps1`, `setup-pc.ps1.sha256` e launcher.
