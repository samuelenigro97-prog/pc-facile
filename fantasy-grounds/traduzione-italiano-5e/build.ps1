# =====================================================================
#  build.ps1 - crea "Traduzione-Italiano-5E.ext" dai file sorgente.
#
#  Un .ext e' uno ZIP con extension.xml ALLA RADICE.
#  Questo script comprime extension.xml + la cartella strings/.
#
#  Uso:  tasto destro -> "Esegui con PowerShell"
#        oppure:  powershell -ExecutionPolicy Bypass -File .\build.ps1
# =====================================================================
$ErrorActionPreference = "Stop"

$src  = $PSScriptRoot
$name = "Traduzione-Italiano-5E"
$zip  = Join-Path $src "$name.zip"
$ext  = Join-Path $src "$name.ext"

if (Test-Path $zip) { Remove-Item $zip }
if (Test-Path $ext) { Remove-Item $ext }

$items = @(
	(Join-Path $src "extension.xml"),
	(Join-Path $src "strings")
)
Compress-Archive -Path $items -DestinationPath $zip
Rename-Item -Path $zip -NewName "$name.ext"

Write-Host ""
Write-Host "Creato: $ext" -ForegroundColor Green
Write-Host "Copialo in:  %APPDATA%\SmileyMouth\Fantasy Grounds\extensions" -ForegroundColor Cyan
