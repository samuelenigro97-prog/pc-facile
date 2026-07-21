# =============================================================================
# Test Pester per setup-pc.ps1
# -----------------------------------------------------------------------------
# setup-pc.ps1 e' un unico file che "gira" dall'alto in basso (menu, controlli
# admin, installazioni): NON si puo' dot-sourcare per intero senza eseguirlo.
# Per testare le funzioni PURE senza effetti collaterali, le ESTRAGGO dal file
# con il parser di PowerShell (AST) e carico in sessione solo quelle. Cosi' i
# test restano sempre allineati alla vera sorgente, senza duplicare codice.
# =============================================================================

BeforeAll {
    $script:SetupPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup-pc.ps1'
    if (-not (Test-Path $script:SetupPath)) { throw "setup-pc.ps1 non trovato: $script:SetupPath" }

    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:SetupPath, [ref]$tokens, [ref]$errors)

    # Carica in sessione SOLO le funzioni indicate (per nome), prese dall'AST.
    function Import-FunzioniDaSetup {
        param([string[]]$Nomi)
        foreach ($nome in $Nomi) {
            $fn = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nome
            }, $true) | Select-Object -First 1
            if (-not $fn) { throw "Funzione '$nome' non trovata in setup-pc.ps1" }
            . ([ScriptBlock]::Create($fn.Extent.Text))
        }
    }

    Import-FunzioniDaSetup -Nomi @(
        'New-PasswordCliente', 'New-EmailCliente',
        'Test-NomeSimile', 'Test-LnkJunk', 'Test-Indietro'
    )
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
