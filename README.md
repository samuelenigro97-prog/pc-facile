# PC Facile

[![Licenza MIT](https://img.shields.io/github/license/samuelenigro97-prog/pc-facile)](LICENSE.md)
[![CI](https://github.com/samuelenigro97-prog/pc-facile/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/samuelenigro97-prog/pc-facile/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/samuelenigro97-prog/pc-facile?display_name=tag&sort=semver)](https://github.com/samuelenigro97-prog/pc-facile/releases)

Script PowerShell (`setup-pc.ps1`) per configurare i PC Windows dei clienti: lingua italiana, nome cliente, Office, antivirus, browser e app base, con report finale degli esiti.

Per le istruzioni complete (download, avvio, risoluzione problemi) vedi **[LEGGIMI.md](./LEGGIMI.md)**.

## Avvio rapido

1. **Web App Operatore (Online)**:
   Apri il **[Pannello Web PC Facile](https://samuelenigro97-prog.github.io/pc-facile/)** per preparare le credenziali, monitorare l'avanzamento o accedere ai portali di attivazione a 1-click.
2. **Sul PC da configurare**:
   Scarica **`PC Facile.bat`** (anche con il tasto di download diretto dentro la Web App) ed eseguilo come amministratore per far partire la configurazione automatica.

## Sviluppo / qualità

- **Integrità**: `PC Facile.bat` verifica lo **SHA256** dello script scaricato contro `setup-pc.ps1.sha256`. Se l'impronta non combacia **o non si riesce a scaricarla**, il download viene scartato (riprova anche dal mirror jsDelivr) e, se nessun download è verificato, si usa la copia sulla chiavetta; la copia sulla chiavetta viene aggiornata solo dopo una verifica riuscita. Su Mac `PC Facile.command` fa lo stesso con `setup-mac.sh.sha256`.
- **Chiavetta auto-aggiornata**: `manifest.txt` elenca i file che servono sulla chiavetta con il loro SHA256; a ogni avvio `PC Facile.bat` / `PC Facile.command` li scarica, li verifica e solo allora sostituisce le copie (compresi `wifi/wifi.txt` e `wifi/UNIEURO_EXPO.xml`; gli altri file di `wifi` non vengono toccati). **Dopo aver modificato uno di questi file** esegui `pwsh ./tools/aggiorna-manifest.ps1` (rigenera `manifest.txt` e le impronte `.sha256`; i test Pester falliscono se sono disallineati).
- **Test**: `tests/PcFacile.Tests.ps1` (Pester) verifica le funzioni pure. Esegui in locale con `Invoke-Pester ./tests`.
- **CI**: `.github/workflows/ci.yml` gira su ogni push/PR (Windows) — controllo sintassi, PSScriptAnalyzer, Pester e verifica dell'hash.
- **Dopo aver modificato `setup-pc.ps1`** va rigenerato l'hash:
  `(Get-FileHash ./setup-pc.ps1 -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-pc.ps1.sha256` (la CI fallisce se è disallineato).
- **Dopo aver modificato `setup-mac.sh`** rigenera `setup-mac.sh.sha256` allo stesso modo:
  `(Get-FileHash ./setup-mac.sh -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-mac.sh.sha256` (oppure `shasum -a 256 setup-mac.sh | cut -d' ' -f1 > setup-mac.sh.sha256`; verificato dai test Pester).
- **Sicurezza**: distribuzione, integrità e dati sensibili sono descritti in **[SECURITY.md](./SECURITY.md)**.
