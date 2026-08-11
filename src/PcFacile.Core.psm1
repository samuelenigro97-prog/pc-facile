function New-PasswordCliente {
    param([string]$Base)
    $b = ($Base -replace '[^A-Za-z]', '')
    if ($b.Length -lt 1) { $b = 'Cliente' }
    $b = $b.Substring(0, 1).ToUpper() + $b.Substring(1).ToLower()
    return "${b}123!"
}

function New-EmailCliente {
    param([string]$Base)
    $e = ($Base -replace '[^A-Za-z0-9]', '').ToLower()
    if (-not $e) { $e = 'cliente' }
    if ($e.Length -gt 15) { $e = $e.Substring(0, 15) }
    return "$e$(Get-Random -Minimum 10 -Maximum 999)@outlook.com"
}

function Test-GpuNvidia {
    try {
        return @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'NVIDIA|GeForce|RTX|GTX' }).Count -gt 0
    } catch { return $false }
}

function Get-GpuDedicata {
    try {
        $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name })
        if ($gpu.Count -eq 0) { return $null }
        if ($gpu | Where-Object { $_.Name -match 'NVIDIA|GeForce|RTX|GTX' }) { return 'NVIDIA' }
        $amdDed = $gpu | Where-Object { $_.Name -match 'Radeon\s*(RX|Pro)|Radeon\s*R[579]|FirePro' }
        $amdQualsiasi = $gpu | Where-Object { $_.Name -match 'AMD|Radeon' }
        $nonAmd = $gpu | Where-Object { $_.Name -notmatch 'AMD|Radeon' }
        if ($amdDed -or ($amdQualsiasi -and $nonAmd)) { return 'AMD' }
        if ($gpu | Where-Object { $_.Name -match 'Intel.*Arc|Arc\s*A\d' }) { return 'INTEL' }
        return $null
    } catch { return $null }
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

Export-ModuleMember -Function New-PasswordCliente, New-EmailCliente, Test-GpuNvidia,
    Get-GpuDedicata, Test-NomeSimile, Test-LnkJunk, Test-Indietro
