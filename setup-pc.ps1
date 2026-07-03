# =============================================================================
# setup-pc.ps1 - Automazione Configurazione PC
# =============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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
    Write-Info "Riavvia PowerShell come amministratore e riprova."
    Pausa
    exit 1
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
        Write-Errore "Smart App Control ATTIVO: puo' bloccare script e installer scaricati."
        Write-Info "Per disattivarlo: Sicurezza di Windows > Controllo app e browser >"
        Write-Info "  Controllo intelligente delle app > Disattivato."
        Write-Info "ATTENZIONE: la disattivazione e' IRREVERSIBILE senza reinstallare Windows."
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
    Write-Info "Consiglio: usa Windows PowerShell 5.1 (Avvia.bat lo fa gia'). Su PowerShell 7"
    Write-Info "  l'installazione di riserva di winget (Add-AppxPackage) puo' non funzionare."
}

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
    Write-Info "Rimedi: tieni setup-pc.ps1 accanto ad Avvia.bat (evita GitHub); per le"
    Write-Info "  installazioni app usa un hotspot o una rete senza filtri."
    Add-Report "Rete: $bloccati servizio/i bloccato/i" "AVVISO"
    Pausa
} else {
    Write-OK "Tutti i servizi chiave sono raggiungibili."
}

# =============================================================================
# LOG SU FILE (registro per ogni PC)
# =============================================================================

# Registra tutto l'output della sessione in un file sul Desktop, utile come
# prova/archivio della configurazione fatta su quel PC cliente.
$Global:LogFile = Join-Path (Get-DesktopDir) ("setup-pc_log_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
try {
    Start-Transcript -Path $Global:LogFile -ErrorAction SilentlyContinue | Out-Null
} catch {
    $Global:LogFile = $null
}

# =============================================================================
# FUNZIONE: VERIFICA E INSTALLA WINGET
# =============================================================================

function Confirm-Winget {
    # Risultato calcolato una sola volta per sessione (evita ricontrolli/reinstalli)
    if ($null -ne $Global:WingetOk) { return $Global:WingetOk }

    Write-Info "Verifica presenza di Winget..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-OK "Winget trovato."
        $Global:WingetOk = $true
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

    $maxTentativi = 2
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
        if (-not (Test-Rete)) {
            Write-Info "Rete assente. Attendo 10s e riprovo..."
            Start-Sleep -Seconds 10
        } else {
            break  # errore non dovuto alla rete, inutile ritentare
        }
    }

    Write-Errore "$Nome NON installato (tentativi: $tentativiFatti)."
    Add-Report "$Nome (installazione)" "ERRORE"
}

# =============================================================================
# BENVENUTO
# =============================================================================

Clear-Host
Write-Titolo "AUTOMAZIONE CONFIGURAZIONE PC - Avvio"
Write-Host "Questo script guida la configurazione del PC del cliente passo per passo." -ForegroundColor White
Write-Host "Segui le istruzioni a schermo e premi INVIO quando indicato." -ForegroundColor White
Pausa

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

Pausa

# =============================================================================
# STEP 1 - NOME CLIENTE
# =============================================================================

Write-Titolo "STEP 1 - Nome Completo Cliente"

# Get-LocalUser puo' fallire (account Microsoft/dominio, modulo assente): protetto
$nomeAttuale = $null
try {
    $nomeAttuale = (Get-LocalUser -Name $env:USERNAME -ErrorAction Stop).FullName
} catch {
    Write-Info "Impossibile leggere il nome attuale (account non locale?): proseguo."
}
Write-Info "Utente corrente: $env:USERNAME"
Write-Info "Nome visualizzato attuale: $(if ($nomeAttuale) { $nomeAttuale } else { '(non impostato)' })"
Write-Host ""

$nomeCliente = Read-Host "Inserisci il nome completo del cliente (es. Mario Rossi)"

if ($nomeCliente.Trim() -ne "") {
    try {
        Set-LocalUser -Name $env:USERNAME -FullName $nomeCliente.Trim() -ErrorAction Stop
        Write-OK "Nome utente aggiornato a: $($nomeCliente.Trim())"
        Add-Report "Nome cliente" "OK"
    } catch {
        Write-Errore "Impossibile aggiornare il nome (account Microsoft/dominio?): $_"
        Add-Report "Nome cliente" "ERRORE"
    }
} else {
    Write-Info "Nome non modificato."
    Add-Report "Nome cliente" "SALTATO"
}

Pausa

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

Pausa

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
        Write-Errore "Scelta non valida. Passaggio saltato."
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

