# =============================================================================
# Test Pester per setup-pc.ps1
# -----------------------------------------------------------------------------
# setup-pc.ps1 e' un unico file che "gira" dall'alto in basso (menu, controlli
# admin, installazioni): NON si puo' dot-sourcare per intero senza eseguirlo.
# Per testare le funzioni PURE senza effetti collaterali, le ESTRAGGO dal file
# con il parser di PowerShell (AST) e le definisco a scope GLOBALE, cosi' sono
# visibili in tutti i blocchi It (in Pester v5 lo scope conta). Restano sempre
# allineate alla vera sorgente, senza duplicare codice.
# =============================================================================

BeforeAll {
    $script:SetupPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup-pc.ps1'
    $script:CorePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/PcFacile.Core.ps1'
    if (-not (Test-Path $script:SetupPath)) { throw "setup-pc.ps1 non trovato: $script:SetupPath" }
    if (-not (Test-Path $script:CorePath)) { throw "PcFacile.Core.ps1 non trovato: $script:CorePath" }

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:CorePath, [ref]$null, [ref]$null)

    $script:FunzioniTestate = @(
        'New-PasswordCliente', 'New-EmailCliente',
        'Test-NomeSimile', 'Test-LnkJunk', 'Test-Indietro'
    )
    foreach ($nome in $script:FunzioniTestate) {
        $fn = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nome
        }, $true) | Select-Object -First 1
        if (-not $fn) { throw "Funzione '$nome' non trovata in setup-pc.ps1" }
        # Definisco la funzione a scope globale: cosi' e' visibile in ogni It.
        Set-Item -Path "function:global:$nome" -Value $fn.Body.GetScriptBlock()
    }
}

AfterAll {
    foreach ($nome in $script:FunzioniTestate) {
        Remove-Item -Path "function:global:$nome" -ErrorAction SilentlyContinue
    }
}

Describe 'setup-pc.ps1: la sorgente e'' sintatticamente valida' {
    It 'non ha errori di parsing' {
        $errs = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:SetupPath, [ref]$null, [ref]$errs) | Out-Null
        @($errs).Count | Should -Be 0
    }
    It 'non ha errori di parsing nel modulo core' {
        $errs = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:CorePath, [ref]$null, [ref]$errs) | Out-Null
        @($errs).Count | Should -Be 0
    }
}

Describe 'New-PasswordCliente' {
    It 'genera password casuali di 16 caratteri senza il nome cliente' {
        $prima = New-PasswordCliente -Base 'Rossi'
        $seconda = New-PasswordCliente -Base 'Rossi'
        $prima.Length | Should -Be 16
        $prima | Should -Not -Match 'Rossi'
        $prima | Should -Not -BeExactly $seconda
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
