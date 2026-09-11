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

- **Integrità**: `PC Facile.bat` verifica lo **SHA256** dello script scaricato contro `setup-pc.ps1.sha256`; se non combacia, scarta il download e usa la copia locale.
- **Test**: `tests/PcFacile.Tests.ps1` (Pester) verifica le funzioni pure. Esegui in locale con `Invoke-Pester ./tests`.
- **CI**: `.github/workflows/ci.yml` gira su ogni push/PR (Windows) — controllo sintassi, PSScriptAnalyzer, Pester e verifica dell'hash.
- **Dopo aver modificato `setup-pc.ps1`** va rigenerato l'hash:
  `(Get-FileHash ./setup-pc.ps1 -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-pc.ps1.sha256` (la CI fallisce se è disallineato).
- **Sicurezza**: distribuzione, integrità e dati sensibili sono descritti in **[SECURITY.md](./SECURITY.md)**.