Pausa

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
    $cartelle = @((Join-Path $env:USERPROFILE "Downloads"), (Get-DesktopDir)) | Select-Object -Unique
    $recente = Get-ChildItem -Path $cartelle -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-20) } |
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
        Write-Info "Nessun .exe recente (ultimi 20 min) in Download o Desktop."
        Write-Info "Avvia l'installer $Nome manualmente."
        Add-Report "$Nome (antivirus)" "ERRORE"
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
        Write-Errore "Scelta non valida. Passaggio saltato."
        Add-Report "Antivirus" "SALTATO"
    }
}

Pausa

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

Pausa

# =============================================================================
# STEP 5 - BROWSER
# =============================================================================

Write-Titolo "STEP 5 - Browser"

$wingetOk = Confirm-Winget

$installaChrome = Read-Host "Installare Google Chrome? (S/N)"
if ($installaChrome -match "^[Ss]") {
    if ($wingetOk) {
        Installa-Pacchetto -Nome "Google Chrome" -WingetId "Google.Chrome"
    } else {
        Write-Errore "Winget non disponibile. Installa Chrome manualmente."
    }
} else {
    Write-Info "Chrome saltato."
}

Write-Host ""

$installaFirefox = Read-Host "Installare Mozilla Firefox? (S/N)"
if ($installaFirefox -match "^[Ss]") {
    if ($wingetOk) {
        Installa-Pacchetto -Nome "Mozilla Firefox" -WingetId "Mozilla.Firefox"
    } else {
        Write-Errore "Winget non disponibile. Installa Firefox manualmente."
    }
} else {
    Write-Info "Firefox saltato."
}

Pausa

# =============================================================================
# STEP 6 - APPLICAZIONI BASE
# =============================================================================

Write-Titolo "STEP 6 - Applicazioni Base"

$appsDisponibili = @(
    @{ Nome = "VLC Media Player";   Id = "VideoLAN.VLC" },
    @{ Nome = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" },
    @{ Nome = "Spotify";            Id = "Spotify.Spotify" },
    @{ Nome = "7-Zip";              Id = "7zip.7zip" },
    @{ Nome = "WhatsApp";           Id = "9NKSQGP7F2NH" },
    @{ Nome = "Steam";              Id = "Valve.Steam" },
    @{ Nome = "AnyDesk";            Id = "AnyDeskSoftwareGmbH.AnyDesk" },
    @{ Nome = "Discord";            Id = "Discord.Discord" },
    @{ Nome = "Zoom";               Id = "Zoom.Zoom" }
)

# Preset profili: sottoinsiemi della lista sopra (per winget Id).
# I browser (Chrome/Firefox) restano nello STEP 5, qui non inclusi.
$profili = [ordered]@{
    "BASE"    = @("VideoLAN.VLC","Adobe.Acrobat.Reader.64-bit","7zip.7zip","9NKSQGP7F2NH","AnyDeskSoftwareGmbH.AnyDesk")
    "UFFICIO" = @("VideoLAN.VLC","Adobe.Acrobat.Reader.64-bit","7zip.7zip","9NKSQGP7F2NH","AnyDeskSoftwareGmbH.AnyDesk","Zoom.Zoom","Spotify.Spotify")
    "GAMING"  = @("VideoLAN.VLC","Adobe.Acrobat.Reader.64-bit","7zip.7zip","9NKSQGP7F2NH","AnyDeskSoftwareGmbH.AnyDesk","Valve.Steam","Discord.Discord")
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
Write-Host "  1) PROFILO BASE     (VLC, Adobe Reader, 7-Zip, WhatsApp, AnyDesk)"
Write-Host "  2) PROFILO UFFICIO  (BASE + Zoom, Spotify)"
Write-Host "  3) PROFILO GAMING   (BASE + Steam, Discord)"
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

Pausa

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

# Salva il report anche su file di testo (riepilogo leggibile da archiviare)
try {
    $reportFile = Join-Path (Get-DesktopDir) ("setup-pc_report_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $righe = @("REPORT CONFIGURAZIONE PC - $(Get-Date -Format 'dd/MM/yyyy HH:mm')", "PC: $env:COMPUTERNAME", "")
    foreach ($r in $Report) { $righe += ("[{0,-8}] {1}" -f $r.Esito, $r.Voce) }
    $righe | Set-Content -Path $reportFile -Encoding UTF8
    Write-OK "Report salvato in: $reportFile"
} catch {
    Write-Info "Impossibile salvare il report su file: $_"
}

# Chiudi il log della sessione
try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
if ($Global:LogFile) { Write-Info "Log completo sessione: $Global:LogFile" }

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
