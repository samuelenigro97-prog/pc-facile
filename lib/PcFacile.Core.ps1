# Funzioni pure condivise dal wizard. Questo file non esegue operazioni sul PC.

function New-PasswordCliente {
    param([string]$Base)
    $gruppi = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%*-_')
    $caratteri = [System.Collections.Generic.List[char]]::new()
    foreach ($gruppo in $gruppi) {
        $caratteri.Add($gruppo[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($gruppo.Length)])
    }
    $tutti = $gruppi -join ''
    while ($caratteri.Count -lt 16) {
        $caratteri.Add($tutti[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($tutti.Length)])
    }
    return -join ($caratteri | Sort-Object { [System.Security.Cryptography.RandomNumberGenerator]::GetInt32([int]::MaxValue) })
}

function New-EmailCliente {
    param([string]$Base)
    $e = ($Base -replace '[^A-Za-z0-9]', '').ToLower()
    if (-not $e) { $e = 'cliente' }
    if ($e.Length -gt 15) { $e = $e.Substring(0, 15) }
    return "$e$(Get-Random -Minimum 10 -Maximum 999)@outlook.com"
}

function Test-NomeSimile {
    param([string]$A, [string]$B)
    $na = ($A -replace '[^A-Za-z0-9]', '').ToLower()
    $nb = ($B -replace '[^A-Za-z0-9]', '').ToLower()
    if (-not $na -or -not $nb) { return $false }
    return ($na.Contains($nb) -or $nb.Contains($na))
}

function Test-LnkJunk {
    param([string]$Base)
    $junk = @('*uninstall*', '*disinstall*', '*guida*', '*help*', '*read*me*', '*leggimi*',
              '*documentation*', '*website*', '*sito*', '*modify*', '*repair*', '*support*',
              '*aggiorna*', '*update*')
    foreach ($p in $junk) { if ($Base -like $p) { return $true } }
    return $false
}

function Test-Indietro {
    param([string]$v)
    return ($v -match '^\s*[Bb]\s*$')
}
