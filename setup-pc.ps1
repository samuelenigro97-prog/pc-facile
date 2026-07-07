# =============================================================================
# setup-pc.ps1 - Automazione Configurazione PC
# =============================================================================

param(
    # Modalita' non interattiva: risponde in automatico e NON installa/modifica nulla.
    # Uso: powershell -ExecutionPolicy Bypass -File setup-pc.ps1 -Test
    [switch]$Test,
    # Diagnostica: controlla ambiente e valida gli ID pacchetti (winget show),
    # senza installare nulla, e mostra cosa e' OK/KO. -File setup-pc.ps1 -Diagnostica
    [switch]$Diagnostica,
    # Veloce: Configura automatica col profilo tipico del negozio. Chiede SOLO
    # le 3 cose che cambiano per cliente (nome, antivirus, profilo app); tutto
    # il resto risponde in automatico. -File setup-pc.ps1 -Veloce
    [switch]$Veloce
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Versione del programma (mostrata nell'header e nel riepilogo).
# Bump ad ogni modifica cosi' capisci se la USB e' aggiornata.
$SCRIPT_VERSION = "4.5 (2026-07-07)"

# Simboli di stato e grafica costruiti a runtime con [char]: NON dipendono
# dall'encoding con cui PowerShell legge questo file (5.1 senza BOM li
# storpierebbe). L'output e' gia' UTF-8 (impostato sopra), quindi si vedono.
$SYM_OK    = [char]0x2713                  # spunta
$SYM_ERR   = [char]0x2717                  # croce
$SYM_INFO  = [char]0x2192                  # freccia
$BOX_FULL  = [char]0x2588                  # blocco pieno (barra progresso)
$BOX_EMPTY = [char]0x2591                  # blocco leggero (barra progresso)
$LINEA_D   = ([string][char]0x2550) * 60   # linea doppia orizzontale

# Tema colori: Unieuro = ARANCIONE (#EE7203) + navy + bianco.
# La console conhost (parte col doppio-click del .bat) ha solo 16 colori con
# nome e NON ha l'arancione. Per l'arancione ESATTO servono le sequenze ANSI
# truecolor (24-bit), che pero' funzionano solo se il "Virtual Terminal" e'
# abilitato. Lo abilitiamo SENZA P/Invoke (vietato: l'antivirus lo segnala)
# scrivendo la chiave di registro HKCU\Console\VirtualTerminalLevel=1, che
# conhost legge all'avvio di ogni nuova finestra.
#
# Logica: se il VT risulta gia' abilitato -> uso l'arancione vero via ANSI
# ($AON/$AOFF avvolgono il testo). Altrimenti fallback pulito su 'DarkYellow'
# (ambra, l'arancio piu' vicino tra i 16 nomi). In piu' scriviamo la chiave,
# cosi' dai lanci successivi su quel PC parte l'arancione vero.
$THEME_TXT = "White"    # testo dei titoli (bianco, come il payoff del logo)

# La chiave vale per le finestre APERTE DOPO averla scritta: il primo giro su
# un PC nuovo puo' essere ancora ambra, i successivi arancione.
try {
    if (-not (Test-Path 'HKCU:\Console')) { New-Item -Path 'HKCU:\Console' -Force | Out-Null }
    Set-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -Value 1 -Type DWord -ErrorAction Stop
    # Rimappa lo slot "DarkBlue" (indice 1) al navy SCURO #0A0E24, cosi' lo
    # sfondo blu e' un navy vero e non il DarkBlue acceso di default. DWORD in
    # formato 0x00BBGGRR = 0x00240E0A. Vale dalle finestre aperte dopo.
    Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable01' -Value 0x00240E0A -Type DWord -ErrorAction SilentlyContinue
} catch {}

# Rileva se il VT e' attivo per QUESTA finestra (chiave gia' presente al lancio).
$vtOn = $false
try { $vtOn = ((Get-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -ErrorAction Stop).VirtualTerminalLevel -eq 1) } catch {}

if ($vtOn) {
    $ESC       = [char]27
    $AON       = "$ESC[38;2;238;114;3m"   # arancione Unieuro #EE7203 (foreground)
    $AOFF      = "$ESC[0m"                  # reset
    $THEME_COL = "White"   # colore -ForegroundColor "di riserva"; l'ANSI ha priorita'
} else {
    $AON       = ""
    $AOFF      = ""
    $THEME_COL = "DarkYellow"   # ambra: fallback quando l'arancione vero non e' disponibile
}

# Sfondo blu navy come nel logo Unieuro. La console dipinge lo sfondo col
# colore NOMINATO (l'RGB esatto non e' impostabile senza P/Invoke): 'DarkBlue'
# e' il navy della palette. Il testo di default va su grigio chiaro cosi' resta
# leggibile. Impostato una volta qui: ogni Clear-Host successivo ridipinge navy.
try {
    $Host.UI.RawUI.BackgroundColor = 'DarkBlue'
    $Host.UI.RawUI.ForegroundColor = 'Gray'
    Clear-Host
} catch {}

# =============================================================================
# FUNZIONI UTILITY
# =============================================================================

function Write-Titolo {
    param([string]$Testo)
    Write-Host ""
    Write-Host "$AON  $LINEA_D$AOFF" -ForegroundColor $THEME_COL
    Write-Host "   $Testo" -ForegroundColor $THEME_TXT
    Write-Host "$AON  $LINEA_D$AOFF" -ForegroundColor $THEME_COL
    Write-Host ""
}

function Write-OK {
    param([string]$Testo)
    Write-Host "   $SYM_OK  $Testo" -ForegroundColor Green
}

function Write-Info {
    param([string]$Testo)
    Write-Host "   $SYM_INFO  $Testo" -ForegroundColor Yellow
}

function Write-Errore {
    param([string]$Testo)
    Write-Host "   $SYM_ERR  $Testo" -ForegroundColor Red
}

function Pausa {
    Write-Host ""
    Read-Host "Premi INVIO per continuare"
}

# Avviso sonoro a fine passo (utile se ti distrai durante installazioni/download).
# [console]::Beep e' un metodo .NET gestito: NON e' P/Invoke, l'antivirus non lo
# segnala. Solo nel run reale (niente bip durante Test/Diagnostica/CI headless).
function Beep-Fine {
    param([int]$Freq = 880, [int]$Dur = 180)
    if ($RunReale) { try { [console]::Beep($Freq, $Dur) } catch {} }
}
# Melodia breve di "tutto finito" (due toni), distinta dal bip di fine passo.
function Beep-Completato {
    if ($RunReale) { try { [console]::Beep(784, 160); [console]::Beep(1047, 260) } catch {} }
}

# Password = nome cliente + "123!" (sempre, cosi' e' prevedibile e facile da
# dettare). Es. "Rossi" -> "Rossi123!". Ha maiuscola, minuscole, cifre e simbolo
# -> soddisfa i requisiti Microsoft. Lo SCRIPT la costruisce (quindi la conosce
# e la scrive nel riepilogo): NON legge nulla dal browser.
function New-PasswordCliente {
    param([string]$Base)
    $b = ($Base -replace '[^A-Za-z]', '')
    if ($b.Length -lt 1) { $b = "Cliente" }
    $b = $b.Substring(0, 1).ToUpper() + $b.Substring(1).ToLower()
    return "${b}123!"
}

# Email suggerita per un nuovo account (outlook.com) dal nome cliente + numero.
function New-EmailCliente {
    param([string]$Base)
    $e = ($Base -replace '[^A-Za-z0-9]', '').ToLower()
    if (-not $e) { $e = "cliente" }
    if ($e.Length -gt 15) { $e = $e.Substring(0, 15) }
    return "$e$(Get-Random -Minimum 10 -Maximum 999)@outlook.com"
}

# Rileva una GPU NVIDIA: serve a capire se e' un PC da gaming e installare l'app
# GeForce (che tiene aggiornati i driver video). Get-CimInstance e' standard,
# niente P/Invoke.
function Test-GpuNvidia {
    try {
        return @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'NVIDIA|GeForce|RTX|GTX' }).Count -gt 0
    } catch { return $false }
}

