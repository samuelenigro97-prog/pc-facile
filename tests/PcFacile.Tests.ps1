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
    if (-not (Test-Path $script:SetupPath)) { throw "setup-pc.ps1 non trovato: $script:SetupPath" }

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:SetupPath, [ref]$null, [ref]$null)

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
}

Describe 'Disattivazione BitLocker dopo account Microsoft' {
    It 'e'' condizionata al provider Microsoft e richiede una risposta esplicita' {
        $sorgente = Get-Content $script:SetupPath -Raw
        $sorgente | Should -Match '\$prov\.Nome -eq "Microsoft"'
        $sorgente | Should -Match 'Attendi-Risposta "Disattivare BitLocker'
        $sorgente | Should -Match "-Name 'PreventDeviceEncryption'"
        $sorgente | Should -Match 'manage-bde\.exe -off \$Volume'
    }

    It 'salva la fase Account soltanto dopo la richiesta BitLocker' {
        $sorgente = Get-Content $script:SetupPath -Raw
        $richiesta = $sorgente.IndexOf('$vuoiDisattivareBitLocker = Attendi-Risposta')
        $salvataggio = $sorgente.IndexOf('Save-Fase 2 "Account/email cliente"')
        $richiesta | Should -BeGreaterThan -1
        $salvataggio | Should -BeGreaterThan $richiesta
    }
}

Describe 'Interfaccia minimale e test su macOS' {
    It 'applica il registro console soltanto su Windows' {
        $sorgente = Get-Content $script:SetupPath -Raw
        $sorgente | Should -Match '\$SuWindows = \(\$env:OS -eq ''Windows_NT''\)'
        $sorgente | Should -Match 'if \(\$SuWindows\) \{\s+try \{\s+if \(-not \(Test-Path ''HKCU:\\Console''\)\)'
    }

    It 'usa sfondo nero e un titolo compatto fuori da Windows' {
        $sorgente = Get-Content $script:SetupPath -Raw
        $sorgente | Should -Match 'if \(-not \$SuWindows -or \$env:WT_SESSION\)'
        $sorgente | Should -Match '\$barra = "=" \* 44'
        $sorgente | Should -Match 'TEST WINDOWS SU MACOS'
    }
}

Describe 'New-PasswordCliente' {
    It 'costruisce Nome + 123! con iniziale maiuscola' {
        New-PasswordCliente -Base 'Rossi' | Should -BeExactly 'Rossi123!'
    }
    It 'usa solo il PRIMO nome (prima parola)' {
        New-PasswordCliente -Base 'Mario Rossi' | Should -BeExactly 'Mario123!'
        New-PasswordCliente -Base 'de luca'     | Should -BeExactly 'De123!'
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
    It 'genera un indirizzo @outlook.it di default' {
        New-EmailCliente -Base 'Rossi' | Should -Match '@outlook\.it$'
    }
    It 'e'' COGNOME+NOME attaccato, minuscolo e SENZA numeri' {
        New-EmailCliente -Base 'Mario Rossi' | Should -BeExactly 'rossimario@outlook.it'
    }
    It 'toglie i caratteri strani dalla parte prima della chiocciola' {
        $mail = New-EmailCliente -Base 'De Luca!'
        ($mail -split '@')[0] | Should -Match '^[a-z0-9]+$'
    }
    It 'rispetta il dominio del provider scelto' {
        New-EmailCliente -Base 'Rossi' -Dominio 'gmail.com' | Should -BeExactly 'rossi@gmail.com'
    }
    It 'usa "cliente" se il nome e'' vuoto' {
        New-EmailCliente -Base '' | Should -BeExactly 'cliente@outlook.it'
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
