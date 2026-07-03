# =============================================================================
# setup-pc.ps1 - Automazione Configurazione PC
# =============================================================================

param(
    # Modalita' non interattiva: risponde in automatico e NON installa/modifica nulla.
    # Uso: powershell -ExecutionPolicy Bypass -File setup-pc.ps1 -Test
    [switch]$Test,
    # Diagnostica: controlla ambiente e valida gli ID pacchetti (winget show),
    # senza installare nulla, e mostra cosa e' OK/KO. -File setup-pc.ps1 -Diagnostica
    [switch]$Diagnostica
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Versione del programma (mostrata nell'header e nel riepilogo).
# Bump ad ogni modifica cosi' capisci se la USB e' aggiornata.
$SCRIPT_VERSION = "1.3 (2026-07-03)"

# =============================================================================
# FUNZIONI UTILITY
# =============================================================================

function Write-Titolo {
    param([string]$Testo)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  $Testo" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-OK {
    param([string]$Testo)
    Write-Host "[OK] $Testo" -ForegroundColor Green
}

function Write-Info {
    param([string]$Testo)
    Write-Host "[INFO] $Testo" -ForegroundColor Yellow
}

function Write-Errore {
    param([string]$Testo)
    Write-Host "[ERRORE] $Testo" -ForegroundColor Red
}

function Pausa {
    Write-Host ""
    Read-Host "Premi INVIO per continuare"
}

# Menu iniziale: se non e' stata scelta una modalita' via parametro, la chiedo.
# Un solo tasto, senza INVIO: D=diagnostica, T=test, C/INVIO/altro=configura.
if (-not $Test -and -not $Diagnostica) {
    try { Clear-Host } catch {}
    Write-Titolo "PC FACILE   -   versione $SCRIPT_VERSION"
    Write-Host "  Premi un tasto:" -ForegroundColor White
    Write-Host ""
    Write-Host "    [C] Configura il PC   (installa e imposta)"
    Write-Host "    [D] Diagnostica       (controlla, NON installa)"
    Write-Host "    [T] Test a vuoto      (percorre tutto, NON installa)"
    Write-Host ""
    Write-Host "  (C oppure INVIO = Configura)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  LEGENDA TASTI:" -ForegroundColor White
    Write-Host "    Nei menu    : premi la LETTERA o il NUMERO indicato" -ForegroundColor DarkGray
    Write-Host "    Nelle domande: S = si, N = no" -ForegroundColor DarkGray
    Write-Host "    A fine passo : INVIO = avanti, B o CANC = torna indietro" -ForegroundColor DarkGray
    Write-Host "    Per uscire   : chiudi la finestra" -ForegroundColor DarkGray

    $tasto = ""
    try {
        $k = [Console]::ReadKey($true)     # legge UN tasto, senza bisogno di INVIO
        $tasto = "$($k.KeyChar)".ToUpper()
    } catch {
        $tasto = (Read-Host "Scelta (C/D/T)").ToUpper()   # fallback se ReadKey non disponibile
    }
    if ($tasto -eq "D" -or $tasto -eq "2") { $Diagnostica = $true; Write-Host "  -> Diagnostica" -ForegroundColor Cyan }
    elseif ($tasto -eq "T" -or $tasto -eq "3") { $Test = $true; Write-Host "  -> Test a vuoto" -ForegroundColor Cyan }
    else { Write-Host "  -> Configura il PC" -ForegroundColor Cyan }
    Write-Host ""
}

# Modalita' TEST (-Test): rende lo script non interattivo e non distruttivo.
# Sovrascrive Read-Host (risponde N ai S/N, vuoto ai menu -> tutto saltato) e
# Pausa (nessuna attesa). Cosi' si verifica l'intero flusso in automatico.
if ($Test -or $Diagnostica) {
    if ($Test) { Write-Host "*** MODALITA' TEST: nessuna modifica reale, risposte automatiche ***" -ForegroundColor Magenta }
    function Read-Host {
        param([Parameter(Position = 0)][string]$Prompt)
        $risposta = if ($Prompt -match 'S/N') { "N" } else { "" }
        Write-Host "$Prompt [AUTO => '$risposta']" -ForegroundColor DarkGray
        return $risposta
    }
    function Pausa { }
}

# Run "reale" = Configura (non Test, non Diagnostica): solo qui si creano i
# file su Desktop (log/report/scheda/batteria), per non sporcare coi controlli.
$RunReale = (-not $Test -and -not $Diagnostica)

# Fine passo: INVIO = avanti, B = torna al passo precedente.
# Ritorna $true se l'utente vuole tornare indietro.
function Continua {
    if ($Test) { return $false }   # in Test avanza sempre, niente attesa
    Write-Host ""
    Write-Host "  [INVIO] continua     [B] o [CANC] torna al passo precedente" -ForegroundColor DarkGray
    try {
        $k = [Console]::ReadKey($true)
        if ("$($k.KeyChar)".ToUpper() -eq 'B') { return $true }
        if ($k.Key -eq [ConsoleKey]::Delete -or $k.Key -eq [ConsoleKey]::Backspace) { return $true }
        return $false
    } catch {
        return $false   # host senza console: come INVIO
    }
}

# =============================================================================
# REPORT FINALE + CONNETTIVITA'
# =============================================================================

$Report = [System.Collections.ArrayList]::new()

function Add-Report {
    param(
        [string]$Voce,
        [string]$Esito  # OK | ERRORE | SALTATO
    )
    [void]$Report.Add([pscustomobject]@{ Voce = $Voce; Esito = $Esito })
}

function Test-Rete {
    # 1) Ping veloce
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        if (($ping.Send("8.8.8.8", 2000)).Status -eq 'Success') { return $true }
    } catch {}
    # 2) Fallback: alcuni firewall bloccano il ping (ICMP) ma non il web (TCP 443)
    return (Test-Endpoint -HostName "www.microsoft.com")
}

# Verifica se un host e' raggiungibile su una porta (default 443) - connect TCP
function Test-Endpoint {
    param(
        [string]$HostName,
        [int]$Port = 443,
        [int]$TimeoutMs = 2500
    )
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne($TimeoutMs)
        $connesso = $ok -and $tcp.Connected
        $tcp.Close()
        return [bool]$connesso
    } catch {
        return $false
    }
}

# Cartella Desktop reale (gestisce anche il Desktop reindirizzato su OneDrive)
function Get-DesktopDir {
    try {
        $d = [Environment]::GetFolderPath('Desktop')
        if ($d -and (Test-Path $d)) { return $d }
    } catch {}
    $fallback = Join-Path $env:USERPROFILE "Desktop"
    if (Test-Path $fallback) { return $fallback }
    return $env:TEMP
}

# =============================================================================
# VERIFICA PRIVILEGI AMMINISTRATORE
# =============================================================================

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Errore "Questo script richiede privilegi di amministratore."
    if ($Test) {
        Write-Info "Modalita' TEST: proseguo comunque (nessuna operazione admin verra' eseguita)."
    } else {
        Write-Info "Riavvia PowerShell come amministratore e riprova."
        Pausa
        return  # return (non exit) per non chiudere la finestra se eseguito in memoria
    }
}

# =============================================================================
# CONTROLLO AMBIENTE (blocchi Windows)
# =============================================================================

# Rimuove il "mark-of-the-web" dallo script stesso (file scaricato da Internet)
try {
    if ($MyInvocation.MyCommand.Path) {
        Unblock-File -Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    }
} catch {}

# ExecutionPolicy: se lo script gira gia' e' ok, ma segnalo per chiarezza
$ep = Get-ExecutionPolicy
if ($ep -eq 'Restricted' -or $ep -eq 'AllSigned') {
    Write-Info "ExecutionPolicy: $ep. Se hai avuto errori di avvio, rilancia con:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -ForegroundColor Yellow
}

# Smart App Control (Controllo intelligente delle app): puo' bloccare .ps1/installer
try {
    $sac = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
            -Name VerifiedAndReputablePolicyState -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState
    if ($sac -eq 1) {
        Write-Host "[AVVISO] Smart App Control ATTIVO: potrebbe bloccare alcuni installer scaricati." -ForegroundColor Yellow
        Write-Info "Se un'installazione viene bloccata: Sicurezza di Windows > Controllo app e browser >"
        Write-Info "  Controllo intelligente delle app > Disattivato (IRREVERSIBILE senza reinstallare Windows)."
        Write-Info "Puoi comunque proseguire: molte app (firmate/reputate) si installano lo stesso."
        Pausa
    }
} catch {}

