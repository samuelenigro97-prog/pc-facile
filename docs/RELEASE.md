# Release manuale — PC Facile

In attesa di poter automatizzare via GitHub Actions, usa questa checklist.

## Artifact da pubblicare
- `setup-pc.ps1`
- `setup-pc.ps1.sha256`
- `PC Facile.bat`
- opzionale: report test Pester in artifact

## Checklist
1. Esegui `Invoke-Pester ./tests` e PSScriptAnalyzer.
2. Se `setup-pc.ps1` è cambiato, rigenera l'hash:
   `(Get-FileHash ./setup-pc.ps1 -Algorithm SHA256).Hash.ToLower() | Set-Content ./setup-pc.ps1.sha256`
3. Verifica che `PC Facile.bat` scarichi la versione attesa e che l'hash combaci.
4. Crea tag semver, es. `v9.5.0`.
5. Crea la GitHub Release dal tag e carica gli artifact sopra.
6. Nel corpo release copia la sezione corrispondente da `CHANGELOG.md`.

## Da automatizzare
Quando il token/integrazione avrà scope `workflow`, creare `.github/workflows/release.yml` con trigger su tag `v*`, test, build artifact e `softprops/action-gh-release` o equivalente.
