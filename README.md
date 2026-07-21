# PC Facile

Script PowerShell (`setup-pc.ps1`) per configurare i PC Windows dei clienti: lingua italiana, nome cliente, Office, antivirus, browser e app base, con report finale degli esiti.

Per le istruzioni complete (download, avvio, risoluzione problemi) vedi **[LEGGIMI.md](./LEGGIMI.md)**.

## Avvio rapido

1. Scarica `PC Facile.bat`
2. Doppio click → chiede i privilegi di amministratore → scarica ed esegue l'ultima versione dello script

Tutti i dettagli, i comandi alternativi da PowerShell e la compatibilità Windows 10/11 sono in [LEGGIMI.md](./LEGGIMI.md).

## Sviluppo / qualità

- **Integrità**: `PC Facile.bat` verifica lo **SHA256** dello script scaricato contro `setup-pc.ps1.sha256`; se non combacia, scarta il download e usa la copia locale.
- **Test**: `tests/PcFacile.Tests.ps1` (Pester) verifica le funzioni pure. Esegui in locale con `Invoke-Pester ./tests`.
- **CI**: `.github/workflows/ci.yml` gira su ogni push/PR (Windows) — controllo sintassi, PSScriptAnalyzer, Pester e verifica dell'hash.
- **Dopo aver modificato `setup-pc.ps1`** va rigenerato l'hash:
  `(Get-FileHash ./setup-pc.ps1 -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-pc.ps1.sha256` (la CI fallisce se è disallineato).