# =============================================================================
# ACCORTEZZE PC NUOVO (orologio + anti-sospensione)
# =============================================================================

# Data/ora sbagliata su un PC nuovo -> errori HTTPS su winget e download.
# Sincronizzo l'orologio con il time server di Windows.
try {
    Set-Service -Name w32time -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name w32time -ErrorAction SilentlyContinue
    & w32tm /resync /force 2>$null | Out-Null
} catch {}

# Tiene sveglio il PC mentre lo script gira (installazioni lunghe su laptop).
# Usa lo stato di esecuzione del thread: si annulla da solo alla chiusura,
# nessuna modifica permanente allo schema energetico.
try {
    Add-Type -Name Power -Namespace Win32Setup -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@ -ErrorAction SilentlyContinue
    # ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x1) | ES_DISPLAY_REQUIRED (0x2)
    [void][Win32Setup.Power]::SetThreadExecutionState([uint32]"0x80000003")
} catch {}

# =============================================================================
# INFO COMPATIBILITA' (Windows e PowerShell)
# =============================================================================

try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        Write-Info "Sistema: $($os.Caption) (build $($os.BuildNumber))"
        $build = 0
        [void][int]::TryParse($os.BuildNumber, [ref]$build)
        if ($build -gt 0 -and $build -lt 17763) {
            Write-Errore "Windows troppo vecchio (build $build): winget richiede 1809 (17763) o superiore."
            Write-Info "Le installazioni app potrebbero non funzionare su questo sistema."
        }
    }
} catch {}

Write-Info "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Info "Consiglio: usa Windows PowerShell 5.1 (PC Facile.bat lo fa gia'). Su PowerShell 7"
    Write-Info "  l'installazione di riserva di winget (Add-AppxPackage) puo' non funzionare."
}

# PowerShell a 32-bit (x86) su Windows a 64-bit: winget spesso da errori
# (sorgenti/certificati). Va usata la versione a 64-bit.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Errore "Stai usando PowerShell a 32-bit (x86) su Windows a 64-bit."
    Write-Info "winget puo' fallire. Chiudi e apri 'Windows PowerShell' NORMALE (64-bit),"
    Write-Info "  NON la voce con '(x86)'. Oppure usa PC Facile.bat (parte a 64-bit)."
    Pausa
}

# =============================================================================
# CONTROLLI PRE-INSTALLAZIONE (riavvio in sospeso + spazio disco)
# =============================================================================

# Riavvio in sospeso: alcune installazioni falliscono finche' non si riavvia.
try {
    $rebootPending = $false
    $chiaviReboot = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    foreach ($k in $chiaviReboot) { if (Test-Path $k) { $rebootPending = $true } }
    $pfro = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
             -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pfro) { $rebootPending = $true }
    if ($rebootPending) {
        Write-Info "C'e' un RIAVVIO in sospeso: alcune installazioni potrebbero fallire."
        Write-Info "Consiglio: riavvia il PC e rilancia lo script per risultati migliori."
    }
} catch {}

# Spazio libero sul disco di sistema
try {
    $lettera = $env:SystemDrive.TrimEnd(':')
    $free = (Get-PSDrive $lettera -ErrorAction SilentlyContinue).Free
    if ($free) {
        $freeGB = [math]::Round($free / 1GB, 1)
        Write-Info "Spazio libero su $($env:SystemDrive) $freeGB GB"
        if ($freeGB -lt 10) {
            Write-Errore "Poco spazio libero ($freeGB GB): le installazioni potrebbero fallire."
        }
    }
} catch {}

