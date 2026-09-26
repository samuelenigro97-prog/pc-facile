# =============================================================================
# tools/sincronizza-pannello.ps1 - copia docs/index.html dentro setup-pc.ps1
# -----------------------------------------------------------------------------
# Il pannello operatore esiste in due copie:
#   - docs/index.html  : pubblicato su GitHub Pages (la sorgente da modificare)
#   - setup-pc.ps1     : here-string $html = @"..."@ in Open-PannelloOperatore,
#                        scritto in TEMP e aperto dallo script (file locale)
# Dopo ogni modifica a docs/index.html eseguire:
#     pwsh ./tools/sincronizza-pannello.ps1
#     pwsh ./tools/aggiorna-manifest.ps1      (setup-pc.ps1 cambia hash)
# Con -SoloVerifica non scrive nulla e restituisce $true se le due copie sono
# allineate (lo usa il test Pester, cosi' non possono divergere).
# Differenze ammesse: solo i 3 valori precompilati dallo script (nome, email,
# password del cliente), che in docs/index.html sono vuoti.
# =============================================================================
param([switch]$SoloVerifica)
$ErrorActionPreference = 'Stop'
$radice = Split-Path $PSScriptRoot -Parent
$percorsoDocs = Join-Path $radice 'docs/index.html'
$percorsoScript = Join-Path $radice 'setup-pc.ps1'

$sostituzioni = [ordered]@{
    'id="inNome" class="cred-input" value=""'           = 'id="inNome" class="cred-input" value="$hNome"'
    'id="inEmail" class="cred-input cred-mono" value=""' = 'id="inEmail" class="cred-input cred-mono" value="$hEmail"'
    'id="inPass" class="cred-input cred-mono" value=""'  = 'id="inPass" class="cred-input cred-mono" value="$hPassword"'
}

$docs = [System.IO.File]::ReadAllText($percorsoDocs).Replace("`r`n", "`n").TrimEnd("`n")
# Here-string espandibile: backtick e $ vanno protetti con un backtick.
$incorporato = $docs.Replace('`', '``').Replace('$', '`$')
foreach ($k in $sostituzioni.Keys) {
    if (-not $incorporato.Contains($k)) { throw "Segnaposto non trovato in docs/index.html: $k" }
    $incorporato = $incorporato.Replace($k, $sostituzioni[$k])
}
if ($incorporato -match '(?m)^"@') { throw 'docs/index.html contiene una riga che inizia con "@ (chiuderebbe la here-string)' }

$script = [System.IO.File]::ReadAllText($percorsoScript)
$apertura = "        `$html = @`"`n"
$inizio = $script.IndexOf($apertura)
if ($inizio -lt 0) { throw 'Inizio del pannello incorporato non trovato in setup-pc.ps1' }
$inizio += $apertura.Length
$fine = $script.IndexOf("`n`"@", $inizio)
if ($fine -lt 0) { throw 'Fine del pannello incorporato non trovata in setup-pc.ps1' }
$attuale = $script.Substring($inizio, $fine - $inizio)

if ($SoloVerifica) { return ($attuale -ceq $incorporato) }
if ($attuale -ceq $incorporato) { Write-Host 'Pannello incorporato gia'' allineato.'; return }
$nuovo = $script.Substring(0, $inizio) + $incorporato + $script.Substring($fine)
[System.IO.File]::WriteAllText($percorsoScript, $nuovo, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'Pannello incorporato in setup-pc.ps1 aggiornato da docs/index.html.'