# Chiede un valore all'operatore, MA in modalita' Veloce risponde da solo con
# $Auto (senza fermarsi): cosi' il preset Veloce salta le domande che non
# cambiano da PC a PC. Le 3 domande che restano sempre interattive (nome,
# antivirus, profilo app) usano Read-Host normale, non questa.
function Chiedi {
    param([string]$Prompt, [string]$Auto = "S")
    if ($Veloce) {
        Write-Host "  $Prompt  [Veloce => '$Auto']" -ForegroundColor Gray
        return $Auto
    }
    return Read-Host $Prompt
}

# Recupera la chiave di ripristino BitLocker del volume di sistema.
# ATTENZIONE - DATO SENSIBILE: la recovery key da' accesso COMPLETO al disco
# cifrato. Finisce nel file riepilogo che RESTA con la macchina/cliente: e'
# voluto e necessario (Windows 11 attiva da solo la crittografia del dispositivo;
# senza questa chiave, dopo un reset o un cambio hardware il cliente resta
# chiuso fuori dai suoi dati). Non va mai pubblicata/condivisa altrove.
# Ritorna un oggetto: Volume, Cifrato, Stato, KeyId, RecoveryKey, Esito, Messaggio.
function Get-BitLockerRecovery {
    param([string]$Volume = $env:SystemDrive)   # es. "C:"

    $r = [ordered]@{
        Volume = $Volume; Cifrato = $false; Stato = "sconosciuto"
        KeyId = ""; RecoveryKey = ""; Esito = "SALTATO"; Messaggio = ""
    }

    # 1) Cmdlet BitLocker (Windows Pro/Enterprise): oggetti puliti, niente parsing.
    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $blv = Get-BitLockerVolume -MountPoint $Volume -ErrorAction Stop
            $r.Stato   = "$($blv.VolumeStatus) / Protezione: $($blv.ProtectionStatus)"
            $r.Cifrato = ($blv.VolumeStatus -ne 'FullyDecrypted')
            # Anche se la protezione e' SOSPESA, il RecoveryPassword protector c'e'
            # ancora: lo prendiamo comunque.
            $rp = $blv.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
            if ($rp) {
                $r.KeyId       = "$($rp.KeyProtectorId)".Trim('{', '}')
                $r.RecoveryKey = "$($rp.RecoveryPassword)".Trim()
            }
        }
    } catch {
        $r.Messaggio = "cmdlet BitLocker non riusciti: $_"
    }

    # 2) Fallback manage-bde (Windows Home: niente cmdlet BitLocker). NON parso le
    #    stringhe localizzate: estraggo con REGEX il GUID e la chiave a 48 cifre,
    #    che sono uguali in ogni lingua.
    if (-not $r.RecoveryKey) {
        try {
            $out = & manage-bde -protectors -get $Volume -Type RecoveryPassword 2>$null | Out-String
            if ($out) {
                $mKey = [regex]::Match($out, '\d{6}(?:-\d{6}){7}')
                $mId  = [regex]::Match($out, '\{?([0-9A-Fa-f]{8}-(?:[0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12})\}?')
                if ($mKey.Success) { $r.RecoveryKey = $mKey.Value; $r.Cifrato = $true }
                if ($mId.Success)  { $r.KeyId = $mId.Groups[1].Value }
                if ($r.Stato -eq 'sconosciuto') { $r.Stato = "rilevato via manage-bde" }
            }
        } catch {
            $r.Messaggio = "manage-bde non riuscito: $_"
        }
    }

    # Esito coerente con Add-Report (OK / AVVISO / SALTATO):
    if ($r.RecoveryKey) {
        $r.Esito = "OK"; $r.Messaggio = "chiave trovata e salvata nel riepilogo"
    } elseif (-not $r.Cifrato) {
        $r.Esito = "SALTATO"; $r.Messaggio = "volume non cifrato: nessuna chiave da salvare"
    } else {
        $r.Esito = "AVVISO"
        if (-not $r.Messaggio) { $r.Messaggio = "volume cifrato ma nessuna RecoveryPassword rilevata" }
    }

    return [pscustomobject]$r
}

# Menu iniziale: se non e' stata scelta una modalita' via parametro, la chiedo.
# Un solo tasto, senza INVIO: D=diagnostica, T=test, C/INVIO/altro=configura.
if (-not $Test -and -not $Diagnostica) {
    try { Clear-Host } catch {}
    $larg = 56
    $titoloB = "PC FACILE   -   versione $SCRIPT_VERSION"
    $padSx = [int](($larg - $titoloB.Length) / 2)
    $padDx = $larg - $padSx - $titoloB.Length
    Write-Host ("$AON  " + [char]0x2554 + (([string][char]0x2550) * $larg) + [char]0x2557 + "$AOFF") -ForegroundColor $THEME_COL
    Write-Host ("  " + [char]0x2551 + (" " * $padSx) + $titoloB + (" " * $padDx) + [char]0x2551) -ForegroundColor $THEME_TXT
    Write-Host ("$AON  " + [char]0x255A + (([string][char]0x2550) * $larg) + [char]0x255D + "$AOFF") -ForegroundColor $THEME_COL
    Write-Host ""
    Write-Host "  Premi un tasto:" -ForegroundColor White
    Write-Host ""
    Write-Host "$AON    [C]$AOFF" -ForegroundColor $THEME_COL -NoNewline; Write-Host " Configura il PC   (installa e imposta, chiede tutto)" -ForegroundColor White
    Write-Host "$AON    [V]$AOFF" -ForegroundColor $THEME_COL -NoNewline; Write-Host " Veloce            (automatico: chiede solo nome, antivirus, app)" -ForegroundColor White
    Write-Host "$AON    [D]$AOFF" -ForegroundColor $THEME_COL -NoNewline; Write-Host " Diagnostica       (controlla, NON installa)" -ForegroundColor White
    Write-Host "$AON    [T]$AOFF" -ForegroundColor $THEME_COL -NoNewline; Write-Host " Test a vuoto      (percorre tutto, NON installa)" -ForegroundColor White
    Write-Host ""
    Write-Host "  (C oppure INVIO = Configura)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  LEGENDA TASTI:" -ForegroundColor White
    Write-Host "    Nei menu     : premi la LETTERA o il NUMERO indicato" -ForegroundColor Gray
    Write-Host "    Nelle domande: S = si, N = no" -ForegroundColor Gray
    Write-Host "    Fine passo   : si avanza automaticamente" -ForegroundColor Gray
    Write-Host "    Per uscire   : chiudi la finestra" -ForegroundColor Gray

    $tasto = ""
    try {
        $k = [Console]::ReadKey($true)     # legge UN tasto, senza bisogno di INVIO
        $tasto = "$($k.KeyChar)".ToUpper()
    } catch {
        $tasto = (Read-Host "Scelta (C/D/T)").ToUpper()   # fallback se ReadKey non disponibile
    }
    if ($tasto -eq "D" -or $tasto -eq "2") { $Diagnostica = $true; Write-Host "$AON  -> Diagnostica$AOFF" -ForegroundColor $THEME_COL }
    elseif ($tasto -eq "T" -or $tasto -eq "3") { $Test = $true; Write-Host "$AON  -> Test a vuoto$AOFF" -ForegroundColor $THEME_COL }
    elseif ($tasto -eq "V" -or $tasto -eq "4") { $Veloce = $true; Write-Host "$AON  -> Veloce (automatico)$AOFF" -ForegroundColor $THEME_COL }
    else { Write-Host "$AON  -> Configura il PC$AOFF" -ForegroundColor $THEME_COL }
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
        Write-Host "$Prompt [AUTO => '$risposta']" -ForegroundColor Gray
        return $risposta
    }
    function Pausa { }
}

