# =====================================================================
#  build.ps1 - crea "Mia-Prima-Estensione.ext" dai file sorgente.
#
#  Un .ext e' semplicemente uno ZIP con extension.xml ALLA RADICE.
#  Questo script comprime extension.xml + la cartella scripts/ e rinomina
#  il risultato in .ext.
#
#  Uso:  tasto destro -> "Esegui con PowerShell"
#        oppure:  powershell -ExecutionPolicy Bypass -File .\build.ps1
# =====================================================================
$ErrorActionPreference = "Stop"

$src  = $PSScriptRoot
$name = "Mia-Prima-Estensione"
$zip  = Join-Path $src "$name.zip"
$ext  = Join-Path $src "$name.ext"

if (Test-Path $zip) { Remove-Item $zip }
if (Test-Path $ext) { Remove-Item $ext }

# Comprime SOLO i file dell'estensione (niente README/build.ps1 dentro il pacchetto).
$items = @(
	(Join-Path $src "extension.xml"),
	(Join-Path $src "scripts")
)
Compress-Archive -Path $items -DestinationPath $zip
Rename-Item -Path $zip -NewName "$name.ext"

Write-Host ""
Write-Host "Creato: $ext" -ForegroundColor Green
Write-Host "Copialo nella cartella:  %APPDATA%\SmileyMouth\Fantasy Grounds\extensions" -ForegroundColor Cyan
