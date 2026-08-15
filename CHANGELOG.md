# Changelog

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/).

## [Unreleased]

### Rimosso
- Creazione automatica dei punti di recupero del sistema su Windows e degli equivalenti locali su macOS, incluse opzioni, messaggi e report dedicati.
- Gestione FileVault nello script macOS, inclusi attivazione, rigenerazione della chiave, diagnostica e sezioni del report.

### Aggiunto
- Dopo la creazione dell'account Microsoft, richiesta esplicita per disattivare BitLocker, avviare la decifratura e impedirne la riattivazione automatica.
- Licenza MIT (`LICENSE.md`).
- Template GitHub per bug report, feature request e pull request.
- Runbook release manuale in `docs/RELEASE.md`.

### Da automatizzare quando il permesso `workflow` sarà attivo
- Generazione changelog da commit/PR.
- Release GitHub con artifact `setup-pc.ps1`, `setup-pc.ps1.sha256` e launcher.