# Modalita' VELOCE: e' una Configura reale (installa davvero), ma NON si ferma
# alle pause tra le sezioni, cosi' scorre da sola. Le domande le gestisce
# 'Chiedi' (auto) tranne nome/antivirus/app, che restano vere Read-Host.
if ($Veloce -and -not $Test -and -not $Diagnostica) {
    Write-Host "*** MODALITA' VELOCE: automatica, chiede solo nome, antivirus e app ***" -ForegroundColor Magenta
    function Pausa { }
}

# Run "reale" = Configura (non Test, non Diagnostica): solo qui si creano i
# file su Desktop (log/report/scheda/batteria), per non sporcare coi controlli.
$RunReale = (-not $Test -and -not $Diagnostica)

# Credenziali del nuovo account, generate dallo script allo step Account
# Microsoft e scritte nel riepilogo. Init qui cosi' esistono anche se quel
# passo viene saltato (restano vuote nel file).
$credMsAccount = ""; $credMsPassword = ""; $credAltro = ""

# =============================================================================
# CATALOGO PACCHETTI - UNICA FONTE (usato da STEP 3/5/6 e dalla Diagnostica)
# Cambi un ID QUI e vale ovunque. Profili: BASE / UFFICIO / GAMING.
# =============================================================================
$CatalogoOffice = @(
    @{ Nome = "Microsoft 365"; Id = "Microsoft.Office" },
    @{ Nome = "OpenOffice";    Id = "Apache.OpenOffice" },
    @{ Nome = "LibreOffice";   Id = "TheDocumentFoundation.LibreOffice" }
)
$CatalogoBrowser = @(
    @{ Nome = "Google Chrome";   Id = "Google.Chrome" },
    @{ Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
    @{ Nome = "Microsoft Edge";  Id = "Microsoft.Edge" },
    @{ Nome = "Brave";           Id = "Brave.Brave" },
    @{ Nome = "Opera";           Id = "Opera.Opera" },
    @{ Nome = "Opera GX";        Id = "Opera.OperaGX" },
    @{ Nome = "Vivaldi";         Id = "Vivaldi.Vivaldi" }
)
$CatalogoApp = @(
    @{ Nome = "VLC Media Player";     Id = "VideoLAN.VLC";                 Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit";  Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "Sumatra PDF";          Id = "SumatraPDF.SumatraPDF";        Profili = @("UFFICIO") },
    @{ Nome = "Spotify";              Id = "Spotify.Spotify";              Profili = @("UFFICIO") },
    @{ Nome = "AIMP";                 Id = "AIMP.AIMP";                    Profili = @() },
    @{ Nome = "7-Zip";                Id = "7zip.7zip";                    Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "WhatsApp";             Id = "9NKSQGP7F2NH";                 Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "GIMP";                 Id = "GIMP.GIMP";                    Profili = @("UFFICIO") },
    @{ Nome = "Steam";                Id = "Valve.Steam";                  Profili = @("GAMING") },
    @{ Nome = "Epic Games Launcher";  Id = "EpicGames.EpicGamesLauncher";  Profili = @("GAMING") },
    @{ Nome = "AnyDesk";              Id = "AnyDesk.AnyDesk";              Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "TeamViewer";           Id = "TeamViewer.TeamViewer";        Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "qBittorrent";          Id = "qBittorrent.qBittorrent";      Profili = @("GAMING") },
    @{ Nome = "Discord";              Id = "Discord.Discord";              Profili = @("GAMING") },
    @{ Nome = "Zoom";                 Id = "Zoom.Zoom";                    Profili = @("UFFICIO") }
)

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

# Evita la sospensione durante le installazioni (solo con alimentatore collegato).
# Uso powercfg (strumento standard) invece di P/Invoke a kernel32, che gli
# antivirus segnalano come falso positivo (ScriptContainsMaliciousContent).
try {
    & powercfg /change standby-timeout-ac 0 2>$null | Out-Null
    & powercfg /change monitor-timeout-ac 0 2>$null | Out-Null
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
    # NB: PendingFileRenameOperations NON e' piu' un segnale: su PC appena
    # installati da USB e' quasi sempre popolato con rinomine innocue e dava
    # un falso "riavvio in sospeso". Restano le due chiavi CBS/WindowsUpdate.
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

    # Disambigua SEMPRE la sorgente: ID Microsoft Store (12 caratteri) -> msstore,
    # tutto il resto -> winget. Senza --source, winget da' errore -1978335138
    # ("specify --source") quando lo stesso ID compare in piu' sorgenti, ed evita
    # anche di interrogare msstore (dove capitano errori di certificato/CDN).
    $sorgente = @()
    if ($WingetId -match '^[A-Z0-9]{12}$') { $sorgente = @('--source', 'msstore') }
    else { $sorgente = @('--source', 'winget') }

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

        # Tutti gli ID pacchetti: derivati dal CATALOGO unico (Office + Browser + App)
        $tuttiId = $CatalogoOffice + $CatalogoBrowser + $CatalogoApp

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
                if ($gia) { Write-OK "OK   $($p.Nome)  [gia' installato]"; $installati++ }
                else { Write-OK "OK   $($p.Nome)  [$($p.Id)]" }
            } else {
                Write-Errore "KO   $($p.Nome)  [$($p.Id)]  (codice $LASTEXITCODE)"
                $ko++
            }
        }
        Write-Host ""
        Write-Host ("Riepilogo pacchetti: {0} validi, {1} KO, {2} gia' installati (su {3})" -f ($tuttiId.Count - $ko), $ko, $installati, $tuttiId.Count) -ForegroundColor $THEME_TXT
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
# La scelta [C] Configura nel menu iniziale e' gia' la conferma: si parte
# diretti. Ogni singolo passo chiede comunque S/N, niente modifiche a sorpresa.

# =============================================================================
# LINGUA E REGIONE (ITALIANO) - primo passo
# =============================================================================

Write-Titolo "Lingua e Regione (Italiano)"

Write-Host "I PC installati da chiavetta partono spesso in INGLESE." -ForegroundColor White
Write-Host "Questo passaggio imposta display, formati, tastiera e language pack in it-IT." -ForegroundColor White
Write-Host ""

$culturaAttuale = (Get-Culture).Name
Write-Info "Lingua/regione attuale: $culturaAttuale"

$impostaLingua = Chiedi "Impostare il sistema in Italiano (it-IT)? (S/N)" "S"
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

    # Fuso orario Italia (CET) + orologio sincronizzato
    try {
        Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop
        Write-OK "Fuso orario impostato su Italia (CET)."
    } catch {
        Write-Info "Impostazione fuso orario non riuscita: proseguo."
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
        $apriImp = Chiedi "Aprire ora Impostazioni lingua per aggiungere/verificare l'Italiano? (S/N)" "N"
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

# Pausa per leggere l'esito solo se ho impostato la lingua; con N vado dritto.
if ($impostaLingua -match "^[Ss]") { Pausa }

# =============================================================================
# NOME CLIENTE E PC (prima voce dopo la lingua: la prima cosa da impostare)
# Un solo nome: vale sia per l'account Windows sia per il nome del PC.
# =============================================================================

Write-Titolo "Nome Cliente e PC"

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
Write-Info "Nome PC attuale: $env:COMPUTERNAME"
Write-Host ""
$nomeCliente = (Read-Host "Nome del cliente (account E nome PC) - INVIO per saltare").Trim()

if ($nomeCliente -ne "") {
    $nomeOk = $false
    # 1) Metodo moderno (modulo LocalAccounts, disponibile solo in PowerShell 64-bit)
    try {
        Set-LocalUser -Name $env:USERNAME -FullName $nomeCliente -ErrorAction Stop
        $nomeOk = $true
    } catch {
        # 2) Fallback ADSI/WinNT: funziona anche in x86 e senza il modulo LocalAccounts
        try {
            $u = [ADSI]$adsiUser
            $u.FullName = $nomeCliente
            $u.SetInfo()
            $nomeOk = $true
        } catch {}
    }
    if ($nomeOk) {
        Write-OK "Nome account aggiornato a: $nomeCliente"
        Add-Report "Nome cliente" "OK"
    } else {
        Write-Errore "Impossibile aggiornare il nome visualizzato dell'account $env:USERNAME."
        Add-Report "Nome cliente" "ERRORE"
    }

    # Stesso nome anche per il PC (hostname): solo A-Z 0-9 e trattino, max 15 char.
    $pcNuovo = ($nomeCliente -replace '[^A-Za-z0-9-]', '')
    if ($pcNuovo.Length -gt 15) { $pcNuovo = $pcNuovo.Substring(0, 15) }
    if ($pcNuovo -ne "" -and $pcNuovo -ne $env:COMPUTERNAME) {
        try {
            Rename-Computer -NewName $pcNuovo -Force -ErrorAction Stop
            Write-OK "PC rinominato in '$pcNuovo' (attivo dopo il riavvio)."
            Add-Report "Rinomina PC ($pcNuovo)" "OK"
        } catch {
            Write-Errore "Impossibile rinominare il PC: $_"
            Add-Report "Rinomina PC" "ERRORE"
        }
    }
} else {
    Write-Info "Nome non modificato (account e PC invariati)."
    Add-Report "Nome cliente" "SALTATO"
}

if ($nomeCliente -ne "") { Pausa }

# =============================================================================
# PUNTO DI RIPRISTINO (rete di sicurezza prima delle modifiche)
# =============================================================================

Write-Titolo "Punto di Ripristino"

Write-Host "Crea un punto di ripristino: se qualcosa va storto puoi tornare indietro." -ForegroundColor White
Write-Host ""

$vuoiRestore = Chiedi "Creare un punto di ripristino ora? (consigliato) (S/N)" "S"
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

if ($vuoiRestore -match "^[Ss]") { Pausa }

# =============================================================================
# ACCOUNT MICROSOFT (accedi/crea presto: velocizza Office e antivirus dopo)
# =============================================================================

Write-Titolo "Account Microsoft"

Write-Host "Accedi (o crea) l'account Microsoft ORA: la sessione resta attiva nel" -ForegroundColor White
Write-Host "browser, cosi' dopo su Office e antivirus fai 'Accedi con Microsoft' al volo." -ForegroundColor White
Write-Host ""

$vuoiMs = Chiedi "Aprire il login account Microsoft ora? (S/N)" "S"
if ($vuoiMs -match "^[Ss]") {
    Start-Process "https://account.microsoft.com"
    Write-OK "Aperto account.microsoft.com nel browser."

    # Credenziali per il riepilogo. Due casi:
    #  - il cliente ha GIA' una sua email/password che usa -> le inserisci tu
    #    (le detta lui) e finiscono nel riepilogo;
    #  - account NUOVO -> le genera lo script (email + Nome123!).
    # In entrambi i casi niente lette dal browser. Questa domanda resta anche in
    # Veloce perche' cambia da cliente a cliente.
    if ($RunReale) {
        $haAccount = Read-Host "Il cliente ha GIA' una sua email/password che usa? (S = le inserisco io / N = ne genero una nuova)"
        if ($haAccount -match "^[Ss]") {
            $credMsAccount  = (Read-Host "  Email del cliente").Trim()
            $credMsPassword = (Read-Host "  Password del cliente").Trim()
            Write-OK "Uso le credenziali del cliente (finiscono nel riepilogo)."
        } else {
            $credMsAccount  = New-EmailCliente -Base $nomeCliente
            $credMsPassword = New-PasswordCliente -Base $nomeCliente
            Write-Host ""
            Write-Host "  Credenziali SUGGERITE per il nuovo account (gia' nel riepilogo):" -ForegroundColor White
            Write-Info  "Email suggerita : $credMsAccount"
            Write-Info  "Password        : $credMsPassword"
            Write-Host "  Se in registrazione ne usi altre, correggi il file." -ForegroundColor Gray
        }
        # In tutti e due i casi copio la password negli appunti (Ctrl+V veloce).
        if ($credMsPassword) { try { Set-Clipboard -Value $credMsPassword; Write-Info "Password copiata negli appunti." } catch {} }
        Write-Host ""
    }

    Write-Info "Accedi o crea l'account, poi torna qui. Usa lo stesso browser per i login dopo."
    Add-Report "Account Microsoft" "OK"
} else {
    Write-Info "Account Microsoft saltato."
    Add-Report "Account Microsoft" "SALTATO"
}

if ($vuoiMs -match "^[Ss]") { Pausa }

# =============================================================================
# ATTIVAZIONE OFFICE (subito dopo l'account Microsoft: si riscatta/attiva)
# =============================================================================

Write-Titolo "Attivazione Office"

Write-Host "Su quasi tutti i PC nuovi Office/M365 e' GIA' installato: qui ATTIVI la licenza." -ForegroundColor White
Write-Host "  1) Microsoft 365 (abbonamento) - apre setup.office.com per riscatto/attivazione" -ForegroundColor White
Write-Host "  2) Office perpetuo (2021/2024) - inserisci il product key" -ForegroundColor White
Write-Host "  3) Salta" -ForegroundColor White
Write-Host ""

function Get-OsppPath {
    $percorsi = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs"
    )
    foreach ($p in $percorsi) { if (Test-Path $p) { return $p } }
    return $null
}

$sceltaAtt = Chiedi "Scelta (1-3)" "1"
switch ($sceltaAtt) {
    "1" {
        Start-Process "https://setup.office.com"
        Write-OK "Browser aperto su setup.office.com"
        Write-Info "Accedi con l'account Microsoft del cliente per riscattare e attivare Office 365."
        Add-Report "Office 365 (riscatto/attivazione)" "OK"
    }
    "2" {
        $osppPath = Get-OsppPath
        if (-not $osppPath) {
            Write-Errore "ospp.vbs non trovato: Office non risulta installato su questo PC."
            Add-Report "Attivazione Office perpetuo" "ERRORE"
        } else {
            $chiaveLicenza = (Read-Host "Inserisci il product key (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)").Trim().ToUpper()
            if ($chiaveLicenza -notmatch "^([A-Z0-9]{5}-){4}[A-Z0-9]{5}$") {
                Write-Errore "Formato non valido: 5 gruppi da 5 caratteri separati da trattino."
                Add-Report "Attivazione Office perpetuo" "ERRORE"
            } else {
                Write-Info "Inserimento product key..."
                cscript //nologo $osppPath /inpkey:$chiaveLicenza
                if ($LASTEXITCODE -ne 0) {
                    Write-Errore "Inserimento chiave fallito (codice $LASTEXITCODE)."
                    Add-Report "Attivazione Office perpetuo" "ERRORE"
                } else {
                    Write-Info "Attivazione in corso..."
                    cscript //nologo $osppPath /act
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK "Office attivato con successo."
                        Add-Report "Attivazione Office perpetuo" "OK"
                    } else {
                        Write-Errore "Attivazione fallita (codice $LASTEXITCODE). Verifica chiave e connessione."
                        Add-Report "Attivazione Office perpetuo" "ERRORE"
                    }
                }
            }
        }
    }
    default {
        Write-Info "Attivazione Office saltata."
        Add-Report "Attivazione Office" "SALTATO"
    }
}

