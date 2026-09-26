# =============================================================================
# tools/aggiorna-manifest.ps1 - rigenera manifest.txt e le impronte .sha256
# -----------------------------------------------------------------------------
# Da eseguire (dalla radice del repository o da qualunque cartella) DOPO aver
# modificato uno dei file distribuiti sulla chiavetta:
#     pwsh ./tools/aggiorna-manifest.ps1      (oppure powershell -File ...)
# Aggiorna setup-pc.ps1.sha256, setup-mac.sh.sha256 e manifest.txt (hash
# minuscoli, fine riga LF). I test Pester falliscono se non sono allineati.
# I file Wi-Fi NON vanno mai nel manifest (restano solo sulla chiavetta).
# =============================================================================
$ErrorActionPreference = 'Stop'
$radice = Split-Path $PSScriptRoot -Parent

# File che servono sulla chiavetta (Windows + Mac), nell'ordine di download.
$fileKit = @(
    'setup-pc.ps1',
    'setup-pc.ps1.sha256',
    'PC Facile.bat',
    'PC Facile.command',
    'setup-mac.sh',
    'setup-mac.sh.sha256',
    'LEGGIMI.md'
)

function Get-Sha256Minuscolo([string]$Percorso) {
    return (Get-FileHash -LiteralPath $Percorso -Algorithm SHA256).Hash.ToLower()
}
function Write-TestoLF([string]$Percorso, [string]$Testo) {
    [System.IO.File]::WriteAllText($Percorso, ($Testo -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# 1) Impronte singole (usate da PC Facile.bat / PC Facile.command).
foreach ($script in @('setup-pc.ps1', 'setup-mac.sh')) {
    Write-TestoLF (Join-Path $radice "$script.sha256") ((Get-Sha256Minuscolo (Join-Path $radice $script)) + "`n")
}

# 2) Manifest (formato sha256sum: <hash><2 spazi><percorso>).
$righe = @(
    '# manifest.txt - file della chiavetta PC Facile con il loro SHA256.',
    '# Generato da tools/aggiorna-manifest.ps1: NON modificare a mano.',
    '# I file Wi-Fi (wifi/) non sono mai inclusi: restano solo sulla chiavetta.'
)
foreach ($f in $fileKit) {
    $p = Join-Path $radice $f
    if (-not (Test-Path -LiteralPath $p)) { throw "File del kit mancante: $f" }
    if ($f -match '^(?i)wifi[/\\]') { throw "I file Wi-Fi non possono stare nel manifest: $f" }
    $righe += ('{0}  {1}' -f (Get-Sha256Minuscolo $p), ($f -replace '\\', '/'))
}
Write-TestoLF (Join-Path $radice 'manifest.txt') (($righe -join "`n") + "`n")
Write-Host "manifest.txt aggiornato ($($fileKit.Count) file)."
