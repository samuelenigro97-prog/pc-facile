# =============================================================================
# Test Pester per setup-pc.ps1
# -----------------------------------------------------------------------------
# Il flusso operativo non viene dot-sourcato: le funzioni pure sono importate
# dal modulo core, mentre la sorgente principale viene validata tramite AST.
# =============================================================================

BeforeAll {
    $script:SetupPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup-pc.ps1'
    if (-not (Test-Path $script:SetupPath)) { throw "setup-pc.ps1 non trovato: $script:SetupPath" }

    $script:CorePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'src\PcFacile.Core.psm1'
    Import-Module $script:CorePath -Force
}

AfterAll {
    Remove-Module PcFacile.Core -Force -ErrorAction SilentlyContinue
}

Describe 'setup-pc.ps1: la sorgente e'' sintatticamente valida' {
    It 'non ha errori di parsing' {
        $errs = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:SetupPath, [ref]$null, [ref]$errs) | Out-Null
        @($errs).Count | Should -Be 0
    }
}

Describe 'New-PasswordCliente' {
    It 'costruisce Nome + 123! con iniziale maiuscola' {
        New-PasswordCliente -Base 'Rossi' | Should -BeExactly 'Rossi123!'
    }
    It 'toglie spazi e caratteri non alfabetici' {
        New-PasswordCliente -Base 'de luca' | Should -BeExactly 'Deluca123!'
    }
    It 'usa "Cliente" se il nome e'' vuoto' {
        New-PasswordCliente -Base '' | Should -BeExactly 'Cliente123!'
    }
    It 'soddisfa i requisiti Microsoft (maiuscola, minuscola, cifra, simbolo)' {
        $pw = New-PasswordCliente -Base 'Bianchi'
        $pw | Should -Match '[A-Z]'
        $pw | Should -Match '[a-z]'
        $pw | Should -Match '[0-9]'
        $pw | Should -Match '[^A-Za-z0-9]'
    }
}

Describe 'New-EmailCliente' {
    It 'genera un indirizzo @outlook.com' {
        New-EmailCliente -Base 'Rossi' | Should -Match '@outlook\.com$'
    }
    It 'e'' tutto minuscolo e senza caratteri strani' {
        $mail = New-EmailCliente -Base 'De Luca!'
        ($mail -split '@')[0] | Should -Match '^[a-z0-9]+$'
    }
    It 'usa "cliente" se il nome e'' vuoto' {
        New-EmailCliente -Base '' | Should -Match '^cliente[0-9]+@outlook\.com$'
    }
}

Describe 'Test-NomeSimile' {
    It 'riconosce nomi che si contengono (a meno di spazi/punteggiatura)' {
        Test-NomeSimile 'Adobe Acrobat Reader' 'Adobe Acrobat' | Should -BeTrue
        Test-NomeSimile '7-Zip' '7-Zip File Manager'            | Should -BeTrue
        Test-NomeSimile 'VLC Media Player' 'VLC media player'   | Should -BeTrue
    }
    It 'distingue nomi diversi' {
        Test-NomeSimile 'Chrome' 'Firefox' | Should -BeFalse
    }
    It 'e'' falso se uno dei due e'' vuoto' {
        Test-NomeSimile '' 'Chrome' | Should -BeFalse
    }
}

Describe 'Test-LnkJunk' {
    It 'segnala i collegamenti spazzatura' {
        Test-LnkJunk 'Uninstall VLC'      | Should -BeTrue
        Test-LnkJunk 'Guida di 7-Zip'     | Should -BeTrue
        Test-LnkJunk 'Website'            | Should -BeTrue
    }
    It 'lascia passare le app vere' {
        Test-LnkJunk 'VLC media player'   | Should -BeFalse
        Test-LnkJunk 'Google Chrome'      | Should -BeFalse
    }
}

Describe 'Test-Indietro' {
    It 'riconosce B/b (anche con spazi) come "indietro"' {
        Test-Indietro 'b'   | Should -BeTrue
        Test-Indietro ' B ' | Should -BeTrue
    }
    It 'non scatta su altri valori' {
        Test-Indietro '3' | Should -BeFalse
        Test-Indietro 'S' | Should -BeFalse
    }
}

Describe 'Modalita non mutanti' {
    It 'calcola RunReale dopo la scelta iniziale e non personalizza il registro console' {
        $sorgente = Get-Content $script:SetupPath -Raw
        $inizializzazione = $sorgente.IndexOf('$RunReale = (-not $Test -and -not $Diagnostica)')
        $sceltaTest = $sorgente.IndexOf('$Test = $true')
        $inizializzazione | Should -BeGreaterThan -1
        $inizializzazione | Should -BeGreaterThan $sceltaTest
        $sorgente | Should -Not -Match "Set-ItemProperty -Path 'HKCU:\\Console'"
    }
}

Describe 'Rilevamento GPU' {
    It 'riconosce NVIDIA' {
        Mock Get-CimInstance -ModuleName PcFacile.Core { @([pscustomobject]@{ Name = 'NVIDIA GeForce RTX 4060' }) }
        Test-GpuNvidia | Should -BeTrue
        Get-GpuDedicata | Should -BeExactly 'NVIDIA'
    }

    It 'non considera dedicata una grafica Intel integrata' {
        Mock Get-CimInstance -ModuleName PcFacile.Core { @([pscustomobject]@{ Name = 'Intel UHD Graphics' }) }
        Test-GpuNvidia | Should -BeFalse
        Get-GpuDedicata | Should -BeNullOrEmpty
    }

    It 'riconosce AMD Radeon RX dedicata' {
        Mock Get-CimInstance -ModuleName PcFacile.Core { @([pscustomobject]@{ Name = 'AMD Radeon RX 7800 XT' }) }
        Get-GpuDedicata | Should -BeExactly 'AMD'
    }
}