if ($sceltaAtt -match "^[12]$") { Pausa }

# =============================================================================
# PULIZIA E OTTIMIZZAZIONE INIZIALE - un solo passaggio, una sola domanda:
#   1/3 rimuove gli antivirus di PROVA (evita conflitti e blocchi)
#   2/3 rimuove il bloatware + pulisce l'avvio automatico (boot piu' veloce)
#   3/3 applica piccole comodita' di Windows (estensioni, Questo PC, OneDrive)
# =============================================================================

Write-Titolo "Pulizia e Ottimizzazione Iniziale"

Write-Host "In un colpo solo, consigliato sui PC nuovi:" -ForegroundColor White
Write-Host "  - toglie gli antivirus di PROVA (McAfee/Norton/Avast: scadono e vanno" -ForegroundColor White
Write-Host "    in conflitto con quello che installi, a volte bloccano lo script)" -ForegroundColor White
Write-Host "  - rimuove il bloatware del produttore (HP/Lenovo/Dell/Asus/Acer) e le" -ForegroundColor White
Write-Host "    app consumer inutili, e alleggerisce l'avvio automatico" -ForegroundColor White
Write-Host "  - applica piccole comodita' (estensioni file, Esplora su 'Questo PC'," -ForegroundColor White
Write-Host "    OneDrive fuori dall'avvio)" -ForegroundColor White
Write-Host "NON tocca: Xbox, Spotify, Store, Foto, driver, ne' i programmi del setup." -ForegroundColor White
Write-Host ""