# Attivazione di Windows (evita di consegnare un PC con Windows non attivo)
try {
    $winLic = Get-CimInstance -ClassName SoftwareLicensingProduct `
        -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($winLic -and $winLic.LicenseStatus -eq 1) {
        Write-OK "Windows attivato."
        Add-Report "Windows attivato" "OK"
    } else {
        Write-Errore "Windows NON risulta attivato: verifica la licenza prima di consegnare."
        Add-Report "Windows attivato" "ERRORE"
    }
} catch {}

# Salute del disco (SMART): avvisa se un disco non e' Healthy
try {
    $dischi = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($dischi) {
        $malati = @($dischi | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' })
        if ($malati.Count -gt 0) {
            foreach ($d in $malati) { Write-Errore "Disco '$($d.FriendlyName)': stato $($d.HealthStatus)!" }
            Add-Report "Salute disco" "ERRORE"
        } else {
            Write-OK "Dischi in salute (Healthy)."
        }
    }
} catch {}

# Presenza batteria (per laptop): lo stato dettagliato finisce nel file riepilogo
try {
    $Global:HaBatteria = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
} catch { $Global:HaBatteria = $false }

# =============================================================================
# PREFLIGHT RETE (utile su reti aziendali con firewall/proxy)
# =============================================================================

Write-Host ""
Write-Info "Controllo raggiungibilita' servizi (rete)..."
$endpoints = @(
    @{ Nome = "GitHub (download script)";            HostName = "raw.githubusercontent.com" },
    @{ Nome = "Microsoft (winget/Windows Update)";   HostName = "www.microsoft.com" },
    @{ Nome = "Store winget (installazione app)";    HostName = "cdn.winget.microsoft.com" }
)
$bloccati = 0
foreach ($e in $endpoints) {
    if (Test-Endpoint -HostName $e.HostName) {
        Write-OK "OK  $($e.Nome)"
    } else {
        Write-Errore "KO  $($e.Nome) [$($e.HostName)]"
        $bloccati++
    }
}
if ($bloccati -gt 0) {
    Write-Info "$bloccati servizio/i non raggiungibile/i: probabile firewall o proxy aziendale."
    Write-Info "Rimedi: tieni setup-pc.ps1 accanto ad PC Facile.bat (evita GitHub); per le"
    Write-Info "  installazioni app usa un hotspot o una rete senza filtri."
    Add-Report "Rete: $bloccati servizio/i bloccato/i" "AVVISO"
    Pausa
} else {
    Write-OK "Tutti i servizi chiave sono raggiungibili."
}

# =============================================================================
# LOG SU FILE (registro per ogni PC)
# =============================================================================

# Nessun log/transcript separato: a fine lavoro si crea UN solo file riepilogo.
$Global:LogFile = $null

# =============================================================================
# FUNZIONE: VERIFICA E INSTALLA WINGET
# =============================================================================

# Ripara le sorgenti winget (una volta per sessione, o forzato su errore).
# Risolve gli errori di integrita' sorgente/certificato (es. 0x8A15005E) su
# sorgenti corrotte o non aggiornate, tipici su PC nuovi.
function Repair-WingetSources {
    param([switch]$Forza)
    if ($Global:WingetRiparato -and -not $Forza) { return }
    $Global:WingetRiparato = $true
    Write-Info "Riparazione sorgenti winget (reset + update)..."
    try {
        winget source reset --force 2>&1 | Out-Null
        winget source update 2>&1 | Out-Null
        Write-OK "Sorgenti winget ripristinate."
    } catch {
        Write-Info "Riparazione sorgenti non riuscita: $_"
    }
}

function Confirm-Winget {
    # Risultato calcolato una sola volta per sessione (evita ricontrolli/reinstalli)
    if ($null -ne $Global:WingetOk) { return $Global:WingetOk }

    Write-Info "Verifica presenza di Winget..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-OK "Winget trovato."
        $Global:WingetOk = $true
        Repair-WingetSources
        return $true
    }

    Write-Info "Winget non trovato. Tentativo di installazione..."

    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $msixBundle = $releases.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

        if (-not $msixBundle) {
            Write-Errore "Impossibile trovare il pacchetto Winget su GitHub."
            $Global:WingetOk = $false
            return $false
        }

        $tempPath = "$env:TEMP\AppInstaller.msixbundle"
        Write-Info "Download in corso: $($msixBundle.name)"
        Invoke-WebRequest -Uri $msixBundle.browser_download_url -OutFile $tempPath -UseBasicParsing

        Add-AppxPackage -Path $tempPath -ErrorAction Stop
        Remove-Item $tempPath -Force

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-OK "Winget installato con successo."
            $Global:WingetOk = $true
            Repair-WingetSources
            return $true
        } else {
            Write-Errore "Installazione Winget fallita."
            $Global:WingetOk = $false
            return $false
        }
    } catch {
        Write-Errore "Errore durante installazione Winget: $_"
        $Global:WingetOk = $false
        return $false
    }
}

function Installa-Pacchetto {
    param(
        [string]$Nome,
        [string]$WingetId
    )

    # Gli ID Microsoft Store sono 12 caratteri maiuscoli/numeri (es. WhatsApp):
    # senza --source msstore winget puo' non trovarli/installarli.
    $sorgente = @()
    if ($WingetId -match '^[A-Z0-9]{12}$') { $sorgente = @('--source', 'msstore') }

    # Gia' installato? (--exact: evita falsi positivi da match parziale dell'ID)
    winget list --exact --id $WingetId @sorgente --accept-source-agreements 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Nome gia' installato. Salto."
        Add-Report "$Nome (installazione)" "OK"
        return
    }

    # Codici che indicano successo (0) o successo con riavvio richiesto (3010/1641)
    $successo = @(0, 3010, 1641)
    # Errori di integrita'/certificato/sorgente: si risolvono riparando le sorgenti
    $erroriSorgente = @(-1978335138, -1978335215, -1978335216)  # 0x8A15005E e simili
    $riparatoQui = $false

    $maxTentativi = 3
    $tentativiFatti = 0
    for ($tentativo = 1; $tentativo -le $maxTentativi; $tentativo++) {
        $tentativiFatti = $tentativo
        Write-Info "Installazione $Nome in corso (tentativo $tentativo/$maxTentativi)..."
        winget install --exact --id $WingetId @sorgente --silent --accept-package-agreements --accept-source-agreements
        if ($successo -contains $LASTEXITCODE) {
            if ($LASTEXITCODE -eq 0) {
                Write-OK "$Nome installato."
            } else {
                Write-OK "$Nome installato (richiede riavvio)."
            }
            Add-Report "$Nome (installazione)" "OK"
            return
        }

        Write-Errore "Installazione $Nome fallita (codice: $LASTEXITCODE)."

        if (($erroriSorgente -contains $LASTEXITCODE) -and -not $riparatoQui) {
            # Sorgenti corrotte: riparo (reset+update forzato) e ritento
            Write-Info "Errore di integrita' sorgente: riparo le sorgenti winget e ritento..."
            Repair-WingetSources -Forza
            $riparatoQui = $true
            continue
        }

        if (-not (Test-Rete)) {
            Write-Info "Rete assente. Attendo 10s e riprovo..."
            Start-Sleep -Seconds 10
        } else {
            break  # errore non dovuto alla rete/sorgente, inutile ritentare
        }
    }

    Write-Errore "$Nome NON installato (tentativi: $tentativiFatti)."
    Add-Report "$Nome (installazione)" "ERRORE"
}

# =============================================================================
# DIAGNOSTICA (-Diagnostica): controlla senza modificare nulla, poi esce
# =============================================================================

if ($Diagnostica) {
    Write-Titolo "DIAGNOSTICA (v$SCRIPT_VERSION) - Nessuna modifica al sistema"

    # Ambiente
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        Write-Errore "PowerShell a 32-bit (x86): winget e LocalAccounts a rischio. Usa 64-bit."
    } else {
        Write-OK "PowerShell a 64-bit."
    }

    # winget + riparazione sorgenti
    if (Confirm-Winget) {
        Write-OK "winget disponibile (sorgenti riparate)."

        # Tutti gli ID pacchetti usati dallo script
        $tuttiId = @(
            @{ N = "Microsoft 365";        Id = "Microsoft.Office" },
            @{ N = "OpenOffice";           Id = "Apache.OpenOffice" },
            @{ N = "LibreOffice";          Id = "TheDocumentFoundation.LibreOffice" },
            @{ N = "Google Chrome";        Id = "Google.Chrome" },
            @{ N = "Mozilla Firefox";      Id = "Mozilla.Firefox" },
            @{ N = "Microsoft Edge";       Id = "Microsoft.Edge" },
            @{ N = "Brave";                Id = "Brave.Brave" },
            @{ N = "Opera";                Id = "Opera.Opera" },
            @{ N = "Opera GX";             Id = "Opera.OperaGX" },
            @{ N = "Vivaldi";              Id = "Vivaldi.Vivaldi" },
            @{ N = "VLC Media Player";     Id = "VideoLAN.VLC" },
            @{ N = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" },
            @{ N = "Spotify";              Id = "Spotify.Spotify" },
            @{ N = "7-Zip";                Id = "7zip.7zip" },
            @{ N = "WhatsApp";             Id = "9NKSQGP7F2NH" },
            @{ N = "Sumatra PDF";          Id = "SumatraPDF.SumatraPDF" },
            @{ N = "AIMP";                 Id = "AIMP.AIMP" },
            @{ N = "GIMP";                 Id = "GIMP.GIMP" },
            @{ N = "TeamViewer";           Id = "TeamViewer.TeamViewer" },
            @{ N = "qBittorrent";          Id = "qBittorrent.qBittorrent" },
            @{ N = "Steam";                Id = "Valve.Steam" },
            @{ N = "AnyDesk";              Id = "AnyDesk.AnyDesk" },
            @{ N = "Discord";              Id = "Discord.Discord" },
            @{ N = "Zoom";                 Id = "Zoom.Zoom" }
        )

        Write-Host ""
        Write-Info "Verifica ID pacchetti con 'winget show' (nessuna installazione)..."
        $ko = 0; $installati = 0
        foreach ($p in $tuttiId) {
            $src = @()
            if ($p.Id -match '^[A-Z0-9]{12}$') { $src = @('--source', 'msstore') }
            winget show --exact --id $p.Id @src --accept-source-agreements 2>$null | Out-Null
            $valido = ($LASTEXITCODE -eq 0)
            winget list --exact --id $p.Id @src --accept-source-agreements 2>$null | Out-Null
            $gia = ($LASTEXITCODE -eq 0)
            if ($valido) {
                if ($gia) { Write-OK "OK   $($p.N)  [gia' installato]"; $installati++ }
                else { Write-OK "OK   $($p.N)  [$($p.Id)]" }
            } else {
                Write-Errore "KO   $($p.N)  [$($p.Id)]  (codice $LASTEXITCODE)"
                $ko++
            }
        }
        Write-Host ""
        Write-Host ("Riepilogo pacchetti: {0} validi, {1} KO, {2} gia' installati (su {3})" -f ($tuttiId.Count - $ko), $ko, $installati, $tuttiId.Count) -ForegroundColor Cyan
        if ($ko -eq 0) { Write-OK "Tutti gli ID pacchetti sono validi." }
        else { Write-Errore "$ko ID pacchetto/i non risolti: da correggere nello script." }
    } else {
        Write-Errore "winget NON disponibile: impossibile validare i pacchetti."
    }

    # Test scrittura sul Desktop (il report/riepilogo finale si salva qui)
    Write-Host ""
    try {
        $tf = Join-Path (Get-DesktopDir) "pcfacile_test.tmp"
        "test" | Set-Content -Path $tf -ErrorAction Stop
        Remove-Item $tf -Force -ErrorAction SilentlyContinue
        Write-OK "Desktop scrivibile (report/riepilogo OK): $(Get-DesktopDir)"
    } catch {
        Write-Errore "Desktop NON scrivibile: il file riepilogo potrebbe non salvarsi."
    }

    # Office installato? (per attivazione perpetuo serve ospp.vbs)
    $ospp = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($ospp) { Write-OK "Office installato (ospp.vbs trovato): attivazione perpetuo possibile." }
    else { Write-Info "Office non ancora installato (ospp.vbs assente): normale su PC nuovo." }

    Write-Host ""
    Write-Info "Diagnostica completata. Nessuna modifica effettuata al sistema."
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
    return  # return (non exit) per non chiudere la finestra se eseguito in memoria
}

# =============================================================================
# BENVENUTO
# =============================================================================

# Clear-Host fallisce senza una console vera (esecuzione headless/redirect): protetto
try { Clear-Host } catch {}
Write-Titolo "AUTOMAZIONE CONFIGURAZIONE PC - Avvio"
Write-Host "Questo script guida la configurazione del PC del cliente passo per passo." -ForegroundColor White
Write-Host "Segui le istruzioni a schermo e premi INVIO quando indicato." -ForegroundColor White
Pausa

# =============================================================================
# PUNTO DI RIPRISTINO (rete di sicurezza prima delle modifiche)
# =============================================================================

Write-Titolo "Punto di Ripristino"

Write-Host "Crea un punto di ripristino: se qualcosa va storto puoi tornare indietro." -ForegroundColor White
Write-Host ""

$vuoiRestore = Read-Host "Creare un punto di ripristino ora? (consigliato) (S/N)"
if ($vuoiRestore -match "^[Ss]") {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Rimuove il limite di 1 punto ogni 24h, solo per crearne uno adesso
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
            -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Info "Creazione punto di ripristino (puo' richiedere un minuto)..."
        Checkpoint-Computer -Description "Prima di setup-pc" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-OK "Punto di ripristino creato."
        Add-Report "Punto di ripristino" "OK"
    } catch {
        Write-Info "Impossibile creare il punto di ripristino (protezione sistema disattivata?): $_"
        Add-Report "Punto di ripristino" "ERRORE"
    }
} else {
    Write-Info "Punto di ripristino saltato."
    Add-Report "Punto di ripristino" "SALTATO"
}

Pausa

# =============================================================================
# ACCOUNT MICROSOFT (accedi/crea presto: velocizza Office e antivirus dopo)
# =============================================================================

Write-Titolo "Account Microsoft"

Write-Host "Accedi (o crea) l'account Microsoft ORA: la sessione resta attiva nel" -ForegroundColor White
Write-Host "browser, cosi' dopo su Office e antivirus fai 'Accedi con Microsoft' al volo." -ForegroundColor White
Write-Host ""

$vuoiMs = Read-Host "Aprire il login account Microsoft ora? (S/N)"
if ($vuoiMs -match "^[Ss]") {
    Start-Process "https://account.microsoft.com"
    Write-OK "Aperto account.microsoft.com nel browser."
    Write-Info "Accedi o crea l'account, poi torna qui. Usa lo stesso browser per i login dopo."
    Add-Report "Account Microsoft" "OK"
} else {
    Write-Info "Account Microsoft saltato."
    Add-Report "Account Microsoft" "SALTATO"
}

Pausa

# =============================================================================
# PASSI DI CONFIGURAZIONE (tasto B a fine passo = torna indietro)
# =============================================================================

$passo = 0
while ($passo -ge 0 -and $passo -le 10) {
switch ($passo) {
0 {
# =============================================================================
# STEP 0 - LINGUA E REGIONE (ITALIANO)
# =============================================================================

Write-Titolo "STEP 0 - Lingua e Regione (Italiano)"

Write-Host "I PC installati da chiavetta partono spesso in INGLESE." -ForegroundColor White
Write-Host "Questo passaggio imposta display, formati, tastiera e language pack in it-IT." -ForegroundColor White
Write-Host ""

$culturaAttuale = (Get-Culture).Name
Write-Info "Lingua/regione attuale: $culturaAttuale"

$impostaLingua = Read-Host "Impostare il sistema in Italiano (it-IT)? (S/N)"
if ($impostaLingua -match "^[Ss]") {

    # --- 1) Impostazioni BASE (locali, sempre applicabili anche senza rete) ---
    try {
        # Lista lingue utente: italiano in cima + tastiera italiana (0410:00000410)
        $lista = New-WinUserLanguageList it-IT
        $lista[0].InputMethodTips.Clear()
        $lista[0].InputMethodTips.Add("0410:00000410")
        Set-WinUserLanguageList $lista -Force

        Set-WinUILanguageOverride -Language it-IT
        Set-Culture it-IT
        Set-WinHomeLocation -GeoId 118    # Italia

        Write-OK "Lingua, tastiera e regione impostate su Italiano (it-IT)."
        Add-Report "Lingua italiana (it-IT)" "OK"
    } catch {
        Write-Errore "Impossibile impostare la lingua base: $_"
        Add-Report "Lingua italiana (it-IT)" "ERRORE"
    }

    # Locale di sistema (per programmi non-Unicode): separato, un suo errore
    # non deve invalidare tastiera/formati gia' applicati sopra.
    try {
        Set-WinSystemLocale it-IT
    } catch {
        Write-Info "Impostazione locale di sistema non riuscita: proseguo (tastiera/formati restano validi)."
    }

    # --- 2) Language pack (Windows 11 22H2+): richiede Internet, NON deve bloccare il resto ---
    if (Get-Command Install-Language -ErrorAction SilentlyContinue) {
        try {
            $installate = (Get-InstalledLanguage -ErrorAction SilentlyContinue).LanguageId
            if ($installate -notcontains "it-IT") {
                Write-Info "Installazione language pack it-IT (puo' richiedere qualche minuto)..."
                Install-Language it-IT -ErrorAction Stop | Out-Null
            } else {
                Write-Info "Language pack it-IT gia' presente."
            }
        } catch {
            Write-Info "Language pack it-IT non installato (rete assente/bloccata?): le impostazioni base restano valide."
        }
    } else {
        Write-Info "Install-Language non disponibile (Windows 10): il pacchetto lingua va aggiunto a mano."
        $packDaAggiungere = $true
    }

    # --- 3) Lingua UI di sistema (Windows 11), non fatale ---
    if (Get-Command Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue) {
        try { Set-SystemPreferredUILanguage it-IT } catch { Write-Info "Impostazione lingua UI di sistema non riuscita: proseguo." }
    }

    # --- 4) Propaga a login + nuovi utenti + sistema (Windows 11), non fatale ---
    if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        try {
            Write-Info "Propagazione impostazioni a login e nuovi utenti..."
            Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
        } catch {
            Write-Info "Propagazione a login/nuovi utenti non riuscita: da sistemare a mano se serve."
        }
    } else {
        Write-Info "Propagazione automatica a login/nuovi utenti non disponibile su questo Windows."
    }

    Write-Info "La lingua di sistema e del login si applicano del tutto dopo il RIAVVIO del PC."

    # --- 5) Windows 10: il pacchetto lingua (display) va aggiunto a mano ---
    if ($packDaAggiungere) {
        Write-Info "Su Windows 10 il pacchetto della lingua di visualizzazione va aggiunto a mano."
        $apriImp = Read-Host "Aprire ora Impostazioni lingua per aggiungere/verificare l'Italiano? (S/N)"
        if ($apriImp -match "^[Ss]") {
            Start-Process "ms-settings:regionlanguage"
            Write-Info "In Impostazioni: aggiungi 'Italiano (Italia)', impostalo come lingua di"
            Write-Info "  visualizzazione e scarica il pacchetto lingua. Poi torna qui."
            Pausa
        }
    }
} else {
    Write-Info "Impostazione lingua saltata."
    Add-Report "Lingua italiana (it-IT)" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
1 {
# =============================================================================
# STEP 1 - NOME CLIENTE
# =============================================================================

Write-Titolo "STEP 1 - Nome Completo Cliente"

# Legge il nome visualizzato attuale: prima LocalAccounts, poi ADSI (che
# funziona anche in PowerShell x86, dove il modulo LocalAccounts non c'e').
$adsiUser = 'WinNT://./' + $env:USERNAME + ',user'
$nomeAttuale = $null
try {
    $nomeAttuale = (Get-LocalUser -Name $env:USERNAME -ErrorAction Stop).FullName
} catch {
    try { $nomeAttuale = ([ADSI]$adsiUser).FullName } catch {}
}
Write-Info "Utente corrente: $env:USERNAME"
Write-Info "Nome visualizzato attuale: $(if ($nomeAttuale) { $nomeAttuale } else { '(non impostato)' })"
Write-Host ""

$nomeCliente = Read-Host "Inserisci il nome completo del cliente (es. Mario Rossi)"

if ($nomeCliente.Trim() -ne "") {
    $nomeOk = $false
    # 1) Metodo moderno (modulo LocalAccounts, disponibile solo in PowerShell 64-bit)
    try {
        Set-LocalUser -Name $env:USERNAME -FullName $nomeCliente.Trim() -ErrorAction Stop
        $nomeOk = $true
    } catch {
        # 2) Fallback ADSI/WinNT: funziona anche in x86 e senza il modulo LocalAccounts
        try {
            $u = [ADSI]$adsiUser
            $u.FullName = $nomeCliente.Trim()
            $u.SetInfo()
            $nomeOk = $true
        } catch {}
    }
    if ($nomeOk) {
        Write-OK "Nome utente aggiornato a: $($nomeCliente.Trim())"
        Add-Report "Nome cliente" "OK"
    } else {
        Write-Errore "Impossibile aggiornare il nome visualizzato dell'account $env:USERNAME."
        Add-Report "Nome cliente" "ERRORE"
    }
} else {
    Write-Info "Nome non modificato."
    Add-Report "Nome cliente" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
2 {
# =============================================================================
# STEP 2 - RISCATTO LICENZA OFFICE
# =============================================================================

Write-Titolo "STEP 2 - Riscatto Licenza Microsoft Office"

Write-Host "Verrà aperto il browser su setup.office.com" -ForegroundColor White
Write-Host "Il cliente deve accedere con il proprio account Microsoft per riscattare la licenza." -ForegroundColor White
Write-Host ""

$risposta = Read-Host "Aprire setup.office.com ora? (S/N)"
if ($risposta -match "^[Ss]") {
    Start-Process "https://setup.office.com"
    Write-OK "Browser aperto su setup.office.com"
    Write-Info "Attendi che il cliente completi il riscatto licenza prima di procedere."
    Add-Report "Riscatto licenza Office (setup.office.com)" "OK"
} else {
    Write-Info "Passaggio saltato."
    Add-Report "Riscatto licenza Office (setup.office.com)" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
3 {
# =============================================================================
# STEP 3 - INSTALLAZIONE OFFICE
# =============================================================================

Write-Titolo "STEP 3 - Installazione Suite Office"

Write-Host "Scegli la suite da installare:" -ForegroundColor White
Write-Host "  1) Microsoft 365 (richiede licenza attiva)"
Write-Host "  2) OpenOffice"
Write-Host "  3) LibreOffice"
Write-Host "  4) Salta"
Write-Host ""

$sceltaOffice = Read-Host "Scelta (1-4)"

switch ($sceltaOffice) {
    "1" {
        Write-Info "Verifica Winget..."
        if (Confirm-Winget) {
            Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office"
        } else {
            Write-Errore "Winget non disponibile. Installa Microsoft 365 manualmente."
        }
    }
    "2" {
        if (Confirm-Winget) {
            Installa-Pacchetto -Nome "OpenOffice" -WingetId "Apache.OpenOffice"
        } else {
            Write-Errore "Winget non disponibile."
        }
    }
    "3" {
        if (Confirm-Winget) {
            Installa-Pacchetto -Nome "LibreOffice" -WingetId "TheDocumentFoundation.LibreOffice"
        } else {
            Write-Errore "Winget non disponibile."
        }
    }
    "4" {
        Write-Info "Installazione Office saltata."
    }
    default {
        Write-Info "Nessuna scelta valida: passaggio saltato."
    }
}

# --- Attivazione licenza Office PERPETUA (product key) ---
Write-Host ""
Write-Host "Se hai installato Office PERPETUO (2021/2024), attivalo ora col product key." -ForegroundColor White
Write-Host "Per Microsoft 365 (abbonamento) rispondi N: si attiva dal login su setup.office.com." -ForegroundColor White
Write-Host ""

function Get-OsppPath {
    $percorsi = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs"
    )
    foreach ($p in $percorsi) { if (Test-Path $p) { return $p } }
    return $null
}

while ($true) {
    $rispostaChiave = Read-Host "Attivare una licenza Office perpetua con product key? (S/N)"

    if ($rispostaChiave -match "^[Ss]$") {
        $osppPath = Get-OsppPath
        if (-not $osppPath) {
            Write-Errore "ospp.vbs non trovato. Office non installato o percorso diverso."
            Write-Info "Installa Office (sopra) prima di attivare."
            Add-Report "Attivazione Office perpetuo" "ERRORE"
            break
        }
        $chiaveLicenza = (Read-Host "Inserisci il product key (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)").Trim().ToUpper()
        if ($chiaveLicenza -notmatch "^([A-Z0-9]{5}-){4}[A-Z0-9]{5}$") {
            Write-Errore "Formato non valido: 5 gruppi da 5 caratteri separati da trattino."
            continue
        }
        Write-Info "Inserimento product key..."
        cscript //nologo $osppPath /inpkey:$chiaveLicenza
        if ($LASTEXITCODE -ne 0) {
            Write-Errore "Inserimento chiave fallito (codice $LASTEXITCODE)."
            Add-Report "Attivazione Office perpetuo" "ERRORE"
            break
        }
        Write-Info "Attivazione in corso..."
        cscript //nologo $osppPath /act
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Office attivato con successo."
            Add-Report "Attivazione Office perpetuo" "OK"
        } else {
            Write-Errore "Attivazione fallita (codice $LASTEXITCODE). Verifica chiave e connessione."
            Add-Report "Attivazione Office perpetuo" "ERRORE"
        }
        break
    } elseif ($rispostaChiave -match "^[Nn]$") {
        Write-Info "Attivazione perpetua saltata."
        Add-Report "Attivazione Office perpetuo" "SALTATO"
        break
    } elseif ($rispostaChiave -eq "") {
        Write-Info "Nessun input (fine stdin). Passaggio saltato."
        Add-Report "Attivazione Office perpetuo" "SALTATO"
        break
    } else {
        Write-Errore "Input non valido. Rispondi con S o N."
    }
}

if (Continua) { $passo-- } else { $passo++ }
}
4 {
# =============================================================================
# STEP 4 - ANTIVIRUS
# =============================================================================

Write-Titolo "STEP 4 - Antivirus"

Write-Host "Scegli l'antivirus da installare:" -ForegroundColor White
Write-Host "  1) McAfee"
Write-Host "  2) Norton"
Write-Host "  3) Salta"
Write-Host ""

$sceltaAV = Read-Host "Scelta (1-3)"

function Installa-Antivirus {
    param(
        [string]$Nome,
        [string]$UrlRiscatto
    )

    Write-Info "Apertura pagina registrazione/riscatto $Nome..."
    Start-Process $UrlRiscatto
    Write-OK "Browser aperto su: $UrlRiscatto"
    Write-Host ""
    Write-Host "Completa registrazione e attivazione nel browser." -ForegroundColor White
    Write-Host "Al termine il sito scarica l'installer (di solito nella cartella Download)." -ForegroundColor White
    Read-Host "Premi INVIO QUANDO IL DOWNLOAD E' FINITO"

    # L'installer ha nome variabile: cerco l'.exe piu' recente in Download e Desktop
    # (finestra ampia: la registrazione online puo' richiedere tempo)
    $cartelle = @((Join-Path $env:USERPROFILE "Downloads"), (Get-DesktopDir)) | Select-Object -Unique
    $recente = Get-ChildItem -Path $cartelle -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-60) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($recente) {
        Write-OK "Installer recente trovato: $($recente.Name)"
        $avvia = Read-Host "Avviare questo installer? (S/N)"
        if ($avvia -match "^[Ss]") {
            Start-Process -FilePath $recente.FullName
            Write-OK "Installer $Nome avviato."
            Add-Report "$Nome (antivirus)" "OK"
        } else {
            Write-Info "Avvio installer annullato."
            Add-Report "$Nome (antivirus)" "SALTATO"
        }
    } else {
        # Non e' un errore dello script: l'installer non e' ancora stato scaricato.
        Write-Info "Nessun .exe recente (ultimi 60 min) in Download o Desktop."
        $percorso = Read-Host "Incolla il percorso completo dell'installer $Nome (INVIO per saltare)"
        $percorso = ($percorso -replace '"', '').Trim()
        if ($percorso -ne "" -and (Test-Path $percorso)) {
            Start-Process -FilePath $percorso
            Write-OK "Installer $Nome avviato."
            Add-Report "$Nome (antivirus)" "OK"
        } elseif ($percorso -ne "") {
            Write-Errore "Percorso non valido: $percorso"
            Add-Report "$Nome (antivirus)" "ERRORE"
        } else {
            Write-Info "${Nome}: installer da avviare a mano piu' tardi."
            Add-Report "$Nome (antivirus)" "AVVISO"
        }
    }
}

# Servizio web-only (nessun installer PC): apre il sito, l'operatore inserisce
# il codice e segna le credenziali per l'app mobile del cliente.
function Attiva-ServizioWeb {
    param(
        [string]$Nome,
        [string]$UrlAttivazione
    )

    Write-Info "Apertura pagina attivazione $Nome..."
    Start-Process $UrlAttivazione
    Write-OK "Browser aperto su: $UrlAttivazione"
    Write-Host ""
    Write-Host "Sul sito: inserisci il codice/PIN e completa i dati richiesti." -ForegroundColor White
    Write-Host "IMPORTANTE: annota le credenziali per l'app mobile e consegnale al cliente." -ForegroundColor Yellow
    $fatto = Read-Host "Attivazione completata e credenziali annotate? (S/N)"
    if ($fatto -match "^[Ss]") {
        Write-OK "$Nome attivato."
        Add-Report "$Nome (protezione)" "OK"
    } else {
        Write-Info "$Nome non completato."
        Add-Report "$Nome (protezione)" "SALTATO"
    }
}

switch ($sceltaAV) {
    "1" {
        Installa-Antivirus -Nome "McAfee" -UrlRiscatto "https://home.mcafee.com/activate"
    }
    "2" {
        Installa-Antivirus -Nome "Norton" -UrlRiscatto "https://www.norton.com/setup"
    }
    "3" {
        Write-Info "Antivirus saltato."
        Add-Report "Antivirus" "SALTATO"
    }
    default {
        Write-Info "Nessuna scelta valida: passaggio saltato."
        Add-Report "Antivirus" "SALTATO"
    }
}

if (Continua) { $passo-- } else { $passo++ }
}
5 {
# =============================================================================
# STEP 4c - UNIEURO CYBER PROTECTION (opzionale)
# =============================================================================

Write-Titolo "STEP 4c - Unieuro Cyber Protection"

Write-Host "Servizio venduto solo su richiesta: salta se il cliente non l'ha acquistato." -ForegroundColor White
Write-Host ""

$vuoiUnieuro = Read-Host "Attivare Unieuro Cyber Protection? (S/N)"
if ($vuoiUnieuro -match "^[Ss]") {
    Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it"
} else {
    Write-Info "Unieuro Cyber Protection saltato."
    Add-Report "Unieuro Cyber Protection" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
6 {
# =============================================================================
# STEP 5 - BROWSER
# =============================================================================

Write-Titolo "STEP 5 - Browser"

$browserDisponibili = @(
    @{ Nome = "Google Chrome";   Id = "Google.Chrome" },
    @{ Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
    @{ Nome = "Microsoft Edge";  Id = "Microsoft.Edge" },
    @{ Nome = "Brave";           Id = "Brave.Brave" },
    @{ Nome = "Opera";           Id = "Opera.Opera" },
    @{ Nome = "Opera GX";        Id = "Opera.OperaGX" },
    @{ Nome = "Vivaldi";         Id = "Vivaldi.Vivaldi" }
)

Write-Host "Browser disponibili:" -ForegroundColor White
for ($i = 0; $i -lt $browserDisponibili.Count; $i++) {
    Write-Host "  $($i + 1)) $($browserDisponibili[$i].Nome)"
}
Write-Host ""
Write-Host "  T) Installa tutti"
Write-Host "  S) Salta"
Write-Host ""

$sceltaBrowser = Read-Host "Scelta (es: 1,2 oppure T per tutti oppure S per saltare)"

if ($sceltaBrowser -match "^[Ss]$") {
    Write-Info "Browser saltati."
} elseif ($sceltaBrowser -match "^[Tt]$") {
    if (Confirm-Winget) {
        foreach ($b in $browserDisponibili) { Installa-Pacchetto -Nome $b.Nome -WingetId $b.Id }
    } else {
        Write-Errore "Winget non disponibile."
    }
} else {
    $indici = $sceltaBrowser -split "," | ForEach-Object { $_.Trim() }
    if (Confirm-Winget) {
        foreach ($indice in $indici) {
            $num = 0
            if ($indice -match "^\d+$" -and [int]::TryParse($indice, [ref]$num)) {
                $idx = $num - 1
                if ($idx -ge 0 -and $idx -lt $browserDisponibili.Count) {
                    Installa-Pacchetto -Nome $browserDisponibili[$idx].Nome -WingetId $browserDisponibili[$idx].Id
                } else {
                    Write-Errore "Numero non valido: $indice"
                }
            } elseif ($indice -ne "") {
                Write-Errore "Valore non riconosciuto: $indice"
            }
        }
    } else {
        Write-Errore "Winget non disponibile."
    }
}

if (Continua) { $passo-- } else { $passo++ }
}
7 {
# =============================================================================
# STEP 6 - APPLICAZIONI BASE
# =============================================================================

Write-Titolo "STEP 6 - Applicazioni Base"

$appsDisponibili = @(
    @{ Nome = "VLC Media Player";   Id = "VideoLAN.VLC" },
    @{ Nome = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" },
    @{ Nome = "Sumatra PDF";        Id = "SumatraPDF.SumatraPDF" },
    @{ Nome = "Spotify";            Id = "Spotify.Spotify" },
    @{ Nome = "AIMP";               Id = "AIMP.AIMP" },
    @{ Nome = "7-Zip";              Id = "7zip.7zip" },
    @{ Nome = "WhatsApp";           Id = "9NKSQGP7F2NH" },
    @{ Nome = "GIMP";               Id = "GIMP.GIMP" },
    @{ Nome = "Steam";              Id = "Valve.Steam" },
    @{ Nome = "AnyDesk";            Id = "AnyDesk.AnyDesk" },
    @{ Nome = "TeamViewer";         Id = "TeamViewer.TeamViewer" },
    @{ Nome = "qBittorrent";        Id = "qBittorrent.qBittorrent" },
    @{ Nome = "Discord";            Id = "Discord.Discord" },
    @{ Nome = "Zoom";               Id = "Zoom.Zoom" }
)

# Preset profili: sottoinsiemi della lista sopra (per winget Id).
# I browser (Chrome/Firefox) restano nello STEP 5, qui non inclusi.
$profili = [ordered]@{
    "BASE"    = @("VideoLAN.VLC","Adobe.Acrobat.Reader.64-bit","7zip.7zip","9NKSQGP7F2NH","AnyDesk.AnyDesk","TeamViewer.TeamViewer")
    "UFFICIO" = @("VideoLAN.VLC","Adobe.Acrobat.Reader.64-bit","7zip.7zip","9NKSQGP7F2NH","AnyDesk.AnyDesk","TeamViewer.TeamViewer","Zoom.Zoom","Spotify.Spotify","GIMP.GIMP","SumatraPDF.SumatraPDF")
    "GAMING"  = @("VideoLAN.VLC","Adobe.Acrobat.Reader.64-bit","7zip.7zip","9NKSQGP7F2NH","AnyDesk.AnyDesk","TeamViewer.TeamViewer","Valve.Steam","Discord.Discord","qBittorrent.qBittorrent")
}

# Installa gli app della lista il cui Id e' nel set passato
function Installa-Set {
    param([string[]]$Ids)
    if (-not (Confirm-Winget)) { Write-Errore "Winget non disponibile."; return }
    foreach ($app in $appsDisponibili) {
        if ($Ids -contains $app.Id) {
            Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id
        }
    }
}

Write-Host "Scegli come installare le applicazioni:" -ForegroundColor White
Write-Host "  1) PROFILO BASE     (VLC, Adobe Reader, 7-Zip, WhatsApp, AnyDesk, TeamViewer)"
Write-Host "  2) PROFILO UFFICIO  (BASE + Zoom, Spotify, GIMP, Sumatra PDF)"
Write-Host "  3) PROFILO GAMING   (BASE + Steam, Discord, qBittorrent)"
Write-Host "  4) COMPLETO         (tutte le app in lista)"
Write-Host "  5) MANUALE          (scelgo io i singoli numeri)"
Write-Host "  S) Salta"
Write-Host ""

$sceltaApps = Read-Host "Scelta (1-5 oppure S)"

switch ($sceltaApps) {
    "1" { Installa-Set -Ids $profili["BASE"] }
    "2" { Installa-Set -Ids $profili["UFFICIO"] }
    "3" { Installa-Set -Ids $profili["GAMING"] }
    "4" {
        if (Confirm-Winget) {
            foreach ($app in $appsDisponibili) { Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id }
        } else {
            Write-Errore "Winget non disponibile."
        }
    }
    "5" {
        Write-Host ""
        Write-Host "App disponibili:" -ForegroundColor White
        for ($i = 0; $i -lt $appsDisponibili.Count; $i++) {
            Write-Host "  $($i + 1)) $($appsDisponibili[$i].Nome)"
        }
        $sceltaManuale = Read-Host "Numeri separati da virgola (es: 1,3,5)"
        $indici = $sceltaManuale -split "," | ForEach-Object { $_.Trim() }
        if (Confirm-Winget) {
            foreach ($indice in $indici) {
                $num = 0
                if ($indice -match "^\d+$" -and [int]::TryParse($indice, [ref]$num)) {
                    $idx = $num - 1
                    if ($idx -ge 0 -and $idx -lt $appsDisponibili.Count) {
                        Installa-Pacchetto -Nome $appsDisponibili[$idx].Nome -WingetId $appsDisponibili[$idx].Id
                    } else {
                        Write-Errore "Numero non valido: $indice"
                    }
                } elseif ($indice -ne "") {
                    Write-Errore "Valore non riconosciuto: $indice"
                }
            }
        } else {
            Write-Errore "Winget non disponibile."
        }
    }
    default {
        if ($sceltaApps -match "^[Ss]$") {
            Write-Info "Applicazioni saltate."
        } else {
            Write-Info "Scelta non valida: applicazioni saltate."
        }
    }
}

if (Continua) { $passo-- } else { $passo++ }
}
8 {
# =============================================================================
# STEP 7 - RIMOZIONE APP SUPERFLUE (BLOATWARE) - opzionale
# =============================================================================

Write-Titolo "STEP 7 - Rimozione App Superflue (Bloatware)"

Write-Host "Rimuove: bloatware del produttore (HP/Lenovo/Dell/Asus/Acer), app consumer" -ForegroundColor White
Write-Host "Microsoft (Bing, giochi, Clipchamp...), trial antivirus preinstallati, toolbar." -ForegroundColor White
Write-Host "NON tocca: Xbox, Spotify, Store, Foto, ne' i programmi installati in questo setup." -ForegroundColor White
Write-Host ""

# App Store (Appx) superflue. Wildcard sul nome. NON include Xbox ne' Spotify,
# ne' driver/stampante (uso pattern mirati sul bloatware, non l'intero publisher).
$bloatwareAppx = @(
    # --- Microsoft consumer / giochi ---
    "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.BingSearch",
    "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MixedReality.Portal",
    "Microsoft.People", "Microsoft.WindowsFeedbackHub",
    "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.Windows.DevHome",
    "Microsoft.Todos", "MicrosoftCorporationII.QuickAssist", "Clipchamp.Clipchamp",
    "king.com.*", "*.CandyCrush*",
    # --- Social/streaming preinstallati (terze parti) ---
    "*.Facebook", "*.Instagram", "*.TikTok", "*.Netflix", "*.DisneyPlus",
    "*.AmazonPrimeVideo", "*Booking*", "*.Twitter", "*ExpressVPN*",
    # --- HP ---
    "*SupportAssistant*", "*myHP*", "AD2F1837.HPPrivacySettings", "*HPJumpStart*",
    "*HPPCHardwareDiagnostics*", "*HPPowerManager*", "*HPQuickDrop*", "*HPSystemInformation*",
    "*HPWorkWell*", "*HPProgrammableKey*", "*HPDesktopSupportUtilities*",
    # --- Lenovo ---
    "*LenovoVantage*", "*LenovoCompanion*", "*LenovoUtility*", "*LenovoWelcome*",
    "*LenovoQuickClean*", "*LenovoNow*", "*LenovoSmartCommunication*",
    # --- Dell ---
    "*DellSupportAssist*", "*DellCustomerConnect*", "*DellDigitalDelivery*",
    "*DellUpdate*", "*DellOptimizer*", "*PartnerPromo*", "*DellPowerManager*",
    # --- Asus / Acer ---
    "*MyASUS*", "*ASUSPCAssistant*", "*ASUSGiftBox*", "*GlideX*", "*ASUSSplendid*",
    "*AcerCollection*", "*AcerRegistration*", "*AcerJumpstart*", "*AcerCareCenter*"
)

$vuoiDebloat = Read-Host "Rimuovere il bloatware elencato? (S/N)"
if ($vuoiDebloat -match "^[Ss]") {
    $rimosse = 0
    foreach ($pkg in $bloatwareAppx) {
        try {
            $trovati = Get-AppxPackage -AllUsers -Name $pkg -ErrorAction SilentlyContinue
            foreach ($t in $trovati) {
                Remove-AppxPackage -Package $t.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $rimosse++
            }
            # Rimuovi anche il provisioning: i nuovi utenti non le riavranno
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $pkg } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        } catch {}
    }

    # Trial antivirus + utility Win32 via winget.
    # GUARDIA: NON rimuovo l'antivirus che ho appena installato in questa sessione.
    $mcafeeNostro = @($Report | Where-Object { $_.Voce -like "McAfee*" -and $_.Esito -eq "OK" }).Count -gt 0
    $nortonNostro = @($Report | Where-Object { $_.Voce -like "Norton*" -and $_.Esito -eq "OK" }).Count -gt 0

    $trialWin32 = @("HP Support Assistant", "HP Documentation", "HP Sure Recover",
                    "WildTangent Games", "ExpressVPN", "Dropbox Promotion")
    if (-not $mcafeeNostro) {
        $trialWin32 += @("McAfee LiveSafe", "McAfee Total Protection", "McAfee Personal Security", "McAfee WebAdvisor", "McAfee Security")
    }
    if (-not $nortonNostro) {
        $trialWin32 += @("Norton 360", "Norton Security", "Norton")
    }

    if (Confirm-Winget) {
        foreach ($nome in $trialWin32) {
            try {
                winget uninstall --name $nome --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
            } catch {}
        }
    }

    Write-OK "Rimozione bloatware completata ($rimosse app Store + trial/utility Win32 via winget)."
    if ($mcafeeNostro -or $nortonNostro) {
        Write-Info "Antivirus installato in questa sessione mantenuto (non rimosso)."
    }
    Add-Report "Rimozione bloatware ($rimosse Store)" "OK"
} else {
    Write-Info "Rimozione bloatware saltata."
    Add-Report "Rimozione bloatware" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
9 {
# =============================================================================
# STEP 8 - AGGIORNAMENTO APP INSTALLATE - opzionale
# =============================================================================

Write-Titolo "STEP 8 - Aggiornamento App Installate"

Write-Host "Aggiorna all'ultima versione le app gestite da winget (incluse molte OEM)." -ForegroundColor White
Write-Host "Puo' richiedere diversi minuti. NB: i DRIVER si aggiornano da Windows Update." -ForegroundColor White
Write-Host ""

$vuoiUpgrade = Read-Host "Aggiornare ora tutte le app installate? (S/N)"
if ($vuoiUpgrade -match "^[Ss]") {
    if (Confirm-Winget) {
        Write-Info "Aggiornamento in corso (puo' richiedere diversi minuti)..."
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --include-unknown
        Write-OK "Aggiornamento app completato."
        Add-Report "Aggiornamento app installate" "OK"
    } else {
        Write-Errore "Winget non disponibile."
        Add-Report "Aggiornamento app installate" "ERRORE"
    }
} else {
    Write-Info "Aggiornamento app saltato."
    Add-Report "Aggiornamento app installate" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
10 {
# =============================================================================
# STEP 9 - CONFIGURAZIONE WINDOWS BASE - opzionale
# =============================================================================

Write-Titolo "STEP 9 - Configurazione Windows Base"

Write-Host "Piccole comodita': mostra le estensioni dei file, apre Esplora file su" -ForegroundColor White
Write-Host "'Questo PC' e disattiva l'avvio automatico di OneDrive." -ForegroundColor White
Write-Host ""

$vuoiConfig = Read-Host "Applicare queste impostazioni? (S/N)"
if ($vuoiConfig -match "^[Ss]") {
    try {
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $adv -Name "HideFileExt" -Value 0 -Type DWord -ErrorAction SilentlyContinue   # mostra estensioni
        Set-ItemProperty -Path $adv -Name "LaunchTo"    -Value 1 -Type DWord -ErrorAction SilentlyContinue   # Esplora su "Questo PC"

        # Disattiva l'avvio automatico di OneDrive (toglie la voce di avvio)
        $run = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        if (Get-ItemProperty -Path $run -Name "OneDrive" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $run -Name "OneDrive" -ErrorAction SilentlyContinue
        }

        Write-OK "Impostazioni applicate (attive al prossimo riavvio di Esplora file)."
        Add-Report "Configurazione Windows base" "OK"
    } catch {
        Write-Errore "Impossibile applicare alcune impostazioni: $_"
        Add-Report "Configurazione Windows base" "ERRORE"
    }
} else {
    Write-Info "Configurazione Windows base saltata."
    Add-Report "Configurazione Windows base" "SALTATO"
}

if (Continua) { $passo-- } else { $passo++ }
}
}
if ($passo -lt 0) { $passo = 0 }
}

# =============================================================================
# FINE
# =============================================================================

Write-Titolo "CONFIGURAZIONE COMPLETATA - REPORT"

if ($Report.Count -eq 0) {
    Write-Info "Nessuna operazione registrata."
} else {
    $nOk      = ($Report | Where-Object { $_.Esito -eq "OK" }).Count
    $nErrore  = ($Report | Where-Object { $_.Esito -eq "ERRORE" }).Count
    $nSaltato = ($Report | Where-Object { $_.Esito -eq "SALTATO" }).Count
    $nAvviso  = ($Report | Where-Object { $_.Esito -eq "AVVISO" }).Count

    foreach ($r in $Report) {
        switch ($r.Esito) {
            "OK"      { $colore = "Green" }
            "ERRORE"  { $colore = "Red" }
            default   { $colore = "Yellow" }
        }
        Write-Host ("  [{0,-8}] {1}" -f $r.Esito, $r.Voce) -ForegroundColor $colore
    }

    Write-Host ""
    Write-Host ("Totale: {0} OK, {1} ERRORE, {2} SALTATO, {3} AVVISO" -f $nOk, $nErrore, $nSaltato, $nAvviso) -ForegroundColor Cyan
    if ($nErrore -gt 0) {
        Write-Host "Controlla le voci in ERRORE prima di consegnare il PC." -ForegroundColor Red
    }
}

# UN SOLO file riepilogo, ordinato - solo run reale (Configura)
if ($RunReale) {
    try {
        $winOk   = @($Report | Where-Object { $_.Voce -eq 'Windows attivato' -and $_.Esito -eq 'OK' }).Count -gt 0
        $diskBad = @($Report | Where-Object { $_.Voce -eq 'Salute disco' -and $_.Esito -eq 'ERRORE' }).Count -gt 0
        $freeTxt = ""
        try { $freeTxt = "{0} GB liberi" -f [math]::Round((Get-PSDrive ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free / 1GB, 1) } catch {}

        $softwareOk = @($Report | Where-Object { $_.Voce -like '*installazione*' -and $_.Esito -eq 'OK' } |
                        ForEach-Object { ($_.Voce -replace ' \(installazione\)', '').Trim() })
        $av = @($Report | Where-Object { ($_.Voce -like '*antivirus*' -or $_.Voce -like '*protezione*') -and $_.Esito -eq 'OK' })
        $altre = @($Report | Where-Object { $_.Voce -notlike '*installazione*' -and $_.Voce -notlike '*antivirus*' -and $_.Voce -notlike '*protezione*' })

        $sep = "------------------------------------------------------------"
        $f = @()
        $f += "============================================================"
        $f += "   RIEPILOGO CONFIGURAZIONE PC"
        $f += "============================================================"
        $f += ""
        $f += "Data     : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
        $f += "Nome PC  : $env:COMPUTERNAME"
        $f += "Utente   : $env:USERNAME"
        $f += ""
        $f += $sep
        $f += "STATO SISTEMA"
        $f += $sep
        $f += "  Windows attivato : $(if ($winOk) { 'SI' } else { 'NO - da verificare' })"
        if ($freeTxt) { $f += "  Spazio disco C:  : $freeTxt" }
        $f += "  Salute dischi    : $(if ($diskBad) { 'ATTENZIONE: un disco non Healthy' } else { 'OK' })"
        if ($Global:HaBatteria) { $f += "  Batteria         : presente (laptop)" }
        $f += ""
        $f += $sep
        $f += "SOFTWARE INSTALLATO"
        $f += $sep
        if ($softwareOk.Count -gt 0) { foreach ($sw in $softwareOk) { $f += "  - $sw" } } else { $f += "  (nessuno)" }
        $f += ""
        $f += $sep
        $f += "ANTIVIRUS / PROTEZIONE"
        $f += $sep
        if ($av.Count -gt 0) { foreach ($a in $av) { $f += "  - $($a.Voce)" } } else { $f += "  (da verificare)" }
        $f += ""
        $f += $sep
        $f += "ALTRE OPERAZIONI"
        $f += $sep
        foreach ($r in $altre) { $f += ("  [{0,-8}] {1}" -f $r.Esito, $r.Voce) }
        $f += ""
        $f += $sep
        $f += "NOTE / CREDENZIALI (da compilare a mano)"
        $f += $sep
        $f += "  Account Microsoft : ______________________________"
        $f += "  Password          : ______________________________"
        # Campi dedicati per ogni antivirus/protezione attivato in questa sessione
        foreach ($a in $av) {
            $nomeSvc = ($a.Voce -replace ' \(antivirus\)', '' -replace ' \(protezione\)', '').Trim()
            $f += ""
            $f += "  [$nomeSvc]"
            $f += "  Email/utente account : ______________________________"
            $f += "  Password account     : ______________________________"
            $f += "  Codice/PIN licenza   : ______________________________"
            $f += "  Credenziali app      : ______________________________"
        }
        $f += ""
        $f += "  Altro             : ______________________________"
        $f += ""
        $f += "============================================================"
        $f += "PC Facile - versione $SCRIPT_VERSION"

        $riepFile = Join-Path (Get-DesktopDir) ("Riepilogo-PC_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmm"))
        $f | Set-Content -Path $riepFile -Encoding UTF8
        Write-OK "Riepilogo salvato sul Desktop: $riepFile"
    } catch {
        Write-Info "Impossibile creare il file riepilogo: $_"
    }
}

# Offri il riavvio se la lingua e' stata cambiata (serve reboot per applicarsi)
$linguaCambiata = @($Report | Where-Object { $_.Voce -like "Lingua italiana*" -and $_.Esito -eq "OK" }).Count -gt 0
Write-Host ""
if ($linguaCambiata) {
    Write-Info "La lingua e' stata cambiata: serve un RIAVVIO per applicarla del tutto."
    $riavvia = Read-Host "Riavviare il PC ora? (S/N)"
    if ($riavvia -match "^[Ss]") {
        Write-Info "Riavvio in corso..."
        Restart-Computer -Force
    } else {
        Write-Info "Ricordati di riavviare il PC prima di consegnarlo."
    }
}

Write-Host ""
Write-Host "Buon lavoro!" -ForegroundColor Cyan
Write-Host ""
Pausa
