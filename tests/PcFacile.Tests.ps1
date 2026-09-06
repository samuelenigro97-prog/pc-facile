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
        'Write-Titolo', 'Write-OK', 'Write-Info', 'Write-Errore', 'Add-Report',
        'New-PasswordCliente', 'New-EmailCliente',
        'Test-NomeSimile', 'Test-LnkJunk', 'Test-Indietro',
        'Get-OfflineDirs', 'Find-OfflineInstaller', 'Install-OfflinePackage', 'Stop-AppPopups', 'Select-DestinazioneUSB', 'Test-IsAppInstalled',
        'Get-StorageHealthInfo', 'Get-BatteryHealthInfo', 'Get-WindowsActivationStatus', 'Get-BitLockerRecovery',
        'Get-SystemHardwareDetails', 'Invoke-PcFacileDiagnostics', 'Install-VisualCRuntime',
        'Update-PannelloStatus', 'Open-PannelloOperatore', 'Set-SplitScreenLayout', 'Get-CredenzialiSalvatePannello',
        'Start-LocalCredServer', 'Stop-LocalCredServer',
        'Enable-SilentElevation', 'Restore-SilentElevation', 'Set-PreventSleep', 'Set-EdgeFirstRunPolicies',
        'New-WlanProfileXml', 'Connect-AutoWiFi', 'Save-StoreWiFiProfile',
        'Invoke-BrowserAutoSignup', 'Wait-CredenzialiPannello',
        'Install-WindowsUpdateDrivers',
        'Convert-PngToIco', 'Get-AppxPackageIcon'
    )
    $allFns = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    $fnMap = @{}
    foreach ($f in $allFns) {
        if (-not $fnMap.ContainsKey($f.Name)) { $fnMap[$f.Name] = $f }
    }
    foreach ($nome in $script:FunzioniTestate) {
        $fn = $fnMap[$nome]
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

Describe 'New-PasswordCliente' {
    It 'costruisce Nome + 123! con iniziale maiuscola' {
        New-PasswordCliente -Base 'Rossi' | Should -BeExactly 'Rossi123!'
    }
    It 'usa solo il PRIMO nome (prima parola)' {
        New-PasswordCliente -Base 'Mario Rossi' | Should -BeExactly 'Mario123!'
        New-PasswordCliente -Base 'de luca'     | Should -BeExactly 'De123!'
    }
    It 'usa "Utente123!" se il nome e'' vuoto o OEM' {
        New-PasswordCliente -Base ''    | Should -BeExactly 'Utente123!'
        New-PasswordCliente -Base 'OEM' | Should -BeExactly 'Utente123!'
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
    It 'usa "utente" se il nome e'' vuoto o OEM' {
        New-EmailCliente -Base ''    | Should -BeExactly 'utente@outlook.it'
        New-EmailCliente -Base 'OEM' | Should -BeExactly 'utente@outlook.it'
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

Describe 'Get-OfflineDirs' {
    It 'restituisce array di percorsi esistenti validi' {
        $dirs = Get-OfflineDirs
        $dirs | Should -Not -BeNullOrEmpty
        foreach ($d in $dirs) {
            Test-Path $d | Should -BeTrue
        }
    }
}

Describe 'Find-OfflineInstaller' {
    BeforeAll {
        $script:tempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) "PcFacileTest_$(Get-Random)"
        $script:tempInstDir = Join-Path $script:tempTestDir "installers"
        New-Item -Path $script:tempInstDir -ItemType Directory -Force | Out-Null
        $Global:TargetDir = $script:tempTestDir

        $dummyBytes = [byte[]]::new(153600) # 150 KB
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "ChromeStandaloneSetup64.exe"), $dummyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "7z2408-x64.exe"), $dummyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "NRnR.exe"), $dummyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "MCPR.exe"), $dummyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "vc_redist.x64.exe"), $dummyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "vc_redist.x86.exe"), $dummyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "SpotifyFullSetup.exe"), $dummyBytes)
        
        # File corrotto/troppo piccolo (< 100 KB)
        [System.IO.File]::WriteAllBytes((Join-Path $script:tempInstDir "CorruptedApp_Setup.exe"), [byte[]]::new(512))
    }

    AfterAll {
        $Global:TargetDir = $null
        if (Test-Path $script:tempTestDir) {
            Remove-Item -Path $script:tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'trova Google Chrome per WingetId' {
        $found = Find-OfflineInstaller -WingetId 'Google.Chrome' -Nome 'Google Chrome'
        $found | Should -Not -BeNullOrEmpty
        $found | Should -Match 'ChromeStandaloneSetup64\.exe$'
    }

    It 'trova 7-Zip per Nome o WingetId' {
        $found = Find-OfflineInstaller -WingetId '7zip.7zip' -Nome '7-Zip'
        $found | Should -Not -BeNullOrEmpty
        $found | Should -Match '7z2408-x64\.exe$'
    }

    It 'trova Spotify per Nome o WingetId' {
        $found = Find-OfflineInstaller -WingetId 'Spotify.Spotify' -Nome 'Spotify'
        $found | Should -Not -BeNullOrEmpty
        $found | Should -Match 'SpotifyFullSetup\.exe$'
    }

    It 'trova i tool rimozione NRnR e MCPR' {
        $nrnr = Find-OfflineInstaller -Nome 'NRnR'
        $nrnr | Should -Not -BeNullOrEmpty
        $nrnr | Should -Match 'NRnR\.exe$'

        $mcpr = Find-OfflineInstaller -Nome 'MCPR'
        $mcpr | Should -Not -BeNullOrEmpty
        $mcpr | Should -Match 'MCPR\.exe$'
    }

    It 'trova i pacchetti Microsoft Visual C++ redistributable x64 e x86' {
        $vc64 = Find-OfflineInstaller -WingetId 'Microsoft.VCRedist.2015+.x64' -Nome 'Microsoft Visual C++ 2015-2022 (x64)'
        $vc64 | Should -Not -BeNullOrEmpty
        $vc64 | Should -Match 'vc_redist\.x64\.exe$'

        $vc86 = Find-OfflineInstaller -WingetId 'Microsoft.VCRedist.2015+.x86' -Nome 'Microsoft Visual C++ 2015-2022 (x86)'
        $vc86 | Should -Not -BeNullOrEmpty
        $vc86 | Should -Match 'vc_redist\.x86\.exe$'
    }

    It 'scarta file offline corrotti o vuoti (< 100 KB)' {
        $found = Find-OfflineInstaller -WingetId 'CorruptedApp' -Nome 'CorruptedApp'
        $found | Should -BeNullOrEmpty
    }

    It 'restituisce null se il pacchetto non esiste' {
        $found = Find-OfflineInstaller -WingetId 'NonEsistente.App' -Nome 'AppFantasma'
        $found | Should -BeNullOrEmpty
    }
}

Describe 'Install-OfflinePackage' {
    It 'completa con successo in modalita simulata/test' {
        $Global:Test = $true
        $res = Install-OfflinePackage -FilePath "/fake/path/SpotifyFullSetup.exe" -Nome "Spotify"
        $res | Should -BeTrue
        $Global:Test = $false
    }
}

Describe 'Stop-AppPopups' {
    It 'gestisce le chiamate senza errori in modalita test' {
        $Global:Test = $true
        { Stop-AppPopups -Nome "Spotify" } | Should -Not -Throw
        { Stop-AppPopups -Nome "Zoom" } | Should -Not -Throw
        { Stop-AppPopups -Nome "7-Zip" } | Should -Not -Throw
        $Global:Test = $false
    }
}

Describe 'Test-IsAppInstalled' {
    It 'ritorna false in modalita test' {
        $Global:Test = $true
        Test-IsAppInstalled -Nome "7-Zip" -WingetId "7zip.7zip" | Should -BeFalse
        $Global:Test = $false
    }
}

Describe 'Select-DestinazioneUSB' {
    It 'restituisce un percorso valido di default in modalita non interattiva' {
        $dest = Select-DestinazioneUSB -DefaultDir $PSScriptRoot -Test
        $dest | Should -Not -BeNullOrEmpty
        Test-Path $dest | Should -BeTrue
    }
}

Describe 'Get-StorageHealthInfo' {
    It 'restituisce un oggetto con campi validi e non nullo' {
        $info = Get-StorageHealthInfo
        $info | Should -Not -BeNullOrEmpty
        $info.Modello | Should -Not -BeNullOrEmpty
        $info.Salute | Should -Not -BeNullOrEmpty
        $info.StatoCompleto | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-BatteryHealthInfo' {
    It 'restituisce un oggetto con campi validi e stato batteria' {
        $batt = Get-BatteryHealthInfo
        $batt | Should -Not -BeNullOrEmpty
        $batt.Salute | Should -Not -BeNullOrEmpty
        $batt.PSObject.Properties['Presente'] | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-WindowsActivationStatus' {
    It 'restituisce un oggetto con stato licenza e messaggio' {
        $act = Get-WindowsActivationStatus
        $act | Should -Not -BeNullOrEmpty
        $act.StatoBreve | Should -Not -BeNullOrEmpty
        $act.Messaggio | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-SystemHardwareDetails' {
    It 'restituisce un oggetto hardware completo con garanzia legale di 2 anni' {
        $hw = Get-SystemHardwareDetails
        $hw | Should -Not -BeNullOrEmpty
        $hw.Produttore | Should -Not -BeNullOrEmpty
        $hw.Modello | Should -Not -BeNullOrEmpty
        $hw.Seriale | Should -Not -BeNullOrEmpty
        $hw.Cpu | Should -Not -BeNullOrEmpty
        $hw.RamGB | Should -BeGreaterThan 0
        $hw.Gpu | Should -Not -BeNullOrEmpty
        $hw.DataSetup | Should -Match '^\d{2}/\d{2}/\d{4}$'
        $hw.ScadenzaGaranzia | Should -Match '^\d{2}/\d{2}/\d{4}$'
        
        $annoSetup = [int]($hw.DataSetup.Split('/')[2])
        $annoGaranzia = [int]($hw.ScadenzaGaranzia.Split('/')[2])
        ($annoGaranzia - $annoSetup) | Should -Be 2
    }
}

Describe 'Install-VisualCRuntime' {
    It 'completa con successo in modalita simulata/test' {
        $Global:Report = [System.Collections.ArrayList]::new()
        $Global:Test = $true
        $res = Install-VisualCRuntime
        $res | Should -BeTrue
        $Global:Test = $false
    }
}

Describe 'Open-PannelloOperatore' {
    It 'genera correttamente il file Pannello-Operatore.html con tutti i provider e i portali' {
        $Global:Test = $true
        $testPannello = Join-Path ([System.IO.Path]::GetTempPath()) "Pannello-Operatore.html"
        Open-PannelloOperatore -NomeCliente "Mario Rossi" -Email "rossimario@outlook.it" -Password "Mario123!"
        Test-Path $testPannello | Should -BeTrue
        $content = Get-Content $testPannello -Raw
        $content | Should -Match "Pannello Assistenza"
        $content | Should -Match "UNIEURO"
        $content | Should -Match "rossimario@outlook\.it"
        $content | Should -Match "Mario123!"
        # Provider selectors
        $content | Should -Match "@outlook\.it"
        $content | Should -Match "@gmail\.com"
        $content | Should -Match "@proton\.me"
        $content | Should -Match "@libero\.it"
        # 1-Click Portali
        $content | Should -Match "account\.microsoft\.com"
        $content | Should -Match "accounts\.google\.com/signup"
        $content | Should -Match "account\.proton\.me/signup"
        $content | Should -Match "registrazione\.libero\.it"
        $content | Should -Match "microsoft365\.com/setup"
        $content | Should -Match "mcafee\.com/activate"
        $content | Should -Match "norton\.com/setup"
        $content | Should -Match "unieuro-cyber-protection\.covercare\.it"
        # Tabs rimosse (Checklist e Vista Completa)
        $content | Should -Not -Match "tab-checklist"
        $content | Should -Not -Match "tab-all"
        $content | Should -Not -Match "view-tab-checklist"
        $content | Should -Not -Match "view-tab-all"
    }
}

Describe 'Update-PannelloStatus' {
    It 'scrive lo stato live in formato js senza errori' {
        Update-PannelloStatus -TaskId "pulizia" -Stato "running" -Percentuale 15 -FaseCorrente "Pulizia Bloatware" -Dettaglio "Rimozione in corso..."
        $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
        $statusFile = Join-Path $tempDir "pcfacile-status.js"
        Test-Path $statusFile | Should -BeTrue
        $content = Get-Content $statusFile -Raw
        $content | Should -Match "window\.onPCFacileStatusUpdate"
        $content | Should -Match "pulizia"
        $content | Should -Match "running"
    }
}

Describe 'Get-CredenzialiSalvatePannello' {
    It 'legge correttamente il file json salvato dal pannello operatore' {
        $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
        $jsonFile = Join-Path $tempDir "pcfacile-cred.json"
        $testData = @{
            Email = "rossimario@gmail.com"
            Password = "Mario123!"
            Provider = "Google"
            Cliente = "Mario Rossi"
        } | ConvertTo-Json
        $testData | Set-Content -Path $jsonFile -Encoding UTF8
        
        $res = Get-CredenzialiSalvatePannello
        $res | Should -BeTrue
        $Global:credMsAccount | Should -Be "rossimario@gmail.com"
        $Global:credMsPassword | Should -Be "Mario123!"
        $Global:provNome | Should -Be "Google"
        
        Remove-Item $jsonFile -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Enable-SilentElevation & Restore-SilentElevation' {
    It 'esegue senza errori e gestisce le variabili di ambiente' {
        { Enable-SilentElevation } | Should -Not -Throw
        $env:SEE_MASK_NOZONECHECKS | Should -Be "1"
        { Restore-SilentElevation } | Should -Not -Throw
    }
}

Describe 'New-WlanProfileXml' {
    It 'genera un profilo XML valido per WPA2-PSK' {
        $xml = New-WlanProfileXml -Ssid "TestWifi" -Password "TestPass123"
        $xml | Should -Match "<name>TestWifi</name>"
        $xml | Should -Match "<keyMaterial>TestPass123</keyMaterial>"
        $xml | Should -Match "<authentication>WPA2PSK</authentication>"
    }
}

Describe 'Connect-AutoWiFi & Save-StoreWiFiProfile' {
    It 'Connect-AutoWiFi completa senza eccezioni in modalita test' {
        $Global:Test = $true
        $res = Connect-AutoWiFi -TargetDir "/fake/dir"
        $res | Should -BeTrue
        $Global:Test = $false
    }
    It 'Save-StoreWiFiProfile completa senza eccezioni in modalita test' {
        $Global:Test = $true
        $res = Save-StoreWiFiProfile -TargetDir "/fake/dir"
        $res | Should -BeTrue
        $Global:Test = $false
    }
}

Describe 'Set-SplitScreenLayout' {
    It 'esegue senza errori in modalita test' {
        $Global:Test = $true
        { Set-SplitScreenLayout -HtmlPath "/fake/test.html" } | Should -Not -Throw
        $Global:Test = $false
    }
}

Describe 'Set-EdgeFirstRunPolicies' {
    It 'esegue senza errori e non genera eccezioni' {
        { Set-EdgeFirstRunPolicies } | Should -Not -Throw
    }
}

Describe 'Sequenza Bootstrap Modalita 1 e 2' {
    It 'esegue Connect-AutoWiFi seguito da Open-PannelloOperatore e Set-SplitScreenLayout senza errori' {
        $Global:Test = $true
        {
            Enable-SilentElevation
            Set-PreventSleep $true
            Set-EdgeFirstRunPolicies
            Connect-AutoWiFi -TargetDir $PSScriptRoot
            Open-PannelloOperatore -NomeCliente "Mario Rossi"
        } | Should -Not -Throw
        $Global:Test = $false
    }
}

Describe 'Invoke-PcFacileDiagnostics' {
    It 'esegue senza errori e restituisce i dati diagnostici hardware, batteria e disco' {
        $diag = Invoke-PcFacileDiagnostics
        $diag | Should -Not -BeNullOrEmpty
        $diag.Hardware | Should -Not -BeNullOrEmpty
        $diag.Disco | Should -Not -BeNullOrEmpty
        $diag.Batteria | Should -Not -BeNullOrEmpty
        $diag.Windows | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-BrowserAutoSignup' {
    It 'completa con successo in modalita test' {
        $res = Invoke-BrowserAutoSignup -NomeCliente 'Mario Rossi' -Test
        $res | Should -Not -BeNullOrEmpty
        $res.Stato | Should -BeExactly 'Completato'
        $res.ServiziTestati | Should -Contain 'Proton'
    }
}

Describe 'Wait-CredenzialiPannello' {
    It 'completa immediatamente in modalita test' {
        $res = Wait-CredenzialiPannello -Test
        $res | Should -BeTrue
    }
}

Describe 'Install-WindowsUpdateDrivers' {
    It 'completa con successo in modalita test senza bloccare l''esecuzione' {
        $Global:Report = [System.Collections.ArrayList]::new()
        $res = Install-WindowsUpdateDrivers -Test
        $res | Should -Not -BeNullOrEmpty
        $res.Esito | Should -BeExactly 'OK'
        @($Global:Report | Where-Object { $_.Voce -eq "Driver (Windows Update)" -and $_.Esito -eq "OK" }).Count | Should -Be 1
    }
}

Describe 'Convert-PngToIco' {
    It 'converte byte PNG validi in file ICO conforme con header standard' {
        $pngBytes = [byte[]]@(
            137, 80, 78, 71, 13, 10, 26, 10,
            0, 0, 0, 13,
            73, 72, 68, 82,
            0, 0, 0, 48,
            0, 0, 0, 48,
            8, 6, 0, 0, 0
        )
        $tmp = [System.IO.Path]::GetTempFileName() + ".ico"
        try {
            $ok = Convert-PngToIco -pngBytes $pngBytes -outFile $tmp
            $ok | Should -BeTrue
            (Test-Path $tmp) | Should -BeTrue
            $icoBytes = [System.IO.File]::ReadAllBytes($tmp)
            $icoBytes[0] | Should -Be 0
            $icoBytes[1] | Should -Be 0
            $icoBytes[2] | Should -Be 1
            $icoBytes[3] | Should -Be 0
            $icoBytes[4] | Should -Be 1
            $icoBytes[5] | Should -Be 0
            $icoBytes[6] | Should -Be 48
            $icoBytes[7] | Should -Be 48
        } finally {
            if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'restituisce false su dati non validi o vuoti' {
        $tmp = [System.IO.Path]::GetTempFileName() + ".ico"
        try {
            Convert-PngToIco -pngBytes @(1, 2, 3) -outFile $tmp | Should -BeFalse
        } finally {
            if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Get-AppxPackageIcon' {
    It 'gestisce nomi sicuri e non va in errore se il pacchetto non e presente' {
        $res = Get-AppxPackageIcon -NomeApp "PacchettoInesistente12345"
        $res | Should -BeNullOrEmpty
    }
}

Describe 'Rimozione Bloatware, Booking, Dropbox e Unpin Taskbar' {
    It 'include Booking e Dropbox in tutte le liste di pulizia di setup-pc.ps1' {
        $content = Get-Content $script:SetupPath -Raw
        $content | Should -Match '\*Booking\*'
        $content | Should -Match '\*Dropbox\*'
        $content | Should -Match 'DropboxInc\.Dropbox'
        $content | Should -Match '\*AcerCareCenter\*'
        $content | Should -Match '\*Planet9\*'
    }

    It 'include la pulizia dei pin della barra applicazioni e dei file lnk e url' {
        $content = Get-Content $script:SetupPath -Raw
        $content | Should -Match 'User Pinned\\TaskBar'
        $content | Should -Match 'Unpin from taskbar|Rimuovi dalla barra'
        $content | Should -Match 'SilentInstalledAppsEnabled'
    }
}

Describe 'Sincronizzazione Credenziali Multi-Canale & Salvataggio Report Desktop' {
    It 'Get-CredenzialiSalvatePannello rileva pcfacile-cred (1).json con dati cliente e credenziali' {
        $tempDir = [System.IO.Path]::GetTempPath()
        $sampleCred = @{
            Email = "peppenappa@proton.me"
            Password = "PeppePassword123!"
            Provider = "Proton"
            Cliente = "peppe nappa"
            Nome = "nappa"
            Cognome = "peppe"
        } | ConvertTo-Json
        
        $testFile = Join-Path $tempDir "pcfacile-cred (1).json"
        try {
            $sampleCred | Set-Content -Path $testFile -Encoding UTF8
            $found = Get-CredenzialiSalvatePannello
            $found | Should -BeTrue
            $Global:nomeCliente | Should -Be "peppe nappa"
            $Global:credMsAccount | Should -Be "peppenappa@proton.me"
            $Global:credMsPassword | Should -Be "PeppePassword123!"
            $Global:credProvider | Should -Be "Proton"
        } finally {
            if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'setup-pc.ps1 contiene il salvataggio sul Desktop di Riepilogo-Configurazione-PC.txt e Scheda-Consegna-Cliente.pdf' {
        $content = Get-Content $script:SetupPath -Raw
        $content | Should -Match 'Riepilogo-Configurazione-PC\.txt'
        $content | Should -Match 'Scheda-Consegna-Cliente\.pdf'
        $content | Should -Match '--print-to-pdf='
        $content | Should -Match 'Start-LocalCredServer'
        $content | Should -Match 'Stop-LocalCredServer'
    }

    It 'Punto di Ripristino non contiene stringhe fuorvianti 5% SSD nel titolo ed e conteggiato come risolto' {
        $content = Get-Content $script:SetupPath -Raw
        $content | Should -Not -Match 'Punto di Ripristino di Sicurezza \(5% SSD\)'
        $content | Should -Match 'stato === ''done'' \|\| stato === ''skipped'''
        $content | Should -Match 'Ottimizzato SSD'
    }
}