$vuoiPulizia = Chiedi "Eseguire ora la pulizia e ottimizzazione iniziale? (consigliato) (S/N)" "S"
if ($vuoiPulizia -match "^[Ss]") {

    # ---------------------------------------------------------------------
    # 1/3 - ANTIVIRUS DI PROVA
    # ---------------------------------------------------------------------
    Write-Info "1/3 - Rimozione antivirus di prova preinstallati..."
    if (Confirm-Winget) {
        $avTrial = @(
            "McAfee LiveSafe", "McAfee Total Protection", "McAfee Personal Security",
            "McAfee Security", "McAfee WebAdvisor", "McAfee Safe Connect", "McAfee",
            "Norton 360", "Norton Security", "Norton AntiVirus", "Norton",
            "Avast Free Antivirus", "AVG Antivirus"
        )
        $tolti = 0; $mcafeeTrovato = $false; $nortonTrovato = $false
        foreach ($n in $avTrial) {
            winget list --name $n --accept-source-agreements 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Rimozione $n..."
                winget uninstall --name $n --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
                $tolti++
                if ($n -like "McAfee*") { $mcafeeTrovato = $true }
                if ($n -like "Norton*") { $nortonTrovato = $true }
            }
        }
        if ($tolti -gt 0) {
            Write-OK "Rimossi/avviata rimozione di $tolti antivirus di prova."
            Add-Report "Antivirus di prova rimossi ($tolti)" "OK"

            # Pulizia COMPLETA coi tool ufficiali (winget lascia residui)
            if ($mcafeeTrovato) {
                Write-Info "McAfee lascia residui: MCPR (tool ufficiale McAfee) pulisce tutto."
                $r = Chiedi "Scaricare e avviare MCPR per rimuovere McAfee del tutto? (S/N)" "N"
                if ($r -match "^[Ss]") {
                    try {
                        $mcpr = "$env:TEMP\MCPR.exe"
                        irm "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe" -OutFile $mcpr -ErrorAction Stop
                        Start-Process -FilePath $mcpr
                        Write-OK "MCPR avviato: segui la procedura a schermo, poi RIAVVIA il PC."
                    } catch {
                        Write-Info "Download MCPR non riuscito. Scaricalo da: https://www.mcafee.com/support/?articleId=TS101331"
                    }
                }
            }
            if ($nortonTrovato) {
                Write-Info "Norton lascia residui: 'Norton Remove and Reinstall' pulisce tutto."
                $r = Chiedi "Aprire la pagina del tool di rimozione Norton? (S/N)" "N"
                if ($r -match "^[Ss]") {
                    Start-Process "https://norton.com/nrnr"
                    Write-OK "Pagina aperta: scarica ed esegui il tool, poi RIAVVIA il PC."
                }
            }
        } else {
            Write-Info "Nessun antivirus di prova trovato."
            Add-Report "Antivirus di prova" "SALTATO"
        }
    } else {
        Write-Errore "winget non disponibile: rimuovi gli AV di prova a mano da Impostazioni > App."
        Add-Report "Antivirus di prova" "ERRORE"
    }

    # ---------------------------------------------------------------------
    # 2/3 - BLOATWARE + PULIZIA AVVIO AUTOMATICO
    # ---------------------------------------------------------------------
    Write-Info "2/3 - Rimozione bloatware e pulizia dell'avvio automatico..."

# App Store (Appx) superflue. Wildcard sul nome. NON include Xbox ne' Spotify,
# ne' driver/stampante (pattern mirati sul bloatware, non l'intero publisher).
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

    $rimosse = 0
    foreach ($pkg in $bloatwareAppx) {
        try {
            $trovati = Get-AppxPackage -AllUsers -Name $pkg -ErrorAction SilentlyContinue
            foreach ($t in $trovati) {
                Write-Info "Rimuovo app: $($t.Name)"
                Remove-AppxPackage -Package $t.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $rimosse++
            }
            # Rimuovi anche il provisioning: i nuovi utenti non le riavranno
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $pkg } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        } catch {}
    }

    # Utility/trial Win32 via winget. NIENTE antivirus: li gestisce gia' il
    # blocco 1/3 qui sopra (nessuna duplicazione).
    $trialWin32 = @("HP Support Assistant", "HP Documentation", "HP Sure Recover",
                    "WildTangent Games", "ExpressVPN", "Dropbox Promotion")
    if (Confirm-Winget) {
        foreach ($nome in $trialWin32) {
            winget uninstall --name $nome --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Info "Rimosso (winget): $nome"; $rimosse++ }
        }
    }

    # --- Pulizia AVVIO AUTOMATICO: updater/helper NOTI (produttore, promo). NON
    # tocca driver, OneDrive, gli updater dei browser, ne' le app del setup. ---
    $avvioJunk = @(
        'HP*', '*Lenovo*', 'Dell*', '*ASUS*', 'Acer*', '*SupportAssist*', '*Vantage*',
        'Adobe*', 'SunJavaUpdate*', 'iTunesHelper', 'QuickTime*', 'CCleaner*',
        'WildTangent*', 'ExpressVPN*', '*Booking*'
    )
    $avvioTolti = 0
    # 1) Voci di registro "Run" (utente + macchina + 32-bit): tolgo per nome-voce
    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    $metaProp = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk)) { continue }
        $voci = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
        if (-not $voci) { continue }
        foreach ($v in $voci.PSObject.Properties) {
            if ($metaProp -contains $v.Name) { continue }
            foreach ($pat in $avvioJunk) {
                if ($v.Name -like $pat) {
                    Write-Info "Tolgo da avvio: $($v.Name)"
                    Remove-ItemProperty -Path $rk -Name $v.Name -ErrorAction SilentlyContinue
                    $avvioTolti++
                    break
                }
            }
        }
    }
    # 2) Collegamenti nelle cartelle "Esecuzione automatica" (utente + tutti)
    foreach ($dir in @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))) {
        if (-not $dir -or -not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
            $nomeLnk = $_.BaseName
            foreach ($pat in $avvioJunk) {
                if ($nomeLnk -like $pat) {
                    Write-Info "Tolgo collegamento avvio: $nomeLnk"
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    $avvioTolti++
                    break
                }
            }
        }
    }
    # 3) Task pianificati all'avvio/logon: DISABILITO (non elimino) i junk noti.
    #    Salto i task di sistema \Microsoft\Windows\ e gli updater dei browser.
    $taskJunk = @(
        '*Adobe*', '*HP*', '*Lenovo*', '*Dell*', '*ASUS*', '*Acer*',
        '*SupportAssist*', '*Vantage*', '*CCleaner*', '*WildTangent*',
        '*ExpressVPN*', '*Java Update*', '*JavaUpdate*'
    )
    try {
        foreach ($tk in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            if ($tk.State -eq 'Disabled') { continue }
            if ($tk.TaskPath -like '\Microsoft\Windows\*') { continue }   # OS: non toccare
            $full = "$($tk.TaskPath)$($tk.TaskName)"
            foreach ($pat in $taskJunk) {
                if ($full -like $pat) {
                    Write-Info "Disabilito task avvio: $($tk.TaskName)"
                    Disable-ScheduledTask -TaskName $tk.TaskName -TaskPath $tk.TaskPath -ErrorAction SilentlyContinue | Out-Null
                    $avvioTolti++
                    break
                }
            }
        }
    } catch {}

    Write-OK "Bloatware: rimosse $rimosse app; tolti $avvioTolti elementi dall'avvio automatico."
    Add-Report "Rimozione bloatware ($rimosse app)" "OK"
    Add-Report "Pulizia avvio automatico ($avvioTolti)" "OK"

    # ---------------------------------------------------------------------
    # 3/3 - CONFIGURAZIONE WINDOWS BASE (piccole comodita')
    # ---------------------------------------------------------------------
    Write-Info "3/3 - Applico piccole comodita' di Windows..."
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

    Write-OK "Pulizia e ottimizzazione iniziale completata."
    Beep-Fine
    Pausa
} else {
    Write-Info "Pulizia e ottimizzazione iniziale saltata."
    Add-Report "Antivirus di prova" "SALTATO"
    Add-Report "Rimozione bloatware" "SALTATO"
    Add-Report "Configurazione Windows base" "SALTATO"
}

# =============================================================================
# PASSI DI CONFIGURAZIONE (dopo ogni scelta si avanza; B al prompt = indietro)
# =============================================================================

# Torna al passo precedente quando l'utente digita B al prompt principale di un
# passo. Uso 'continue wizard' (loop etichettato) per rifare il giro del while
# anche da dentro lo switch, saltando il $passo++ di fine passo.
function Test-Indietro { param([string]$v) return ($v -match '^\s*[Bb]\s*$') }

# Il wizard parte dal passo 2: il passo 1 "Nome" e' stato spostato prima (dopo
# la lingua). Non rinumero i case dello switch: nella barra mostro (passo-1) su 7.
$passo = 2
:wizard while ($passo -ge 2 -and $passo -le 8) {
Write-Host ""
$barLen = 20
$totPassi = 7
$passoMostrato = $passo - 1
$pieni = [int]($barLen * $passoMostrato / $totPassi)
if ($pieni -gt $barLen) { $pieni = $barLen }
$bar = (([string]$BOX_FULL) * $pieni) + (([string]$BOX_EMPTY) * ($barLen - $pieni))
Write-Host ("$AON  Passo $passoMostrato/$totPassi  [$bar]$AOFF") -ForegroundColor $THEME_COL
switch ($passo) {
2 {
# =============================================================================
# STEP 2 - INSTALLA SUITE OFFICE GRATUITA (OpenOffice / LibreOffice)
# =============================================================================

Write-Titolo "Installa Suite Office (alternativa gratuita)"

Write-Host "Serve solo se vuoi una suite GRATUITA al posto di Microsoft Office." -ForegroundColor White
Write-Host "(Microsoft 365 lo attivi nel passo 'Attivazione Office', all'inizio.)" -ForegroundColor Gray
Write-Host "  1) OpenOffice" -ForegroundColor White
Write-Host "  2) LibreOffice" -ForegroundColor White
Write-Host "  3) Salta" -ForegroundColor White
Write-Host ""

$sceltaSuite = Chiedi "Scelta (1-3, B=indietro)" "3"
if (Test-Indietro $sceltaSuite) { $passo = [Math]::Max(2, $passo - 1); continue wizard }
switch ($sceltaSuite) {
    "1" {
        if (Confirm-Winget) { Installa-Pacchetto -Nome "OpenOffice" -WingetId "Apache.OpenOffice" }
        else { Write-Errore "Winget non disponibile." ; Add-Report "OpenOffice (installazione)" "ERRORE" }
    }
    "2" {
        if (Confirm-Winget) { Installa-Pacchetto -Nome "LibreOffice" -WingetId "TheDocumentFoundation.LibreOffice" }
        else { Write-Errore "Winget non disponibile." ; Add-Report "LibreOffice (installazione)" "ERRORE" }
    }
    default {
        Write-Info "Nessuna suite alternativa installata."
    }
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
3 {
# =============================================================================
# STEP 4 - ANTIVIRUS
# =============================================================================

Write-Titolo "Antivirus"

Write-Host "Scegli l'antivirus da installare:" -ForegroundColor White
Write-Host "  1) McAfee"
Write-Host "  2) Norton"
Write-Host "  3) Salta"
Write-Host ""

$sceltaAV = Read-Host "Scelta (1-3, B=indietro)"
if (Test-Indietro $sceltaAV) { $passo = [Math]::Max(2, $passo - 1); continue wizard }

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
        $avvia = Chiedi "Avviare questo installer? (S/N)" "S"
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
        Installa-Antivirus -Nome "McAfee" -UrlRiscatto "https://www.mcafee.com/activate"
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

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
4 {
# =============================================================================
# STEP 4c - UNIEURO CYBER PROTECTION (opzionale)
# =============================================================================

Write-Titolo "Unieuro Cyber Protection"

Write-Host "Servizio venduto solo su richiesta: salta se il cliente non l'ha acquistato." -ForegroundColor White
Write-Host ""

$vuoiUnieuro = Chiedi "Attivare Unieuro Cyber Protection? (S/N, B=indietro)" "N"
if (Test-Indietro $vuoiUnieuro) { $passo = [Math]::Max(2, $passo - 1); continue wizard }
if ($vuoiUnieuro -match "^[Ss]") {
    Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it"
} else {
    Write-Info "Unieuro Cyber Protection saltato."
    Add-Report "Unieuro Cyber Protection" "SALTATO"
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
5 {
# =============================================================================
# STEP 5 - BROWSER
# =============================================================================

Write-Titolo "Browser"

$browserDisponibili = $CatalogoBrowser

Write-Host "Browser disponibili:" -ForegroundColor White
for ($i = 0; $i -lt $browserDisponibili.Count; $i++) {
    Write-Host "  $($i + 1)) $($browserDisponibili[$i].Nome)"
}
Write-Host ""
Write-Host "  T) Installa tutti"
Write-Host "  S) Salta"
Write-Host ""

$sceltaBrowser = Chiedi "Scelta (es: 1,2 - T tutti - S salta - B indietro)" "S"
if (Test-Indietro $sceltaBrowser) { $passo = [Math]::Max(2, $passo - 1); continue wizard }

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

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
6 {
# =============================================================================
# STEP 6 - APPLICAZIONI BASE
# =============================================================================

Write-Titolo "Applicazioni Base"

# App e profili derivano dal CATALOGO unico definito all'inizio (niente duplicati).
$appsDisponibili = $CatalogoApp
$profili = [ordered]@{
    "BASE"    = @($CatalogoApp | Where-Object { $_.Profili -contains "BASE" }    | ForEach-Object { $_.Id })
    "UFFICIO" = @($CatalogoApp | Where-Object { $_.Profili -contains "UFFICIO" } | ForEach-Object { $_.Id })
    "GAMING"  = @($CatalogoApp | Where-Object { $_.Profili -contains "GAMING" }  | ForEach-Object { $_.Id })
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
Write-Host "  3) PROFILO GAMING   (BASE + Steam, Epic, Discord, qBittorrent; +GeForce se NVIDIA)"
Write-Host "  4) COMPLETO         (tutte le app in lista)"
Write-Host "  5) MANUALE          (scelgo io i singoli numeri)"
Write-Host "  S) Salta"
Write-Host ""

$sceltaApps = Read-Host "Scelta (1-5 - S salta - B indietro)"
if (Test-Indietro $sceltaApps) { $passo = [Math]::Max(2, $passo - 1); continue wizard }

switch ($sceltaApps) {
    "1" { Installa-Set -Ids $profili["BASE"] }
    "2" { Installa-Set -Ids $profili["UFFICIO"] }
    "3" {
        Installa-Set -Ids $profili["GAMING"]
        # PC da gaming: se c'e' una GPU NVIDIA installo l'app GeForce (driver video)
        if ((Test-GpuNvidia) -and (Confirm-Winget)) {
            Write-Info "GPU NVIDIA rilevata (PC da gaming): installo l'app GeForce per i driver."
            Installa-Pacchetto -Nome "NVIDIA GeForce Experience" -WingetId "Nvidia.GeForceExperience"
        }
    }
    "4" {
        if (Confirm-Winget) {
            foreach ($app in $appsDisponibili) { Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id }
            # Completo: aggiungo l'app GeForce solo se c'e' davvero una GPU NVIDIA
            if (Test-GpuNvidia) {
                Write-Info "GPU NVIDIA rilevata: installo anche l'app GeForce per i driver."
                Installa-Pacchetto -Nome "NVIDIA GeForce Experience" -WingetId "Nvidia.GeForceExperience"
            }
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

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
7 {
# =============================================================================
# STEP 8 - AGGIORNAMENTO APP INSTALLATE - opzionale
# =============================================================================

Write-Titolo "Aggiornamento App Installate"

Write-Host "Aggiorna all'ultima versione le app gestite da winget (incluse molte OEM)." -ForegroundColor White
Write-Host "Puo' richiedere diversi minuti. (I driver hanno il loro passo dedicato dopo.)" -ForegroundColor White
Write-Host ""

$vuoiUpgrade = Chiedi "Aggiornare ora tutte le app installate? (S/N, B=indietro)" "S"
if (Test-Indietro $vuoiUpgrade) { $passo = [Math]::Max(2, $passo - 1); continue wizard }
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

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
8 {
# =============================================================================
# STEP 8 - INSTALLA/AGGIORNA DRIVER (Windows Update, opzionale, ultimo passo)
# =============================================================================

Write-Titolo "Driver (Windows Update)"

Write-Host "Cerca e installa i driver mancanti/aggiornati dal catalogo Windows Update." -ForegroundColor White
Write-Host "Vendor-neutral: niente tool del produttore. Puo' richiedere qualche minuto" -ForegroundColor White
Write-Host "e talvolta un riavvio. Opzionale, ultimo passo." -ForegroundColor White
Write-Host ""

$vuoiDriver = Chiedi "Cercare e installare i driver ora? (S/N, B=indietro)" "S"
if (Test-Indietro $vuoiDriver) { $passo = [Math]::Max(2, $passo - 1); continue wizard }
if ($vuoiDriver -match "^[Ss]") {
    try {
        Write-Info "Ricerca driver su Windows Update (puo' richiedere qualche minuto)..."
        $sess = New-Object -ComObject Microsoft.Update.Session
        $searcher = $sess.CreateUpdateSearcher()
        # Solo aggiornamenti di tipo driver non ancora installati
        $result = $searcher.Search("Type='Driver' and IsInstalled=0")
        if ($result.Updates.Count -eq 0) {
            Write-OK "Nessun driver da installare: risultano gia' tutti aggiornati."
            Add-Report "Driver (Windows Update)" "OK"
        } else {
            $daInstallare = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($u in $result.Updates) {
                Write-Info "Driver trovato: $($u.Title)"
                $daInstallare.Add($u) | Out-Null
            }
            Write-Info "Download driver..."
            $downloader = $sess.CreateUpdateDownloader()
            $downloader.Updates = $daInstallare
            $downloader.Download() | Out-Null
            Write-Info "Installazione driver..."
            $installer = $sess.CreateUpdateInstaller()
            $installer.Updates = $daInstallare
            $esito = $installer.Install()
            if ($esito.ResultCode -eq 2) {
                Write-OK "Driver installati ($($daInstallare.Count))."
                Add-Report "Driver installati ($($daInstallare.Count))" "OK"
            } else {
                Write-Info "Installazione driver conclusa (codice $($esito.ResultCode)): alcuni potrebbero richiedere riavvio."
                Add-Report "Driver (Windows Update)" "AVVISO"
            }
            if ($esito.RebootRequired) { Write-Info "Alcuni driver richiedono un RIAVVIO per completare." }
        }
    } catch {
        Write-Errore "Ricerca/installazione driver non riuscita: $_"
        Add-Report "Driver (Windows Update)" "ERRORE"
    }
} else {
    Write-Info "Installazione driver saltata."
    Add-Report "Driver (Windows Update)" "SALTATO"
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
}
Beep-Fine   # avviso sonoro: passo del wizard completato
if ($passo -lt 2) { $passo = 2 }
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
    Write-Host ("$AON" + ("Totale: {0} OK, {1} ERRORE, {2} SALTATO, {3} AVVISO" -f $nOk, $nErrore, $nSaltato, $nAvviso) + "$AOFF") -ForegroundColor $THEME_COL
    if ($nErrore -gt 0) {
        Write-Host "Controlla le voci in ERRORE prima di consegnare il PC." -ForegroundColor Red
    }
}

# UN SOLO file riepilogo, ordinato - solo run reale (Configura)
if ($RunReale) {
    # -------------------------------------------------------------------------
    # CHIAVE DI RIPRISTINO BITLOCKER (il piu' TARDI possibile: se la device
    # encryption di Windows 11 si e' attivata durante il setup, ora la chiave
    # esiste). Usa la funzione di log Add-Report come gli altri passi.
    # DATO SENSIBILE: la chiave finisce nel riepilogo che resta col PC (voluto).
    # -------------------------------------------------------------------------
    Write-Titolo "Chiave di Ripristino BitLocker"
    Write-Host "Salvo la chiave di ripristino nel riepilogo: senza, se Windows attiva la" -ForegroundColor White
    Write-Host "crittografia da solo, dopo un reset o un cambio hardware si perde l'accesso." -ForegroundColor White
    Write-Host ""
    $bitlocker = Get-BitLockerRecovery -Volume $env:SystemDrive
    switch ($bitlocker.Esito) {
        "OK"      { Write-OK "Chiave di ripristino BitLocker salvata (volume $($bitlocker.Volume))." }
        "SALTATO" { Write-Info $bitlocker.Messaggio }
        default   { Write-Info $bitlocker.Messaggio }   # AVVISO
    }
    Add-Report "Chiave di ripristino BitLocker" $bitlocker.Esito

    # Le credenziali del nuovo account le ha GENERATE lo script allo step Account
    # Microsoft ($credMsAccount / $credMsPassword). Se quel passo e' stato saltato
    # restano vuote. Niente domande all'operatore, niente password dal browser.
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
        $f += "Cliente  : $(if ($nomeCliente) { $nomeCliente } else { '(non impostato)' })"
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
        # DATO SENSIBILE: la recovery key da' accesso completo al disco. Sta qui
        # apposta, cosi' resta col PC del cliente e non si perde.
        $f += "CHIAVE DI RIPRISTINO BITLOCKER  (DATO SENSIBILE: accesso al disco)"
        $f += $sep
        if ($bitlocker) {
            $f += "  Volume        : $($bitlocker.Volume)"
            $f += "  Cifratura     : $($bitlocker.Stato)"
            if ($bitlocker.RecoveryKey) {
                $f += "  ID chiave     : $($bitlocker.KeyId)"
                $f += "  Recovery key  : $($bitlocker.RecoveryKey)"
                $f += "  >> CONSERVA questa chiave: senza, dopo un reset o un cambio"
                $f += "     hardware il disco cifrato NON e' piu' accessibile."
            } else {
                $f += "  $($bitlocker.Messaggio)"
            }
        } else {
            $f += "  (controllo non eseguito)"
        }
        $f += ""
        $f += $sep
        $f += "ALTRE OPERAZIONI"
        $f += $sep
        foreach ($r in $altre) { $f += ("  [{0,-8}] {1}" -f $r.Esito, $r.Voce) }
        $f += ""
        $f += $sep
        $blank = "______________________________"
        $haCred = ($credMsAccount -or $credMsPassword -or $credAltro)
        $f += "NOTE / CREDENZIALI$(if ($haCred) { ' - CONTIENE DATI IN CHIARO: ELIMINA IL FILE DOPO LA CONSEGNA' } else { ' (da compilare a mano)' })"
        $f += $sep
        $f += "  Account Microsoft : $(if ($credMsAccount) { $credMsAccount } else { $blank })"
        $f += "  Password          : $(if ($credMsPassword) { $credMsPassword } else { $blank })"
        # Campi dedicati per ogni antivirus/protezione attivato in questa sessione.
        # Antivirus (McAfee/Norton): stesse credenziali dell'account Microsoft.
        # Cyber protection (Unieuro): la password la CREA il sito e la manda via
        # email dopo la registrazione, quindi non la conosciamo in anticipo.
        foreach ($a in $av) {
            $nomeSvc = ($a.Voce -replace ' \(antivirus\)', '' -replace ' \(protezione\)', '').Trim()
            $isProtezione = $a.Voce -like '*protezione*'
            $f += ""
            $f += "  [$nomeSvc]"
            $f += "  Email/utente account : $(if ($credMsAccount) { $credMsAccount } else { $blank })"
            if ($isProtezione) {
                $f += "  Password account     : (creata dal sito, arriva via email dopo la registrazione)"
            } else {
                $f += "  Password account     : $(if ($credMsPassword) { $credMsPassword } else { $blank })"
            }
            $f += "  Codice/PIN licenza   : $blank"
            $f += "  Credenziali app      : $blank"
        }
        $f += ""
        $f += "  Altro             : $(if ($credAltro) { $credAltro } else { $blank })"
        $f += ""
        $f += "============================================================"

        $riepFile = Join-Path (Get-DesktopDir) ("Riepilogo-PC_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmm"))
        $f | Set-Content -Path $riepFile -Encoding UTF8
        Write-OK "Riepilogo salvato sul Desktop: $riepFile"
    } catch {
        Write-Info "Impossibile creare il file riepilogo: $_"
    }
}

# -----------------------------------------------------------------------------
# PULIZIA FINALE: PC Facile non lascia tracce di se' sul PC del cliente.
# Cancella la copia dello script scaricata in %TEMP% dal launcher e i due valori
# di registro dei colori (console riportata allo stato di fabbrica). Remove-Item
# cancella in modo PERMANENTE, NON passa dal Cestino. Il REPORT sul Desktop
# resta: serve al cliente. Se lo script gira dalla chiavetta (offline) la copia
# locale NON viene toccata. Fatto PRIMA dell'eventuale riavvio, cosi' parte sempre.
# -----------------------------------------------------------------------------
if ($RunReale) {
    try {
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable01' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -ErrorAction SilentlyContinue
    } catch {}
    $ioStesso = $MyInvocation.MyCommand.Path
    if ($ioStesso -and $ioStesso -like "$env:TEMP\*") {
        # Il file .ps1 in esecuzione NON e' bloccato: lo rimuovo ora, lo script
        # prosegue dalla memoria. Cosi' non resta nulla sul disco del cliente.
        try { Remove-Item -LiteralPath $ioStesso -Force -ErrorAction SilentlyContinue } catch {}
    }
    Write-OK "Pulizia finale: PC Facile rimosso dal PC (il report resta sul Desktop)."
}

# Offri il riavvio se la lingua e' stata cambiata (serve reboot per applicarsi)
$linguaCambiata = @($Report | Where-Object { $_.Voce -like "Lingua italiana*" -and $_.Esito -eq "OK" }).Count -gt 0
Write-Host ""
if ($linguaCambiata) {
    Write-Info "La lingua e' stata cambiata: serve un RIAVVIO per applicarla del tutto."
    $riavvia = Chiedi "Riavviare il PC ora? (S/N)" "N"
    if ($riavvia -match "^[Ss]") {
        Write-Info "Riavvio in corso..."
        Restart-Computer -Force
    } else {
        Write-Info "Ricordati di riavviare il PC prima di consegnarlo."
    }
}

Write-Host ""
Beep-Completato   # melodia "tutto finito" (utile se ti sei allontanato)
Write-Host "${AON}Buon lavoro!$AOFF" -ForegroundColor $THEME_COL
# Niente Pausa qui: l'unico "premi un tasto" e' quello finale del launcher .bat
# ("Operazione terminata"), cosi' non si preme INVIO due volte.
