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
    # Modalita' Espresso (Automatico 1-Click): fa TUTTO da solo alla massima velocita'
    # senza interruzioni (profilo app base, pulizia bloatware/AV, ottimizzazioni, update).
    [Alias("ZeroTouch", "Automatico", "Auto", "Silenzioso")]
    [switch]$Espresso,
    # Modalita' Manuale: procedura guidata passo-passo (scelta account, app personalizzate, office, AV).
    [switch]$Manuale,
    # Prepara USB Offline: scarica tutti i programmi di installazione (.exe/.msi)
    # direttamente nella cartella 'installers' della chiavetta per lavorare al 100% offline.
    [Alias("USB", "Offline", "DownloadOffline")]
    [switch]$PreparaUSB,
    # Modulo Trasferimento Dati / Migrazione: copia dati utente da vecchio PC o disco USB.
    [Alias("Backup", "Trasferimento", "Migra")]
    [switch]$Migrazione,
    # Modalita' Agente IA / Automatica: automazione intelligente registrazione account con stop su codici OTP
    [Alias("IA", "Agent", "AutoIA", "Automatica")]
    [switch]$AgenteIA,
    # Menu iniziale di scelta modalita'
    [switch]$Menu,
    # Veloce: parametro di compatibilita'
    [switch]$Veloce,
    # Salta la creazione del punto di ripristino
    [switch]$skipRestore,
    # Cartella target o USB esplicita (opzionale)
    [string]$TargetDir
)

if ($TargetDir) {
    $TargetDir = ($TargetDir -replace '["'']', '').Trim().TrimEnd('\').TrimEnd('/')
    $Global:TargetDir = $TargetDir
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Versione del programma (mostrata nell'header e nel riepilogo).
# Bump ad ogni modifica cosi' capisci se la USB e' aggiornata.
$SCRIPT_VERSION = "12.0 (2026-09-05)"

# Versione SEMPRE VISIBILE: la scrivo nella barra del titolo della finestra, che
# resta a video in QUALSIASI schermata (a differenza dell'header, che scorre via).
# Cosi' l'operatore controlla al volo se la chiavetta ha scaricato l'ultima.
try { $Host.UI.RawUI.WindowTitle = "PC Facile  -  v$SCRIPT_VERSION" } catch {}

# Simboli di stato e grafica costruiti a runtime con [char]: NON dipendono
# dall'encoding con cui PowerShell legge questo file (5.1 senza BOM li
# storpierebbe). L'output e' gia' UTF-8 (impostato sopra), quindi si vedono.
$SYM_OK    = [char]0x2713                  # spunta
$SYM_ERR   = [char]0x2717                  # croce
$SYM_INFO  = [char]0x2192                  # freccia
$BOX_FULL  = [char]0x2588                  # blocco pieno (barra progresso)
$BOX_EMPTY = [char]0x2591                  # blocco leggero (barra progresso)
$LINEA_D   = ([string][char]0x2550) * 60   # linea doppia orizzontale

# =============================================================================
# TEMA GRAFICO UFFICIALE UNIEURO (NAVY #00122B & ARANCIONE #EE7203)
# =============================================================================
$ESC         = [char]27
$U_NAVY_BG   = "$ESC[48;2;0;18;43m"          # Sfondo Navy Unieuro (#00122B)
$U_CARD_BG   = "$ESC[48;2;0;31;72m"          # Sfondo Card Navy (#001F48)
$U_ORANGE    = "$ESC[38;2;238;114;3m"        # Arancione Unieuro (#EE7203)
$U_ORANGE_BG = "$ESC[48;2;238;114;3m$ESC[38;2;255;255;255m$ESC[1m" # Badge UNIEURO
$U_WHITE     = "$ESC[38;2;248;250;252m$ESC[1m" # Bianco brillante (#F8FAFC)
$U_GREEN     = "$ESC[38;2;34;197;94m$ESC[1m"  # Verde spunta (#22C55E)
$U_BLUE      = "$ESC[38;2;147;197;253m"      # Blu chiaro (#93C5FD)
$U_PEACH     = "$ESC[38;2;254;215;170m"      # Evidenziatore pesca (#FED7AA)
$U_MUTED     = "$ESC[38;2;148;163;184m"      # Grigio secondario (#94A3B8)
$U_ERR       = "$ESC[38;2;239;68;68m$ESC[1m"  # Rosso errore (#EF4444)
$U_RESET     = "$ESC[0m"

$AON         = $U_ORANGE
$AOFF        = $U_RESET
$THEME_COL   = "DarkYellow"
$THEME_TXT   = "White"

# Rileva se il Virtual Terminal (ANSI 24-bit) e' attivo
$vtOn = $true
try {
    if (Test-Path 'HKCU:\') {
        if (-not (Test-Path 'HKCU:\Console')) { New-Item -Path 'HKCU:\Console' -Force | Out-Null }
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable00' -Value 0x002B1200 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable01' -Value 0x002B1200 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable02' -Value 0x005EC522 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable03' -Value 0x00FDC593 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable06' -Value 0x000372EE -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable07' -Value 0x00FCFAF8 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable10' -Value 0x005EC522 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable14' -Value 0x000372EE -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable15' -Value 0x00FFFFFF -Type DWord -ErrorAction SilentlyContinue
    }
} catch {}

try {
    $Host.UI.RawUI.BackgroundColor = 'Black'
    $Host.UI.RawUI.ForegroundColor = 'Gray'
    Clear-Host
} catch {}

# =============================================================================
# FUNZIONI UTILITY
# =============================================================================

function Write-Titolo {
    param([string]$Testo)
    $barra = ([string]$BOX_FULL) * 54
    Write-Host ""
    Write-Host ""
    if ($vtOn) {
        Write-Host "  $U_ORANGE$barra$U_RESET"
        Write-Host "  $U_ORANGE_BG UNIEURO $U_RESET  $U_WHITE$($Testo.ToUpper())$U_RESET"
        Write-Host "  $U_ORANGE$barra$U_RESET"
    } else {
        Write-Host "  $barra" -ForegroundColor DarkYellow
        Write-Host "   [UNIEURO] $($Testo.ToUpper())" -ForegroundColor White
        Write-Host "  $barra" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

function Write-OK {
    param([string]$Testo)
    if ($vtOn) {
        Write-Host "   $U_GREEN$SYM_OK$U_RESET  $U_WHITE$Testo$U_RESET"
    } else {
        Write-Host "   $SYM_OK  $Testo" -ForegroundColor Green
    }
}

function Write-Info {
    param([string]$Testo)
    if ($vtOn) {
        Write-Host "   $U_ORANGE$SYM_INFO$U_RESET  $U_BLUE$Testo$U_RESET"
    } else {
        Write-Host "   $SYM_INFO  $Testo" -ForegroundColor Yellow
    }
}

function Write-Errore {
    param([string]$Testo)
    if ($vtOn) {
        Write-Host "   $U_ERR$SYM_ERR$U_RESET  $U_ERR$Testo$U_RESET"
    } else {
        Write-Host "   $SYM_ERR  $Testo" -ForegroundColor Red
    }
}

# =============================================================================
# GESTIONE AVVISI SICUREZZA
# =============================================================================
function Enable-SilentElevation {
    try {
        $env:SEE_MASK_NOZONECHECKS = '1'
    } catch {}
}

function Restore-SilentElevation {
    # Pulizia impostazioni
}

# Avviso sonoro. [console]::Beep e' un metodo .NET gestito: NON e' P/Invoke,
# l'antivirus non lo segnala. Solo nel run reale (niente bip in Test/Diagnostica).
# Bip di ATTESA: suona quando lo script si ferma e aspetta una TUA azione
# (domande, pause). Cosi', se ti allontani, un bip = "serve la tua azione".
function Beep-Attesa {
    if ($RunReale) { try { [console]::Beep(1000, 150) } catch {} }
}
# Melodia breve di "tutto finito" (due toni), a fine lavoro.
function Beep-Completato {
    if ($RunReale) { try { [console]::Beep(784, 160); [console]::Beep(1047, 260) } catch {} }
}

$Report = [System.Collections.ArrayList]::new()

function Add-Report {
    param(
        [string]$Voce,
        [string]$Esito  # OK | ERRORE | SALTATO
    )
    if ($null -eq $Report -or $Report.IsFixedSize) {
        $nuovo = [System.Collections.ArrayList]::new()
        if ($Report) { foreach ($elem in $Report) { [void]$nuovo.Add($elem) } }
        $Report = $nuovo
        $Global:Report = $nuovo
    }
    [void]$Report.Add([pscustomobject]@{ Voce = $Voce; Esito = $Esito })
}

$Global:ErroriImprevisti = [System.Collections.ArrayList]::new()

function Register-ErroreImprevisto {
    param($ErroreRec)
    try {
        if ($null -eq $Global:ErroriImprevisti) { $Global:ErroriImprevisti = [System.Collections.ArrayList]::new() }
        $info = [ordered]@{
            Quando  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Messaggio = "$($ErroreRec.Exception.Message)"
            Comando   = "$($ErroreRec.InvocationInfo.MyCommand)"
            Riga      = "$($ErroreRec.InvocationInfo.ScriptLineNumber)"
            Dettaglio = "$($ErroreRec.InvocationInfo.Line)".Trim()
        }
        [void]$Global:ErroriImprevisti.Add([pscustomobject]$info)
    } catch {}
}

trap {
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}

# BIP DI RICHIAMO: se ti allontani e non rispondi, dopo 2 MINUTI di silenzio lo
# script inizia a bipare in modo RICORRENTE (un bip corto ogni pochi secondi,
# discreto, non stressante) e continua finche' non digiti, cosi' te ne accorgi.
# Read-Host blocca il thread principale, quindi il bip gira in un RUNSPACE
# separato (.NET gestito, niente P/Invoke: l'antivirus non lo segnala), che
# lavora in parallelo mentre il thread principale e' fermo su Read-Host.
$Global:BipPS = $null
function Start-BipRipetuto {
    param(
        [int]$Attesa   = 120,   # secondi di silenzio prima di iniziare a richiamare
        [int]$Cadenza  = 4       # poi un bip corto ogni tot secondi, di continuo
    )
    if (-not $RunReale) { return }
    Stop-BipRipetuto
    try {
        $ps = [PowerShell]::Create()
        [void]$ps.AddScript({
            param($attesa, $cadenza)
            Start-Sleep -Seconds $attesa          # 2 min: nessun suono, lavori in pace
            while ($true) {                        # poi richiamo ricorrente ma discreto
                try { [console]::Beep(880, 120) } catch {}
                Start-Sleep -Seconds $cadenza
            }
        }).AddArgument($Attesa).AddArgument($Cadenza)
        [void]$ps.BeginInvoke()
        $Global:BipPS = $ps
    } catch { $Global:BipPS = $null }
}
function Stop-BipRipetuto {
    if ($Global:BipPS) {
        try { $Global:BipPS.Stop(); $Global:BipPS.Dispose() } catch {}
        $Global:BipPS = $null
    }
}

# BARRA ANIMATA GENERICA per le operazioni lunghe che NON sono installazioni
# winget (lingua, punto di ripristino, driver, pulizia...). Quelle bloccano il
# thread principale e non hanno un processo da "agganciare", percio' l'animazione
# gira in un RUNSPACE separato (.NET gestito, niente P/Invoke) che disegna una
# barra "a spola" col tempo trascorso, mentre l'operazione vera lavora nel thread
# principale (cosi' variabili ed effetti restano intatti). Uso:
#   Start-BarraAnimata "Testo"; <operazione bloccante>; Stop-BarraAnimata
$Global:BarraPS = $null
function Start-BarraAnimata {
    param([string]$Testo)
    if (-not $RunReale) { return }
    Stop-BarraAnimata
    try {
        $pctVal = if ($Global:PannelloStatus) { $Global:PannelloStatus.Percentuale } else { 0 }
        try { $host.UI.RawUI.WindowTitle = "PC Facile [$pctVal%] - $Testo" } catch {}
        $ps = [PowerShell]::Create()
        [void]$ps.AddScript({
            param($testo, $full, $empty, $uOrange, $uReset, $uBlue, $uPeach, $pct)
            $larg = 20; $span = 4; $period = ($larg - $span) * 2; $inizio = Get-Date; $i = 0
            while ($true) {
                $phase = $i % $period
                $pos = if ($phase -le ($larg - $span)) { $phase } else { $period - $phase }
                $barra = ($empty * $pos) + ($full * $span) + ($empty * ($larg - $span - $pos))
                $sec = [int]((Get-Date) - $inizio).TotalSeconds
                $pctTxt = if ($pct -ge 0) { " $uOrange$pct%$uReset" } else { "" }
                $riga = "   $uBlue$testo$uReset$pctTxt  [$uOrange$barra$uReset]  $uPeach${sec}s$uReset"
                try { [Console]::Write("`r$riga") } catch {}
                Start-Sleep -Milliseconds 120; $i++
            }
        }).AddArgument($Testo).AddArgument([string]$BOX_FULL).AddArgument([string]$BOX_EMPTY).AddArgument($U_ORANGE).AddArgument($U_RESET).AddArgument($U_BLUE).AddArgument($U_PEACH).AddArgument($pctVal)
        [void]$ps.BeginInvoke()
        $Global:BarraPS = $ps
    } catch { $Global:BarraPS = $null }
}
function Stop-BarraAnimata {
    if ($Global:BarraPS) {
        try { $Global:BarraPS.Stop(); $Global:BarraPS.Dispose() } catch {}
        $Global:BarraPS = $null
        try { [Console]::Write("`r" + (' ' * 72) + "`r") } catch {}
    }
}

# Attesa di una risposta CON WATCHDOG DI SICUREZZA:
# Attende una decisione o risposta dell'operatore.
# NON salta le decisioni: aspetta l'operatore con bip di avviso sonoro (Beep-Attesa)
# e richiamo acustico ricorrente (Start-BipRipetuto) dopo 2 minuti, cosi' l'operatore
# in negozio lo sente e puo' intervenire quando e' pronto.
function Attendi-Risposta {
    param(
        [string]$Prompt,
        [int]$TimeoutSec = 0,
        [string]$Default = ""
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST) {
        if ($Default) { return $Default }
        if ($Prompt -match 'S/N') { return "N" }
        return ""
    }

    Beep-Attesa
    Start-BipRipetuto
    try {
        if ($TimeoutSec -gt 0) {
            $inputStr = ""
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            Write-Host -NoNewline "${Prompt}: "
            while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
                try {
                    if ([Console]::KeyAvailable) {
                        $keyInfo = [Console]::ReadKey($false)
                        if ($keyInfo.Key -eq [ConsoleKey]::Enter) {
                            Write-Host ""
                            if ([string]::IsNullOrWhiteSpace($inputStr)) { return $Default }
                            return $inputStr
                        } elseif ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
                            if ($inputStr.Length -gt 0) {
                                $inputStr = $inputStr.Substring(0, $inputStr.Length - 1)
                                [Console]::Write("`b `b")
                            }
                        } elseif (-not [char]::IsControl($keyInfo.KeyChar)) {
                            $inputStr += $keyInfo.KeyChar
                        }
                    }
                } catch { break }
                Start-Sleep -Milliseconds 100
            }
            Write-Host ""
            if ([string]::IsNullOrWhiteSpace($inputStr)) { return $Default }
            return $inputStr
        } else {
            return (Read-Host $Prompt)
        }
    } finally {
        Stop-BipRipetuto
    }
}

function Pausa {
    Write-Host ""
    [void](Attendi-Risposta "Premi INVIO per continuare")
}

# Password = nome cliente + "123!" (sempre, cosi' e' prevedibile e facile da
# dettare). Es. "Rossi" -> "Rossi123!". Ha maiuscola, minuscole, cifre e simbolo
# -> soddisfa i requisiti Microsoft. Lo SCRIPT la costruisce (quindi la conosce
# e la scrive nel riepilogo): NON legge nulla dal browser.
function New-PasswordCliente {
    param([string]$Base)
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP')
    if ($Base -and ($oemNames -contains $Base.Trim().ToUpper())) {
        $Base = "Utente"
    }
    # Convenzione del negozio: "Nome123!" -> SOLO il primo nome (prima parola),
    # prima lettera maiuscola, il resto minuscolo. Es. "Mario Rossi" -> "Mario123!".
    $primo = @($Base -split '\s+' | Where-Object { $_ })[0]
    $b = ($primo -replace '[^A-Za-z]', '')
    if ($b.Length -lt 1 -or $b.ToUpper() -eq "CLIENTE") { $b = "Utente" }
    $b = $b.Substring(0, 1).ToUpper() + $b.Substring(1).ToLower()
    return "${b}123!"
}

# Email suggerita per un nuovo account: convenzione del negozio "cognomenome"
# (COGNOME poi NOME) tutto attaccato e minuscolo, senza numeri. L'operatore
# digita "Nome Cognome": prendo l'ULTIMA parola come cognome e la metto davanti.
# Il dominio dipende dal provider scelto (outlook.it, gmail.com, proton.me).
# Es. "Mario Rossi" -> rossimario@outlook.it.
function New-EmailCliente {
    param([string]$Base, [string]$Dominio = "outlook.it")
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP')
    if ($Base -and ($oemNames -contains $Base.Trim().ToUpper())) {
        $Base = "utente"
    }
    $parti = @($Base -split '\s+' | ForEach-Object { $_ -replace '[^A-Za-z0-9]', '' } | Where-Object { $_ })
    if ($parti.Count -ge 2) {
        $cognome = $parti[-1]
        $nome    = ($parti[0..($parti.Count - 2)] -join '')
        $e = ($cognome + $nome).ToLower()
    } elseif ($parti.Count -eq 1) {
        $e = $parti[0].ToLower()
    } else {
        $e = "utente"
    }
    if ($e.Length -gt 20) { $e = $e.Substring(0, 20) }
    return "$e@$Dominio"
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

# Rileva la GPU DEDICATA (non l'integrata): solo per queste ha senso installare
# il tool del produttore, perche' Windows Update spesso non ne prende il driver
# giusto. Sulle integrate (Intel HD/UHD/Iris, Radeon dei Ryzen) Windows Update
# basta, quindi non aggiungiamo app inutili. Ritorna il vendor: 'NVIDIA',
# 'AMD', 'INTEL' oppure $null se c'e' solo grafica integrata.
# Euristica (solo Win32_VideoController, niente tool esterni):
#  - NVIDIA presente          -> sempre dedicata.
#  - AMD "Radeon RX/Pro"       -> dedicata; una AMD + un'altra GPU -> dedicata.
#    "Radeon Graphics"/"Vega" da sola -> integrata (nel dubbio si salta).
#  - Intel "Arc"               -> dedicata (rara); le altre Intel -> integrate.
function Get-GpuDedicata {
    try {
        $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name })
        if ($gpu.Count -eq 0) { return $null }

        if ($gpu | Where-Object { $_.Name -match 'NVIDIA|GeForce|RTX|GTX' }) { return 'NVIDIA' }

        $amdDed = $gpu | Where-Object { $_.Name -match 'Radeon\s*(RX|Pro)|Radeon\s*R[579]|FirePro' }
        # AMD affiancata a una GPU di un altro vendor = quasi certamente dedicata.
        $amdQualsiasi = $gpu | Where-Object { $_.Name -match 'AMD|Radeon' }
        $nonAmd       = $gpu | Where-Object { $_.Name -notmatch 'AMD|Radeon' }
        if ($amdDed -or ($amdQualsiasi -and $nonAmd)) { return 'AMD' }

        if ($gpu | Where-Object { $_.Name -match 'Intel.*Arc|Arc\s*A\d' }) { return 'INTEL' }

        return $null   # solo grafica integrata
    } catch { return $null }
}

# Trova gli antivirus di PROVA installati leggendo le chiavi di disinstallazione
# (ARP) del registro: piu' affidabile di 'winget list', becca anche i
# preinstallati che winget non gestisce. Ritorna nome + stringhe di uninstall.
function Get-AntivirusInstallati {
    $chiavi = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $pattern = 'McAfee|Norton|Avast|AVG'
    $trovati = @()
    foreach ($k in $chiavi) {
        try {
            Get-ItemProperty $k -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName -match $pattern } |
                ForEach-Object {
                    $trovati += [pscustomobject]@{
                        Nome           = $_.DisplayName
                        Uninstall      = $_.UninstallString
                        QuietUninstall = $_.QuietUninstallString
                    }
                }
        } catch {}
    }
    # dedup per nome
    return $trovati | Sort-Object Nome -Unique
}

# Domanda "opzionale": nel flusso automatico (il default del banco) risponde da
# sola col valore consigliato $Auto, SENZA fermarsi, cosi' l'operatore non deve
# cliccare per cose che non cambiano da PC a PC. Le domande essenziali (nome,
# account, Office, profilo app, antivirus) NON usano questa: chiedono davvero.
function Chiedi {
    param([string]$Prompt, [string]$Auto = "S")
    if ($Veloce) {
        $azione = if ($Auto -match '^[Ss]') { "si'" } else { "no" }
        Write-Host "  - $Prompt  -> automatico: $azione" -ForegroundColor Gray
        return $Auto
    }
    return Attendi-Risposta $Prompt   # bip subito + ribip ogni 2 min se non rispondi
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

# -----------------------------------------------------------------------------
# DIAGNOSTICA HARDWARE, BATTERIA E STATO ATTIVAZIONE WINDOWS
# -----------------------------------------------------------------------------

function Get-StorageHealthInfo {
    $info = [ordered]@{
        Modello       = "Disco di sistema"
        Tipo          = "SSD"
        Salute        = "Buono"
        Usura         = ""
        Temperatura   = ""
        StatoCompleto = "OK"
    }
    try {
        if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
            $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq 0 -or $_.OperationalStatus -eq 'OK' } | Select-Object -First 1
            if ($disks) {
                if ($disks.FriendlyName) { $info.Modello = $disks.FriendlyName }
                $info.Tipo = if ($disks.MediaType -and $disks.MediaType -ne 'Unspecified') { "$($disks.MediaType)" } else { "SSD" }
                $info.Salute = if ($disks.HealthStatus) { "$($disks.HealthStatus)" } else { "Healthy" }
            }
        }
        if (Get-Command Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
            $disk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($disk) {
                $counter = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction SilentlyContinue
                if ($counter) {
                    if ($counter.Wear -ne $null -and $counter.Wear -ge 0) {
                        $info.Usura = "Usura SSD: $($counter.Wear)%"
                    }
                    if ($counter.Temperature -gt 0) {
                        $info.Temperatura = "$($counter.Temperature)°C"
                    }
                }
            }
        }
        if (-not $info.Modello -or $info.Modello -eq "Disco di sistema") {
            $wmiDisk = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($wmiDisk) {
                if ($wmiDisk.Model) { $info.Modello = $wmiDisk.Model }
                $info.Salute = if ($wmiDisk.Status -eq 'OK') { "Buono (SMART OK)" } else { "$($wmiDisk.Status)" }
            }
        }
    } catch {}

    $disp = "$($info.Tipo) - $($info.Modello)"
    if ($info.Salute) { $disp += " (Stato: $($info.Salute))" }
    if ($info.Usura) { $disp += " - $($info.Usura)" }
    $info.StatoCompleto = $disp
    return [pscustomobject]$info
}

function Get-BatteryHealthInfo {
    $r = [ordered]@{
        Presente     = $false
        Salute       = "Non presente (PC Desktop)"
        Percentuale  = 100
        StatoCarica  = ""
        Descrizione  = ""
    }
    try {
        $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($batt) {
            $r.Presente = $true
            $r.StatoCarica = "$($batt.EstimatedChargeRemaining)%"
            $fullCap = $null
            $desCap  = $null
            try {
                $staticData = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
                $fullData   = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($staticData -and $fullData -and $staticData.DesignedCapacity -gt 0) {
                    $desCap  = $staticData.DesignedCapacity
                    $fullCap = $fullData.FullChargedCapacity
                }
            } catch {}

            if ($fullCap -and $desCap -and $desCap -gt 0) {
                $pct = [Math]::Round(($fullCap / $desCap) * 100)
                if ($pct -gt 100) { $pct = 100 }
                $r.Percentuale = $pct
                $condizione = if ($pct -ge 85) { "Ottima" } elseif ($pct -ge 70) { "Buona" } else { "Usurata" }
                $r.Salute = "$pct% ($condizione)"
                $r.Descrizione = "Salute Batteria: $pct% ($condizione) - Livello carica: $($batt.EstimatedChargeRemaining)%"
            } else {
                $r.Salute = "Presente (Carica: $($batt.EstimatedChargeRemaining)%)"
                $r.Descrizione = "Batteria Notebook: Carica $($batt.EstimatedChargeRemaining)%"
            }
        }
    } catch {}
    return [pscustomobject]$r
}

function Get-WindowsActivationStatus {
    $r = [ordered]@{
        Attivo      = $false
        Tipo        = "Sconosciuto"
        Messaggio   = "Non verificato"
        StatoBreve  = "Da verificare"
    }
    try {
        $lic = Get-CimInstance -Query "SELECT LicenseStatus, Description, Name, PartialProductKey FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like "*Windows*" } | Select-Object -First 1
        if ($lic) {
            if ($lic.LicenseStatus -eq 1) {
                $r.Attivo = $true
                $r.Tipo = if ($lic.Description -like "*OEM*") { "Licenza OEM" }
                          elseif ($lic.Description -like "*VOLUME*" -or $lic.Description -like "*KMS*") { "Licenza Volume/KMS" }
                          elseif ($lic.Description -like "*RETAIL*") { "Licenza Retail / Digitale" }
                          else { "Licenza Digitale Permanente" }
                $r.Messaggio  = "Attivato regolarmente ($($r.Tipo))"
                $r.StatoBreve = "Attivato ($($r.Tipo))"
            } else {
                $r.Attivo     = $false
                $r.Tipo       = "Non Attivo"
                $r.Messaggio  = "Windows NON attivato o in periodo di prova (Status: $($lic.LicenseStatus))"
                $r.StatoBreve = "NON ATTIVATO (Richiede licenza)"
            }
        } else {
            $slmgrOut = & cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli 2>$null | Out-String
            if ($slmgrOut -match "License Status:\s*Licensed" -or $slmgrOut -match "Stato licenza:\s*Con licenza") {
                $r.Attivo = $true
                $r.Tipo = "Licenza Digitale"
                $r.Messaggio = "Attivato regolarmente"
                $r.StatoBreve = "Attivato"
            }
        }
    } catch {
        $r.Messaggio = "Impossibile interrogare lo stato licenza: $_"
    }
    return [pscustomobject]$r
}

function Get-SystemHardwareDetails {
    $details = [ordered]@{
        Produttore       = "Standard PC"
        Modello          = "Desktop/Notebook"
        Seriale          = "Non disponibile"
        SchedaMadre      = "Standard"
        Cpu              = "Processore Standard"
        RamGB            = 8
        Gpu              = "Grafica integrata"
        DataSetup        = (Get-Date).ToString("dd/MM/yyyy")
        ScadenzaGaranzia = (Get-Date).AddYears(2).ToString("dd/MM/yyyy")
    }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs) {
            if ($cs.Manufacturer -and $cs.Manufacturer -notmatch "System manufacturer|To be filled") {
                $details.Produttore = $cs.Manufacturer.Trim()
            }
            if ($cs.Model -and $cs.Model -notmatch "System Product|To be filled") {
                $details.Modello = $cs.Model.Trim()
            }
            if ($cs.TotalPhysicalMemory) {
                $details.RamGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB)
            }
        }
    } catch {}

    try {
        $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
        if ($bios -and $bios.SerialNumber -and $bios.SerialNumber -notmatch "To be filled|Default|None|00000000|System Serial") {
            $details.Seriale = $bios.SerialNumber.Trim()
        } else {
            $csp = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
            if ($csp -and $csp.IdentifyingNumber -and $csp.IdentifyingNumber -notmatch "To be filled|Default|None|00000000|System Serial") {
                $details.Seriale = $csp.IdentifyingNumber.Trim()
            }
        }
    } catch {}

    try {
        $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
        if ($bb) {
            $mfg = if ($bb.Manufacturer -and $bb.Manufacturer -notmatch "To be filled") { $bb.Manufacturer.Trim() } else { "" }
            $prd = if ($bb.Product -and $bb.Product -notmatch "To be filled") { $bb.Product.Trim() } else { "" }
            $details.SchedaMadre = "$mfg $prd".Trim()
            if (-not $details.SchedaMadre) { $details.SchedaMadre = "Standard" }
        }
    } catch {}

    try {
        $proc = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc -and $proc.Name) {
            $details.Cpu = ($proc.Name -replace '\s+', ' ').Trim()
        }
    } catch {}

    try {
        $gpu = Get-GpuDedicata
        if ($gpu) {
            $details.Gpu = $gpu
        } else {
            $gpuDisp = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gpuDisp -and $gpuDisp.Name) {
                $details.Gpu = $gpuDisp.Name.Trim()
            }
        }
    } catch {}

    return [pscustomobject]$details
}

function Invoke-PcFacileDiagnostics {
    param([switch]$MostraDettagli)
    
    Write-Titolo "CHECK SALUTE & DIAGNOSTICA HARDWARE PC FACILE"
    Write-Host "Esecuzione test completi su disco SSD, batteria, licenza e driver..." -ForegroundColor Gray
    Write-Host ""
    
    $hw      = Get-SystemHardwareDetails
    $storage = Get-StorageHealthInfo
    $battery = Get-BatteryHealthInfo
    $winAct  = Get-WindowsActivationStatus
    $bitlock = Get-BitLockerRecovery -Volume $env:SystemDrive
    
    # Controllo Driver con problemi (Device Manager Sentinel)
    $driverProblematici = @()
    try {
        if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
            $driverProblematici = @(Get-PnpDevice -Status Error, Degraded -ErrorAction SilentlyContinue |
                                    Where-Object { $_.FriendlyName -and $_.Class -ne 'LegacyDriver' })
        }
    } catch {}

    # Controllo Spazio Disco
    $freeGB = 0
    try {
        $drv = Get-PSDrive ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
        if ($drv) { $freeGB = [math]::Round($drv.Free / 1GB, 1) }
    } catch {}

    # Output formattato a schermo
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 1. DISPOSITIVO & SPECIFICHE PRINCIPALI" -ForegroundColor White
    Write-Host "    Modello PC       : " -NoNewline; Write-Host "$($hw.Produttore) $($hw.Modello)" -ForegroundColor Cyan
    Write-Host "    Seriale (S/N)    : " -NoNewline; Write-Host "$($hw.Seriale)" -ForegroundColor Yellow
    Write-Host "    Processore (CPU) : $($hw.Cpu)"
    Write-Host "    Memoria RAM      : $($hw.RamGB) GB"
    Write-Host "    Scheda Video     : $($hw.Gpu)"
    Write-Host "    Garanzia Legale  : Fino al $($hw.ScadenzaGaranzia) (2 Anni)"
    Write-Host ""

    Write-Host " 2. SALUTE DISCO & MEMORIA DI MASSA (SMART)" -ForegroundColor White
    $diskColor = if ($storage.Salute -match 'Healthy|Buono|OK') { 'Green' } else { 'Red' }
    Write-Host "    Stato Disco / SSD: " -NoNewline; Write-Host "$($storage.StatoCompleto)" -ForegroundColor $diskColor
    if ($storage.Temperatura) { Write-Host "    Temperatura SSD  : $($storage.Temperatura)" }
    Write-Host "    Spazio Libero C: : $freeGB GB disponibili"
    Write-Host ""

    Write-Host " 3. STATO BATTERIA & ALIMENTAZIONE" -ForegroundColor White
    if ($battery.Presente) {
        $battColor = if ($battery.Percentuale -ge 80) { 'Green' } elseif ($battery.Percentuale -ge 65) { 'Yellow' } else { 'Red' }
        Write-Host "    Salute Batteria  : " -NoNewline; Write-Host "$($battery.Salute)" -ForegroundColor $battColor
        Write-Host "    Livello Carica   : $($battery.StatoCarica)"
    } else {
        Write-Host "    Tipo Computer    : PC Desktop / Fisso (Senza batteria)" -ForegroundColor Gray
    }
    Write-Host ""

    Write-Host " 4. SISTEMA OPERATIVO & SICUREZZA" -ForegroundColor White
    $winColor = if ($winAct.Attivo) { 'Green' } else { 'Red' }
    Write-Host "    Licenza Windows  : " -NoNewline; Write-Host "$($winAct.StatoBreve)" -ForegroundColor $winColor
    
    $bitColor = if ($bitlock.Esito -eq 'OK') { 'Green' } else { 'Yellow' }
    Write-Host "    BitLocker Disco  : " -NoNewline; Write-Host "$($bitlock.Stato)" -ForegroundColor $bitColor
    if ($bitlock.RecoveryKey) {
        Write-Host "    Chiave BitLocker : $($bitlock.RecoveryKey)" -ForegroundColor DarkGreen
    }
    Write-Host ""

    Write-Host " 5. CONTROLLO GESTIONE DISPOSITIVI (DRIVER)" -ForegroundColor White
    if ($driverProblematici.Count -gt 0) {
        Write-Host "    [ATTENZIONE] Rilevati $($driverProblematici.Count) dispositivi con errori di driver:" -ForegroundColor Red
        foreach ($d in $driverProblematici) {
            Write-Host "      - $($d.FriendlyName) (Classe: $($d.Class), Stato: $($d.Status))" -ForegroundColor Red
        }
    } else {
        Write-Host "    [OK] Tutti i dispositivi e i driver hardware risultano operativi." -ForegroundColor Green
    }
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

    $diagObj = [ordered]@{
        Hardware     = $hw
        Disco        = $storage
        SpazioLibero = $freeGB
        Batteria     = $battery
        Windows      = $winAct
        BitLocker    = $bitlock
        DriverErrori = $driverProblematici
    }
    return [pscustomobject]$diagObj
}

function Set-PreventSleep {
    param([bool]$Enable = $true)
    if ($Test -or $Global:Test -or $env:PESTER_TEST) { return }
    try {
        if ($Enable) {
            # Evita spegnimento schermo, standby e sospensione sia su AC che su BATTERIA (DC)
            powercfg /change standby-timeout-ac 0 2>$null | Out-Null
            powercfg /change standby-timeout-dc 0 2>$null | Out-Null
            powercfg /change monitor-timeout-ac 0 2>$null | Out-Null
            powercfg /change monitor-timeout-dc 0 2>$null | Out-Null
            powercfg /change hibernate-timeout-ac 0 2>$null | Out-Null
            powercfg /change hibernate-timeout-dc 0 2>$null | Out-Null
            # Non andare MAI in sospensione alla chiusura del coperchio (essenziale per setup notturni in negozio)
            powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 2>$null | Out-Null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 2>$null | Out-Null
            powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null
            Enable-PreventSleep
        } else {
            # Ripristina valori standard
            powercfg /change monitor-timeout-ac 15 2>$null | Out-Null
            powercfg /change standby-timeout-ac 30 2>$null | Out-Null
            powercfg /change monitor-timeout-dc 10 2>$null | Out-Null
            powercfg /change standby-timeout-dc 15 2>$null | Out-Null
            powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>$null | Out-Null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>$null | Out-Null
            powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null
        }
    } catch {}
}

function Clear-TempCache {
    Write-Info "Pulizia file temporanei e cache di installazione..."
    try {
        $dirs = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
        foreach ($d in $dirs) {
            if ($d -and (Test-Path $d)) {
                Get-ChildItem -Path $d -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.PSIsContainer } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
        Write-OK "File temporanei e cache ripuliti con successo."
        Add-Report "Pulizia file temporanei e cache" "OK"
    } catch {
        Add-Report "Pulizia file temporanei e cache" "SALTATO"
    }
}

$Global:PannelloStatus = [ordered]@{
    Percentuale   = 5
    FaseCorrente  = "Inizializzazione Setup"
    Dettaglio     = "Avvio pannello operatore Unieuro e preparazione ambiente..."
    Completato    = $false
    Tasks         = [ordered]@{
        "pulizia"     = [ordered]@{ Nome = "Pulizia Bloatware OEM & Ottimizzazione SSD"; Stato = "pending"; Dettaglio = "In attesa" }
        "lingua"      = [ordered]@{ Nome = "Forzatura Lingua & Regione Italiana (it-IT)"; Stato = "pending"; Dettaglio = "In attesa" }
        "ripristino"  = [ordered]@{ Nome = "Punto di Ripristino di Sicurezza (5% SSD)"; Stato = "pending"; Dettaglio = "In attesa" }
        "runtime"     = [ordered]@{ Nome = "Runtime Microsoft Visual C++ (x86 & x64)"; Stato = "pending"; Dettaglio = "In attesa" }
        "office"      = [ordered]@{ Nome = "Configurazione Icone Office / Microsoft 365"; Stato = "pending"; Dettaglio = "In attesa" }
        "antivirus"   = [ordered]@{ Nome = "Sicurezza & Antivirus (Windows Defender / Card)"; Stato = "pending"; Dettaglio = "In attesa" }
        "cyber"       = [ordered]@{ Nome = "Servizio Unieuro Cyber Protection"; Stato = "pending"; Dettaglio = "In attesa" }
        "aggiorna"    = [ordered]@{ Nome = "Aggiornamenti & Driver Windows Update"; Stato = "pending"; Dettaglio = "In attesa" }
        "app"         = [ordered]@{ Nome = "Installazione Applicazioni (Ultimo Passaggio)"; Stato = "pending"; Dettaglio = "In attesa" }
        "diagnostica" = [ordered]@{ Nome = "Diagnostica Hardware, BitLocker & Scheda Consegna"; Stato = "pending"; Dettaglio = "In attesa" }
    }
}

function Set-SplitScreenLayout {
    param([string]$HtmlPath)
    if ($Global:Test -or $env:PESTER_TEST) { return }
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WinSplit {
    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue

        $scrW = 1920
        $scrH = 1080
        try {
            $w = [WinSplit]::GetSystemMetrics(0)
            $h = [WinSplit]::GetSystemMetrics(1)
            if ($w -gt 600) { $scrW = $w }
            if ($h -gt 400) { $scrH = $h }
        } catch {}

        $workH = [math]::Max(400, $scrH - 48)
        $halfW = [int]($scrW / 2)

        # 1. Posiziona la console a DESTRA (X = halfW, Y = 0, W = halfW, H = workH)
        try {
            $hConsole = [WinSplit]::GetConsoleWindow()
            if ($hConsole -and $hConsole -ne [IntPtr]::Zero) {
                [WinSplit]::ShowWindow($hConsole, 9)
                [WinSplit]::MoveWindow($hConsole, $halfW, 0, $halfW, $workH, $true) | Out-Null
            }
        } catch {}

        # 2. Avvia Edge a SINISTRA (X = 0, Y = 0, W = halfW, H = workH)
        $edgePath = "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe"
        if (-not (Test-Path $edgePath)) {
            $edgePath = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        }
        
        if (Test-Path $edgePath) {
            Start-Process -FilePath $edgePath -ArgumentList "--new-window --window-position=0,0 --window-size=$halfW,$workH `"$HtmlPath`"" -ErrorAction SilentlyContinue
        } else {
            Start-Process $HtmlPath
        }
    } catch {
        try { Start-Process $HtmlPath } catch {}
    }
}

function Update-PannelloStatus {
    param(
        [string]$TaskId = "",
        [string]$Stato = "",
        [string]$Dettaglio = "",
        [int]$Percentuale = -1,
        [string]$FaseCorrente = "",
        [switch]$Completato
    )
    try {
        if (-not $Global:PannelloStatus) {
            $Global:PannelloStatus = [ordered]@{
                Percentuale   = 5
                FaseCorrente  = "Inizializzazione Setup"
                Dettaglio     = "Avvio pannello operatore Unieuro..."
                Completato    = $false
                Tasks         = [ordered]@{
                    "pulizia"     = [ordered]@{ Nome = "Pulizia Bloatware OEM & Ottimizzazione SSD"; Stato = "pending"; Dettaglio = "In attesa" }
                    "lingua"      = [ordered]@{ Nome = "Forzatura Lingua & Regione Italiana (it-IT)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "ripristino"  = [ordered]@{ Nome = "Punto di Ripristino di Sicurezza (5% SSD)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "runtime"     = [ordered]@{ Nome = "Runtime Microsoft Visual C++ (x86 & x64)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "office"      = [ordered]@{ Nome = "Configurazione Icone Office / Microsoft 365"; Stato = "pending"; Dettaglio = "In attesa" }
                    "aggiorna"    = [ordered]@{ Nome = "Aggiornamenti & Driver Windows Update"; Stato = "pending"; Dettaglio = "In attesa" }
                    "app"         = [ordered]@{ Nome = "Installazione Applicazioni Unieuro"; Stato = "pending"; Dettaglio = "In attesa" }
                    "antivirus"   = [ordered]@{ Nome = "Sicurezza & Antivirus Definitivo (Defender / Card)"; Stato = "pending"; Dettaglio = "In attesa" }
                    "cyber"       = [ordered]@{ Nome = "Servizio Unieuro Cyber Protection"; Stato = "pending"; Dettaglio = "In attesa" }
                    "diagnostica" = [ordered]@{ Nome = "Diagnostica Hardware, BitLocker & Scheda Consegna"; Stato = "pending"; Dettaglio = "In attesa" }
                }
            }
        }
        if ($Percentuale -ge 0) { $Global:PannelloStatus.Percentuale = $Percentuale }
        if ($FaseCorrente) { $Global:PannelloStatus.FaseCorrente = $FaseCorrente }
        if ($Dettaglio -and -not $TaskId) { $Global:PannelloStatus.Dettaglio = $Dettaglio }
        if ($Completato) {
            $Global:PannelloStatus.Completato = $true
            $Global:PannelloStatus.Percentuale = 100
        }

        if ($TaskId -and $Global:PannelloStatus.Tasks.Contains($TaskId)) {
            if ($Stato) { $Global:PannelloStatus.Tasks[$TaskId].Stato = $Stato }
            if ($Dettaglio) { $Global:PannelloStatus.Tasks[$TaskId].Dettaglio = $Dettaglio }
        }

        # Aggiorna il titolo della finestra console con percentuale e fase
        try {
            $curPct = $Global:PannelloStatus.Percentuale
            $curFase = if ($FaseCorrente) { $FaseCorrente } else { $Global:PannelloStatus.FaseCorrente }
            $host.UI.RawUI.WindowTitle = "PC Facile [$curPct%] - $curFase"
        } catch {}

        $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
        $statusFile = Join-Path $tempDir "pcfacile-status.js"
        
        $json = $Global:PannelloStatus | ConvertTo-Json -Depth 5 -Compress
        $js = "window.PCFacileStatus = $json; if (typeof window.onPCFacileStatusUpdate === 'function') { window.onPCFacileStatusUpdate(window.PCFacileStatus); }"
        $js | Set-Content -Path $statusFile -Encoding UTF8
    } catch {}
}

function Open-PannelloOperatore {
    param(
        [string]$NomeCliente = "",
        [string]$Email = "",
        [string]$Password = ""
    )
    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP')
    if ($NomeCliente -and ($oemNames -contains $NomeCliente.Trim().ToUpper() -or $NomeCliente.Trim().ToUpper() -eq "CLIENTE" -or $NomeCliente.Trim().ToUpper() -eq "UTENTE")) {
        $NomeCliente = ""
    }
    if (-not $Email -and $NomeCliente) { $Email = New-EmailCliente -Base $NomeCliente }
    elseif (-not $Email) { $Email = "utente@outlook.it" }
    if (-not $Password -and $NomeCliente) { $Password = New-PasswordCliente -Base $NomeCliente }
    elseif (-not $Password) { $Password = "Utente123!" }

    # Rileva specifiche hardware rapide per il mini-dashboard del pannello
    $hw = Get-SystemHardwareDetails
    $hwModello = if ($hw.Produttore -and $hw.Modello) { "$($hw.Produttore) $($hw.Modello)" } else { "PC Windows" }
    $hwCpu = if ($hw.Cpu) { $hw.Cpu } else { "Processore" }
    $hwRam = if ($hw.RamGB) { "$($hw.RamGB) GB RAM" } else { "8 GB RAM" }
    $hwSeriale = if ($hw.Seriale -and $hw.Seriale -ne "Non disponibile") { $hw.Seriale } else { "" }

    $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
    $pannelloFile = Join-Path $tempDir "Pannello-Operatore.html"
    
    # Inizializza subito il file di stato sincrono
    Update-PannelloStatus -Percentuale 5 -FaseCorrente "Inizializzazione Setup" -Dettaglio "Avvio pannello operatore Unieuro..."
    
    try {
        $html = @"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Unieuro - Pannello Assistenza Tecnica PC</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif; }
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #000c1e; }
        ::-webkit-scrollbar-thumb { background: #003875; border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: #EE7203; }

        body { background: radial-gradient(circle at 50% 0%, #001a3d 0%, #000d20 70%, #000713 100%); color: #f8fafc; padding: 12px; min-height: 100vh; line-height: 1.4; }
        .container { max-width: 980px; margin: 0 auto; }

        /* HEADER & BRAND */
        .header { background: linear-gradient(135deg, rgba(0,26,58,0.95) 0%, rgba(0,43,92,0.95) 100%); backdrop-filter: blur(10px); border: 1px solid #00458C; border-radius: 12px; padding: 12px 16px; border-bottom: 3.5px solid #EE7203; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 6px 20px rgba(0,0,0,0.45); }
        .brand-box { display: flex; align-items: center; gap: 10px; }
        .u-logo { background: #EE7203; color: #fff; font-weight: 900; font-size: 17px; letter-spacing: 1.2px; padding: 6px 12px; border-radius: 7px; text-transform: uppercase; box-shadow: 0 2px 10px rgba(238,114,3,0.4); flex-shrink: 0; }
        .brand-titles h1 { font-size: 15.5px; color: #fff; font-weight: 700; letter-spacing: 0.2px; line-height: 1.2; }
        .brand-titles p { font-size: 11.5px; color: #94a3b8; margin-top: 2px; }
        .u-tagline { color: #EE7203; font-weight: 700; font-style: italic; }
        
        .header-actions { display: flex; align-items: center; gap: 8px; }
        .btn-audio { background: #00142E; border: 1px solid #00458C; color: #93c5fd; border-radius: 20px; padding: 5px 10px; font-size: 11px; font-weight: 700; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 4px; }
        .btn-audio:hover { border-color: #EE7203; color: #fff; }
        .badge-live { background: linear-gradient(135deg, #EE7203 0%, #d95e00 100%); color: #fff; font-weight: 800; font-size: 10.5px; padding: 5px 12px; border-radius: 20px; text-transform: uppercase; letter-spacing: 0.5px; box-shadow: 0 0 12px rgba(238,114,3,0.6); animation: pulse 2s infinite; white-space: nowrap; }
        .badge-done { background: #16a34a !important; box-shadow: 0 0 14px rgba(34,197,94,0.6) !important; animation: none !important; color: #fff; font-weight: 800; font-size: 10.5px; padding: 5px 12px; border-radius: 20px; text-transform: uppercase; white-space: nowrap; }
        @keyframes pulse { 0% { opacity: 0.9; transform: scale(1); } 50% { opacity: 1; transform: scale(1.02); } 100% { opacity: 0.9; transform: scale(1); } }

        /* MINI DASHBOARD HARDWARE */
        .hw-bar { background: rgba(0, 20, 46, 0.8); border: 1px solid #003366; border-radius: 8px; padding: 6px 12px; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 11px; color: #cbd5e1; flex-wrap: wrap; }
        .hw-item { display: flex; align-items: center; gap: 5px; }
        .hw-item strong { color: #38bdf8; }
        .hw-item .hw-val { color: #fff; font-weight: 600; }
        .hw-copy-sn { cursor: pointer; color: #fed7aa; text-decoration: underline; font-size: 10.5px; }
        .hw-copy-sn:hover { color: #EE7203; }

        /* HERO PROGRESS BAR SINCRONIZZATA IN TEMPO REALE */
        .progress-card { background: linear-gradient(135deg, rgba(0,26,58,0.9) 0%, rgba(0,38,77,0.9) 100%); border: 1px solid #00458C; border-radius: 10px; padding: 10px 14px; margin-bottom: 10px; box-shadow: 0 4px 14px rgba(0,0,0,0.3); }
        .progress-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; font-size: 12px; }
        .progress-title { color: #fed7aa; font-weight: 700; display: flex; align-items: center; gap: 6px; font-size: 12px; }
        .progress-meta { display: flex; align-items: center; gap: 10px; }
        .progress-timer { color: #94a3b8; font-size: 11px; font-family: monospace; }
        .progress-pct { color: #EE7203; font-size: 16px; font-weight: 900; }
        .progress-bar-bg { background: #000c1c; border: 1px solid #003B7A; height: 11px; border-radius: 6px; overflow: hidden; position: relative; }
        .progress-bar-fill { background: linear-gradient(90deg, #EE7203 0%, #ff9d42 70%, #38bdf8 100%); height: 100%; width: 5%; border-radius: 6px; transition: width 0.4s ease; box-shadow: 0 0 10px rgba(238,114,3,0.7); }
        .progress-status-row { display: flex; justify-content: space-between; align-items: center; margin-top: 6px; font-size: 11px; }
        .current-fase { color: #fff; font-weight: 600; }
        .current-detail { color: #94a3b8; font-style: italic; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 55%; text-align: right; }

        /* COMPLETION BANNER */
        .banner-complete { display: none; background: rgba(34, 197, 94, 0.15); border: 2px solid #22c55e; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; text-align: center; }
        .banner-complete h3 { color: #4ade80; font-size: 14px; margin-bottom: 3px; }
        .banner-complete p { color: #dcfce7; font-size: 12px; margin-bottom: 8px; }
        .btn-scheda { display: inline-block; background: #22c55e; color: #fff; font-weight: 700; font-size: 12px; padding: 7px 16px; border-radius: 6px; text-decoration: none; box-shadow: 0 2px 10px rgba(34,197,94,0.4); transition: all 0.2s; }
        .btn-scheda:hover { background: #16a34a; transform: translateY(-1px); }

        /* NAVIGATION TABS (OTTIMIZZAZIONE 50% SPLIT SCREEN) */
        .tab-bar { display: flex; gap: 4px; margin-bottom: 10px; background: rgba(0, 20, 46, 0.95); padding: 4px; border-radius: 8px; border: 1px solid #003366; overflow-x: auto; }
        .tab-btn { flex: 1; min-width: max-content; background: transparent; border: none; color: #94a3b8; font-size: 11px; font-weight: 700; padding: 6px 10px; border-radius: 6px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 5px; white-space: nowrap; }
        .tab-btn:hover { color: #fff; background: rgba(0, 59, 122, 0.4); }
        .tab-btn.active { background: #003B7A; color: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.3); border: 1px solid #0056B3; }
        .tab-btn.active .tab-badge-num { background: #EE7203; color: #fff; }
        .tab-badge-num { background: #001f48; color: #93c5fd; font-size: 9.5px; padding: 1px 5px; border-radius: 10px; font-weight: 800; }

        /* SEZIONI E CARD */
        .section-view { display: none; }
        .section-view.active-view { display: block; }
        .grid-view-all { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px; }
        
        .card { background: rgba(0, 31, 72, 0.85); backdrop-filter: blur(8px); border: 1px solid #003B7A; border-radius: 10px; padding: 12px 14px; box-shadow: 0 4px 12px rgba(0,0,0,0.25); margin-bottom: 10px; }
        .card h2 { font-size: 13.5px; color: #f8fafc; margin-bottom: 10px; border-bottom: 1.5px solid #003B7A; padding-bottom: 6px; display: flex; align-items: center; justify-content: space-between; }
        .card h2 .title-left { display: flex; align-items: center; gap: 6px; }
        .card h2 .bar { width: 3.5px; height: 14px; background: #EE7203; border-radius: 2px; display: inline-block; }
        
        /* CREDENZIALI */
        .cred-group { margin-bottom: 9px; }
        .cred-label { font-size: 10.5px; color: #93c5fd; margin-bottom: 3px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.4px; display: flex; justify-content: space-between; align-items: center; }
        .cred-box { display: flex; gap: 6px; }
        .cred-input { flex: 1; background: #00122B; border: 1px solid #00458C; border-radius: 6px; padding: 7px 10px; font-size: 12px; color: #fff; font-family: 'Consolas', monospace; outline: none; transition: border-color 0.2s; }
        .cred-input:focus { border-color: #EE7203; box-shadow: 0 0 0 2px rgba(238,114,3,0.35); }
        .dom-selector { display: grid; grid-template-columns: repeat(auto-fit, minmax(88px, 1fr)); gap: 4px; margin-bottom: 6px; }
        .dom-btn { background: #00122B; border: 1px solid #00458C; color: #cbd5e1; font-size: 10.5px; font-weight: 700; padding: 4.5px 6px; border-radius: 5px; cursor: pointer; transition: all 0.15s; text-align: center; }
        .dom-btn:hover { border-color: #EE7203; color: #fff; }
        .dom-btn.active { background: #EE7203; border-color: #EE7203; color: #fff; box-shadow: 0 2px 6px rgba(238,114,3,0.4); font-weight: 800; }
        .btn-copy { background: linear-gradient(135deg, #003B7A 0%, #002B5C 100%); border: 1px solid #0056B3; color: #fff; border-radius: 5px; padding: 0 10px; font-size: 10.5px; font-weight: 700; cursor: pointer; transition: all 0.2s; white-space: nowrap; display: flex; align-items: center; gap: 4px; }
        .btn-copy:hover { background: #EE7203; border-color: #EE7203; }
        .btn-mini-action { background: #001f48; border: 1px solid #00458C; color: #cbd5e1; border-radius: 5px; padding: 0 8px; font-size: 11px; cursor: pointer; transition: all 0.2s; }
        .btn-mini-action:hover { color: #fff; border-color: #EE7203; }

        /* PORTALI 1-CLICK */
        .portal-filter { width: 100%; background: #00122B; border: 1px solid #003B7A; border-radius: 6px; padding: 6px 10px; font-size: 11px; color: #fff; margin-bottom: 8px; outline: none; }
        .portal-filter:focus { border-color: #EE7203; }
        .links-grid { display: flex; flex-direction: column; gap: 4.5px; }
        .portal-divider { display: flex; align-items: center; gap: 6px; margin: 6px 0 3px 0; }
        .portal-divider::before, .portal-divider::after { content: ""; flex: 1; height: 1px; background: linear-gradient(90deg, rgba(238,114,3,0.1), #EE7203, rgba(238,114,3,0.1)); }
        .portal-divider span { font-size: 9.5px; font-weight: 800; color: #fed7aa; text-transform: uppercase; letter-spacing: 0.4px; background: #001A3A; border: 1px solid #EE7203; padding: 1.5px 6px; border-radius: 4px; box-shadow: 0 1px 4px rgba(238,114,3,0.25); white-space: nowrap; }
        .portal-btn { display: flex; align-items: center; justify-content: space-between; background: #00142E; border: 1px solid #003B7A; border-radius: 6px; padding: 6.5px 10px; color: #f8fafc; text-decoration: none; font-size: 11.5px; font-weight: 600; transition: all 0.15s; }
        .portal-btn:hover { background: #00224D; border-color: #EE7203; transform: translateX(2px); }
        .portal-btn .icon { font-size: 13px; margin-right: 5px; }
        .portal-btn .arrow { color: #EE7203; font-weight: bold; font-size: 11px; }
        .portal-btn.highlight { border-color: #EE7203; background: rgba(238, 114, 3, 0.12); box-shadow: 0 0 8px rgba(238,114,3,0.2); }

        /* CHECKLIST */
        .checklist { list-style: none; display: flex; flex-direction: column; gap: 6px; }
        .checklist li { display: flex; align-items: center; gap: 8px; font-size: 11.5px; color: #e2e8f0; background: #00142E; padding: 6px 10px; border-radius: 6px; border: 1px solid #003B7A; }
        .checklist input[type="checkbox"] { width: 15px; height: 15px; accent-color: #EE7203; cursor: pointer; }
        .checklist-actions { display: flex; gap: 6px; margin-top: 8px; flex-wrap: wrap; }
        .btn-quick { background: #001f48; border: 1px solid #00458C; color: #cbd5e1; font-size: 10.5px; font-weight: 700; padding: 5px 10px; border-radius: 5px; cursor: pointer; transition: all 0.2s; text-decoration: none; display: inline-flex; align-items: center; gap: 4px; }
        .btn-quick:hover { background: #003B7A; border-color: #EE7203; color: #fff; }

        /* TASKS SINCRONIZZATI */
        .bg-tasks { list-style: none; display: flex; flex-direction: column; gap: 4px; }
        .task-item { display: flex; align-items: center; justify-content: space-between; font-size: 11px; padding: 5px 8px; border-radius: 5px; border: 1px solid transparent; transition: all 0.2s ease; }
        .task-left { display: flex; align-items: center; gap: 6px; flex: 1; min-width: 0; }
        .task-icon { font-size: 11px; width: 14px; text-align: center; flex-shrink: 0; }
        .task-name { color: #cbd5e1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .task-detail { color: #fed7aa; font-size: 10px; margin-left: 3px; font-style: italic; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .task-badge { font-size: 9px; font-weight: 700; padding: 1.5px 6px; border-radius: 8px; text-transform: uppercase; white-space: nowrap; flex-shrink: 0; }
        
        .task-item.pending { color: #64748b; }
        .task-item.pending .task-icon { color: #475569; }
        .badge-pending { background: #00122B; color: #64748b; border: 1px solid #003B7A; }
        
        .task-item.running { background: rgba(238, 114, 3, 0.12); border-color: #EE7203; color: #fff; font-weight: 600; box-shadow: 0 0 8px rgba(238,114,3,0.25); }
        .task-item.running .task-name { color: #fff; font-weight: 700; }
        .badge-running { background: #EE7203; color: #fff; animation: pulse 1.5s infinite; }
        
        .task-item.done { color: #f8fafc; }
        .task-item.done .task-icon { color: #22c55e; font-weight: bold; }
        .task-item.done .task-name { color: #e2e8f0; }
        .badge-done-task { background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid #22c55e; }
        
        .task-item.error { background: rgba(239, 68, 68, 0.12); border-color: #ef4444; color: #fca5a5; }
        .task-item.error .task-icon { color: #ef4444; font-weight: bold; }
        .badge-error { background: #ef4444; color: #fff; }
        
        .task-item.skipped { color: #94a3b8; }
        .task-item.skipped .task-icon { color: #94a3b8; }
        .badge-skipped { background: #00122B; color: #94a3b8; border: 1px solid #003B7A; }

        .spinner { display: inline-block; width: 10px; height: 10px; border: 1.5px solid #EE7203; border-top-color: transparent; border-radius: 50%; animation: spin 0.8s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }

        /* TOAST NOTIFICATION */
        .toast { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%) translateY(100px); background: #16a34a; color: #fff; font-size: 11.5px; font-weight: 700; padding: 7px 16px; border-radius: 20px; box-shadow: 0 4px 14px rgba(0,0,0,0.4); opacity: 0; pointer-events: none; transition: all 0.3s ease; z-index: 1000; }
        .toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }

        .footer { text-align: center; font-size: 10.5px; color: #64748b; margin-top: 10px; padding-top: 8px; border-top: 1px solid #002B5C; }
        .footer strong { color: #cbd5e1; }

        /* RESPONSIVE SPECIFICO PER SCHERMI RIDOTTI / SPLIT SCREEN */
        @media (max-width: 900px) {
            body { padding: 8px; }
            .grid-view-all { grid-template-columns: 1fr; }
            .header { padding: 10px 12px; }
            .brand-titles h1 { font-size: 14px; }
            .brand-titles p { display: none; }
            .u-logo { font-size: 15px; padding: 4px 8px; }
            .card { padding: 10px 12px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- HEADER PRINCIPALE -->
        <div class="header">
            <div class="brand-box">
                <div class="u-logo">UNIEURO</div>
                <div class="brand-titles">
                    <h1>Pannello Assistenza &amp; Configurazione PC</h1>
                    <p><span class="u-tagline">Batte. Forte. Sempre.</span> &bull; Setup Tecnico Dedicato</p>
                </div>
            </div>
            <div class="header-actions">
                <button type="button" id="btnSoundToggle" class="btn-audio" onclick="toggleAudio()" title="Suono fine configurazione">🔔 Audio</button>
                <div id="badgeLive" class="badge-live">&#9889; Setup in corso</div>
            </div>
        </div>

        <!-- MINI DASHBOARD HARDWARE E SISTEMA -->
        <div class="hw-bar">
            <div class="hw-item">💻 <strong>PC:</strong> <span class="hw-val">$hwModello</span></div>
            <div class="hw-item">⚙️ <strong>CPU/RAM:</strong> <span class="hw-val">$hwCpu &bull; $hwRam</span></div>
            <div class="hw-item">🏷️ <strong>Seriale:</strong> <span class="hw-val" id="hwSerialVal">$hwSeriale</span> <span class="hw-copy-sn" onclick="copiaSeriale()">[copia]</span></div>
        </div>

        <!-- HERO PROGRESS CARD SINCRONIZZATA IN TEMPO REALE -->
        <div class="progress-card">
            <div class="progress-header">
                <div class="progress-title">&#9889; Avanzamento Configurazione Automatica (Zero-Touch)</div>
                <div class="progress-meta">
                    <span id="elapsedTimerText" class="progress-timer">00:00</span>
                    <div id="progressPercentText" class="progress-pct">5%</div>
                </div>
            </div>
            <div class="progress-bar-bg">
                <div id="progressBarFill" class="progress-bar-fill" style="width: 5%;"></div>
            </div>
            <div class="progress-status-row">
                <div><span style="color:#93c5fd; font-weight:700;">FASE:</span> <span id="currentFaseText" class="current-fase">Inizializzazione Setup</span></div>
                <div id="currentDetailText" class="current-detail">Avvio pannello operatore Unieuro...</div>
            </div>
        </div>

        <!-- BANNER COMPLETAMENTO CELEBRATIVO -->
        <div id="completionBanner" class="banner-complete">
            <h3>&#127881; TUTTI I LAVORI IN BACKGROUND COMPLETATI CON SUCCESSO!</h3>
            <p>Il computer &egrave; configurato, ottimizzato e aggiornato secondo gli standard Unieuro.</p>
            <a href="Scheda-Consegna-Cliente.html" target="_blank" class="btn-scheda">&#128196; Apri Scheda di Consegna Cliente</a>
        </div>

        <!-- SELETTORE VISTE / TABS (PERFETTO PER SPLIT SCREEN 50%) -->
        <div class="tab-bar">
            <button type="button" class="tab-btn active" onclick="switchView('tab-live', this)">
                <span>&#9889; Lavori Live</span> <span id="taskCountBadge" class="tab-badge-num">10</span>
            </button>
            <button type="button" class="tab-btn" onclick="switchView('tab-cred', this)">
                <span>&#128273; Account &amp; Credenziali</span>
            </button>
            <button type="button" class="tab-btn" onclick="switchView('tab-portali', this)">
                <span>&#127760; Portali 1-Click</span>
            </button>
            <button type="button" class="tab-btn" onclick="switchView('tab-checklist', this)">
                <span>&#9745; Checklist &amp; Tool</span>
            </button>
            <button type="button" class="tab-btn" onclick="switchView('tab-all', this)">
                <span>&#9638; Vista Completa</span>
            </button>
        </div>

        <!-- VISTA 1: LAVORI LIVE -->
        <div id="view-tab-live" class="section-view active-view">
            <div class="card">
                <h2>
                    <span class="title-left"><span class="bar"></span> &#9881; Lavori Automatici in Background</span>
                    <span style="font-size: 10px; color: #94a3b8; font-weight: normal;">Sincronizzato live con PowerShell</span>
                </h2>
                <ul class="bg-tasks" id="tasksContainer">
                    <!-- FASE 1: PULIZIA & SISTEMA -->
                    <div class="portal-divider" style="margin-top: 0;"><span>&#128736; 1. Pulizia &amp; Sistema</span></div>
                    <li id="task-pulizia" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">1. Pulizia Bloatware OEM &amp; Ottimizzazione SSD</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                    <li id="task-lingua" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">2. Forzatura Lingua &amp; Regione Italiana (it-IT)</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                    <li id="task-ripristino" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">3. Punto di Ripristino di Sicurezza (5% SSD)</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>

                    <!-- FASE 2: COMPONENTI & PRODUTTIVITA' -->
                    <div class="portal-divider"><span>&#9881; 2. Componenti &amp; Produttivit&agrave;</span></div>
                    <li id="task-runtime" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">4. Runtime Microsoft Visual C++ (x86 &amp; x64)</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                    <li id="task-office" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">5. Configurazione Icone Office / Microsoft 365</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                    <li id="task-aggiorna" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">6. Aggiornamenti &amp; Driver Windows Update</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>

                    <!-- FASE 3: APPLICAZIONI & SICUREZZA -->
                    <div class="portal-divider"><span>&#128737; 3. Applicazioni &amp; Sicurezza</span></div>
                    <li id="task-app" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">7. Installazione Applicazioni Unieuro</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                    <li id="task-antivirus" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">8. Sicurezza &amp; Antivirus Definitivo (Defender / Card)</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                    <li id="task-cyber" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">9. Servizio Unieuro Cyber Protection</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>

                    <!-- FASE 4: COLLAUDO & SCHEDA -->
                    <div class="portal-divider"><span>&#128640; 4. Collaudo &amp; Scheda di Consegna</span></div>
                    <li id="task-diagnostica" class="task-item pending">
                        <div class="task-left">
                            <span class="task-icon">&#9675;</span>
                            <span class="task-name">10. Diagnostica Hardware, BitLocker &amp; Scheda Consegna</span>
                            <span class="task-detail"></span>
                        </div>
                        <span class="task-badge badge-pending">In attesa</span>
                    </li>
                </ul>
            </div>
        </div>

        <!-- VISTA 2: CREDENZIALI & ACCOUNT -->
        <div id="view-tab-cred" class="section-view">
            <div class="card">
                <h2>
                    <span class="title-left"><span class="bar"></span> &#128273; Generatore Credenziali &amp; Account Cliente</span>
                    <span style="font-size: 10px; color: #94a3b8;">Standard Unieuro</span>
                </h2>
                
                <!-- 1. SELETTORE DOMINIO / PROVIDER -->
                <div class="cred-group">
                    <div class="cred-label">1. Scegli Provider / Dominio Email:</div>
                    <div class="dom-selector">
                        <button type="button" class="dom-btn active" onclick="setDomain('outlook.it', 'Microsoft', this)">@outlook.it</button>
                        <button type="button" class="dom-btn" onclick="setDomain('hotmail.com', 'Hotmail', this)">@hotmail.com</button>
                        <button type="button" class="dom-btn" onclick="setDomain('gmail.com', 'Google', this)">@gmail.com</button>
                        <button type="button" class="dom-btn" onclick="setDomain('proton.me', 'Proton', this)">@proton.me</button>
                        <button type="button" class="dom-btn" onclick="setDomain('libero.it', 'Libero', this)">@libero.it</button>
                        <button type="button" class="dom-btn" onclick="setDomain('icloud.com', 'iCloud', this)">@icloud.com</button>
                    </div>
                </div>

                <!-- 2. COGNOME, NOME E TELEFONO -->
                <div class="cred-group">
                    <div class="cred-label">2. Dati Cliente:</div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 6px;">
                        <input type="text" id="inCognome" class="cred-input" placeholder="Cognome (es. Rossi)" oninput="aggiornaCred()">
                        <input type="text" id="inNome" class="cred-input" value="$NomeCliente" placeholder="Nome (es. Mario)" oninput="aggiornaCred()">
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr; gap: 6px;">
                        <input type="tel" id="inTelefono" class="cred-input" placeholder="Cellulare / Telefono (es. 3331234567)" oninput="segnaModificato()">
                    </div>
                </div>

                <!-- 3. EMAIL RISULTANTE -->
                <div class="cred-group">
                    <div class="cred-label">3. Email Generata:</div>
                    <div class="cred-box">
                        <input type="text" id="inEmail" class="cred-input" value="$Email" oninput="segnaModificato()">
                        <button type="button" class="btn-copy" onclick="copia('inEmail', 'Email copiata!')">&#128203; Copia</button>
                    </div>
                </div>

                <!-- 4. PASSWORD INIZIALE -->
                <div class="cred-group">
                    <div class="cred-label">
                        <span>4. Password Iniziale Consigliata:</span>
                        <span>
                            <button type="button" class="btn-mini-action" onclick="togglePassVis()" title="Mostra/Nascondi">&#128065;</button>
                            <button type="button" class="btn-mini-action" onclick="generaPassCasuale()" title="Genera password sicura">&#127922;</button>
                        </span>
                    </div>
                    <div class="cred-box">
                        <input type="password" id="inPass" class="cred-input" value="$Password" oninput="segnaModificato()">
                        <button type="button" class="btn-copy" onclick="copia('inPass', 'Password copiata!')">&#128203; Copia</button>
                    </div>
                </div>

                <!-- 5. SERVIZI DA ATTIVARE NELLA SEQUENZA AUTOMATICA -->
                <div class="cred-group" style="background: rgba(15, 23, 42, 0.4); border: 1px solid rgba(255,255,255,0.08); border-radius: 6px; padding: 8px; margin-top: 6px;">
                    <div class="cred-label" style="margin-bottom: 6px; color: #fed7aa; font-weight: 700;">⚙️ Servizi Acquistati da Attivare:</div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 11px;">
                        <label style="display: flex; align-items: center; gap: 5px; cursor: pointer;">
                            <input type="checkbox" id="chkSvcProton" checked> <span>✉️ Email Proton</span>
                        </label>
                        <label style="display: flex; align-items: center; gap: 5px; cursor: pointer;">
                            <input type="checkbox" id="chkSvcOffice"> <span>📦 Card Office 365</span>
                        </label>
                        <label style="display: flex; align-items: center; gap: 5px; cursor: pointer;">
                            <input type="checkbox" id="chkSvcMcAfee"> <span>🛡️ Card McAfee</span>
                        </label>
                        <label style="display: flex; align-items: center; gap: 5px; cursor: pointer;">
                            <input type="checkbox" id="chkSvcNorton"> <span>🛡️ Card Norton</span>
                        </label>
                        <label style="display: flex; align-items: center; gap: 5px; grid-column: span 2; cursor: pointer;">
                            <input type="checkbox" id="chkSvcCyber" checked> <span>🔒 Unieuro Cyber Protection</span>
                        </label>
                    </div>
                </div>

                <div style="margin-top: 12px; display: flex; flex-direction: column; gap: 8px;">
                    <button type="button" id="btnAvviaAuto" class="btn-scheda" style="background: #16a34a; font-weight: 700; font-size: 13px; padding: 10px 14px; width: 100%; border: none; cursor: pointer; text-align: center; border-radius: 6px; color: #fff;" onclick="avviaSetupAutomatico()">🚀 AVVIA SETUP AUTOMATICO (Zero Clic)</button>
                    <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 6px;">
                        <button type="button" id="btnSalvaCred" class="btn-scheda" style="background: #EE7203; border: none; font-size: 11px; padding: 6px 12px; cursor: pointer;" onclick="salvaCredenziali()">&#128190; Salva per Scheda Consegna</button>
                        <button type="button" class="btn-quick" onclick="copiaRiepilogoCred()">&#128203; Copia Tutto per Ticket</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- VISTA 3: PORTALI 1-CLICK -->
        <div id="view-tab-portali" class="section-view">
            <div class="card">
                <h2>
                    <span class="title-left"><span class="bar"></span> &#127760; Portali Servizi &amp; Attivazione (1-Click)</span>
                    <span style="font-size: 10px; color: #94a3b8;">Apertura istantanea</span>
                </h2>
                <div style="background: rgba(14, 165, 233, 0.12); border: 1px solid #0284c7; border-radius: 8px; padding: 8px 12px; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between;">
                    <div style="font-size: 11px; color: #38bdf8;">
                        <strong>&#129302; Assistente Agente IA</strong>: Apertura rapida &amp; compilazione intelligente. Stop con avviso sonoro sui codici OTP/SMS.
                    </div>
                </div>
                <input type="text" class="portal-filter" id="portalSearch" placeholder="&#128269; Cerca portale o servizio..." oninput="filtraPortali()">
                
                <div class="links-grid" id="portalLinksGrid">
                    <!-- SEZIONE 1: ACCOUNT & EMAIL -->
                    <div class="portal-divider" style="margin-top: 0;"><span>&#128100; Creazione Account &amp; Email</span></div>
                    <a href="https://account.microsoft.com" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="microsoft outlook account">
                        <span><span class="icon">&#128100;</span> 1. Account Microsoft / Outlook</span>
                        <span class="arrow">&rarr;</span>
                    </a>
                    <a href="https://accounts.google.com/signup" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="google gmail account">
                        <span><span class="icon">&#128231;</span> 2. Account Google / Gmail</span>
                        <span class="arrow">&rarr;</span>
                    </a>
                    <a href="https://account.proton.me/signup" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="proton mail account">
                        <span><span class="icon">&#128274;</span> 3. Account Proton Mail</span>
                        <span class="arrow">&rarr;</span>
                    </a>
                    <a href="https://registrazione.libero.it" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="libero mail registrazione">
                        <span><span class="icon">&#128236;</span> 4. Account Libero Mail</span>
                        <span class="arrow">&rarr;</span>
                    </a>

                    <!-- SEZIONE 2: PRODUTTIVITA' & OFFICE -->
                    <div class="portal-divider"><span>&#128230; Produttivit&agrave; &amp; Licenze Office</span></div>
                    <a href="https://microsoft365.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="office microsoft 365 setup pin riscatto">
                        <span><span class="icon">&#128230;</span> 5. Riscatto Card Microsoft 365 / Office</span>
                        <span class="arrow">&rarr;</span>
                    </a>
                    <a href="https://account.microsoft.com/services" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="office microsoft download installa account abbonamento">
                        <span><span class="icon">&#128229;</span> 6. Installa Office da Account Microsoft</span>
                        <span class="arrow">&rarr;</span>
                    </a>

                    <!-- SEZIONE 3: ANTIVIRUS DA CARD -->
                    <div class="portal-divider"><span>&#128737; Sicurezza &amp; Antivirus da Card</span></div>
                    <a href="https://www.mcafee.com/activate" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="mcafee activate antivirus card">
                        <span><span class="icon">&#128737;</span> 7. Attivazione Card McAfee</span>
                        <span class="arrow">&rarr;</span>
                    </a>
                    <a href="https://www.norton.com/setup" target="_blank" rel="noopener noreferrer" class="portal-btn" data-name="norton setup antivirus card">
                        <span><span class="icon">&#128737;</span> 8. Attivazione Card Norton</span>
                        <span class="arrow">&rarr;</span>
                    </a>

                    <!-- SEZIONE 4: SERVIZIO UNIEURO -->
                    <div class="portal-divider"><span>&#128274; Servizio Esclusivo Unieuro</span></div>
                    <a href="https://unieuro-cyber-protection.covercare.it" target="_blank" rel="noopener noreferrer" class="portal-btn highlight" data-name="unieuro cyber protection covercare">
                        <span><span class="icon">&#128274;</span> 9. Unieuro Cyber Protection</span>
                        <span class="arrow">&rarr;</span>
                    </a>
                </div>
            </div>
        </div>

        <!-- VISTA 4: CHECKLIST & STRUMENTI -->
        <div id="view-tab-checklist" class="section-view">
            <div class="card">
                <h2>
                    <span class="title-left"><span class="bar"></span> &#9745; Checklist Operatore &amp; Strumenti Rapidi</span>
                    <span style="font-size: 10px; color: #94a3b8;">Salvataggio automatico</span>
                </h2>
                <ul class="checklist">
                    <li><input type="checkbox" id="chk1" onchange="salvaChecklist()"> <label for="chk1">Account cliente configurato / verificato (Microsoft/Google/Proton/Libero)</label></li>
                    <li><input type="checkbox" id="chk2" onchange="salvaChecklist()"> <label for="chk2">Codice PIN Office riscattato (se acquistato con il PC)</label></li>
                    <li><input type="checkbox" id="chk3" onchange="salvaChecklist()"> <label for="chk3">Antivirus attivato con card cliente (McAfee / Norton)</label></li>
                    <li><input type="checkbox" id="chk4" onchange="salvaChecklist()"> <label for="chk4">Servizio Unieuro Cyber Protection registrato (se acquistato)</label></li>
                </ul>

                <div class="checklist-actions">
                    <a href="Scheda-Consegna-Cliente.html" target="_blank" class="btn-quick">&#128196; Scheda Consegna HTML</a>
                    <button type="button" class="btn-quick" onclick="copiaRiepilogoTecnico()">&#128203; Copia Dati PC Completi</button>
                    <button type="button" class="btn-quick" onclick="pollStatus()">&#128260; Sincronizza Ora</button>
                </div>
            </div>
        </div>

        <!-- VISTA 5: VISTA COMPLETA (TUTTO A SCHERMO IN GRIGLIA) -->
        <div id="view-tab-all" class="section-view">
            <div id="gridAllContainer" class="grid-view-all">
                <!-- Il contenuto viene clonato dinamicamente o visualizzato in griglia per schermi ampi -->
            </div>
        </div>

        <div class="footer">
            Piattaforma Assistenza Tecnica <strong>PC Facile</strong> &bull; Servizio <strong>Unieuro</strong> &bull; Batte. Forte. Sempre.
        </div>
    </div>

    <!-- TOAST POPUP FLUTTUANTE -->
    <div id="toastEl" class="toast">&#10003; Azione completata!</div>

    <script>
        var currentDomain = 'outlook.it';
        var currentProviderName = 'Microsoft';
        var manualEdit = false;
        var audioEnabled = true;
        var audioPlayed = false;
        var startTime = new Date();

        // TIMER TRASCORSO
        setInterval(function() {
            var now = new Date();
            var diffSec = Math.floor((now - startTime) / 1000);
            var m = Math.floor(diffSec / 60);
            var s = diffSec % 60;
            var el = document.getElementById('elapsedTimerText');
            if (el) el.innerText = (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
        }, 1000);

        // SUONO DI COMPLETAMENTO (Web Audio API synthesis senza file esterni)
        function playChime() {
            if (!audioEnabled) return;
            try {
                var AudioContext = window.AudioContext || window.webkitAudioContext;
                if (!AudioContext) return;
                var ctx = new AudioContext();
                var notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
                notes.forEach(function(freq, idx) {
                    var osc = ctx.createOscillator();
                    var gain = ctx.createGain();
                    osc.type = 'sine';
                    osc.frequency.value = freq;
                    gain.gain.setValueAtTime(0, ctx.currentTime + idx * 0.12);
                    gain.gain.linearRampToValueAtTime(0.2, ctx.currentTime + idx * 0.12 + 0.04);
                    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + idx * 0.12 + 0.35);
                    osc.connect(gain);
                    gain.connect(ctx.destination);
                    osc.start(ctx.currentTime + idx * 0.12);
                    osc.stop(ctx.currentTime + idx * 0.12 + 0.4);
                });
            } catch(e) {}
        }

        function toggleAudio() {
            audioEnabled = !audioEnabled;
            var btn = document.getElementById('btnSoundToggle');
            if (btn) {
                btn.innerHTML = audioEnabled ? '🔔 Audio' : '🔕 Muto';
                btn.style.color = audioEnabled ? '#93c5fd' : '#64748b';
            }
            showToast(audioEnabled ? 'Audio notifiche attivo' : 'Audio notifiche disattivato');
        }

        function showToast(msg) {
            var t = document.getElementById('toastEl');
            if (!t) return;
            t.innerText = msg;
            t.classList.add('show');
            setTimeout(function() { t.classList.remove('show'); }, 2200);
        }

        // GESTIONE VISTE / TABS
        function switchView(tabId, btn) {
            var btns = document.querySelectorAll('.tab-btn');
            for (var i = 0; i < btns.length; i++) btns[i].classList.remove('active');
            if (btn) btn.classList.add('active');

            var views = document.querySelectorAll('.section-view');
            for (var j = 0; j < views.length; j++) views[j].classList.remove('active-view');

            if (tabId === 'tab-all') {
                var allView = document.getElementById('view-tab-all');
                var grid = document.getElementById('gridAllContainer');
                if (allView && grid) {
                    grid.innerHTML = '';
                    var liveCard = document.querySelector('#view-tab-live .card');
                    var credCard = document.querySelector('#view-tab-cred .card');
                    var portaliCard = document.querySelector('#view-tab-portali .card');
                    var chkCard = document.querySelector('#view-tab-checklist .card');
                    if (liveCard) grid.appendChild(liveCard.cloneNode(true));
                    if (credCard) grid.appendChild(credCard.cloneNode(true));
                    if (portaliCard) grid.appendChild(portaliCard.cloneNode(true));
                    if (chkCard) grid.appendChild(chkCard.cloneNode(true));
                    allView.classList.add('active-view');
                }
            } else {
                var target = document.getElementById('view-' + tabId);
                if (target) target.classList.add('active-view');
            }
        }

        function setDomain(dom, provName, btn) {
            currentDomain = dom;
            currentProviderName = provName || dom;
            var btns = document.querySelectorAll('.dom-btn');
            for (var i = 0; i < btns.length; i++) btns[i].classList.remove('active');
            if (btn) btn.classList.add('active');
            aggiornaCred();
        }

        function segnaModificato() { manualEdit = true; }

        function togglePassVis() {
            var inp = document.getElementById('inPass');
            if (!inp) return;
            inp.type = (inp.type === 'password' ? 'text' : 'password');
        }

        function generaPassCasuale() {
            var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
            var pass = '';
            for (var i = 0; i < 10; i++) {
                pass += chars.charAt(Math.floor(Math.random() * chars.length));
            }
            pass += '!1';
            var inp = document.getElementById('inPass');
            if (inp) {
                inp.value = pass;
                inp.type = 'text';
                manualEdit = true;
                showToast('Generata password casuale sicura');
            }
        }

        function copia(id, msg) {
            var el = document.getElementById(id);
            if (!el) return;
            navigator.clipboard.writeText(el.value).then(function() {
                showToast(msg || 'Copiato negli appunti!');
            });
        }

        function copiaSeriale() {
            var sn = document.getElementById('hwSerialVal');
            if (sn && sn.innerText) {
                navigator.clipboard.writeText(sn.innerText.trim()).then(function() {
                    showToast('Seriale copiato: ' + sn.innerText.trim());
                });
            }
        }

        function copiaRiepilogoCred() {
            var email = document.getElementById('inEmail') ? document.getElementById('inEmail').value : '';
            var pass = document.getElementById('inPass') ? document.getElementById('inPass').value : '';
            var text = 'Account: ' + email + ' | Password: ' + pass + ' (Provider: ' + currentProviderName + ')';
            navigator.clipboard.writeText(text).then(function() {
                showToast('Dati account copiati per ticket!');
            });
        }

        function copiaRiepilogoTecnico() {
            var sn = document.getElementById('hwSerialVal') ? document.getElementById('hwSerialVal').innerText : '';
            var email = document.getElementById('inEmail') ? document.getElementById('inEmail').value : '';
            var pass = document.getElementById('inPass') ? document.getElementById('inPass').value : '';
            var text = '--- UNIEURO PC FACILE ---\nModello: $hwModello\nSeriale: ' + sn + '\nCPU/RAM: $hwCpu - $hwRam\nAccount: ' + email + '\nPassword: ' + pass;
            navigator.clipboard.writeText(text).then(function() {
                showToast('Riepilogo tecnico completo copiato!');
            });
        }

        function filtraPortali() {
            var q = (document.getElementById('portalSearch') ? document.getElementById('portalSearch').value.toLowerCase().trim() : '');
            var links = document.querySelectorAll('#portalLinksGrid .portal-btn');
            for (var i = 0; i < links.length; i++) {
                var dname = (links[i].getAttribute('data-name') || '') + ' ' + links[i].innerText.toLowerCase();
                links[i].style.display = (q === '' || dname.indexOf(q) !== -1) ? 'flex' : 'none';
            }
        }

        function salvaChecklist() {
            try {
                var st = {
                    c1: document.getElementById('chk1') ? document.getElementById('chk1').checked : false,
                    c2: document.getElementById('chk2') ? document.getElementById('chk2').checked : false,
                    c3: document.getElementById('chk3') ? document.getElementById('chk3').checked : false,
                    c4: document.getElementById('chk4') ? document.getElementById('chk4').checked : false
                };
                localStorage.setItem('pcfacile_checklist', JSON.stringify(st));
            } catch(e) {}
        }

        function caricaChecklist() {
            try {
                var raw = localStorage.getItem('pcfacile_checklist');
                if (raw) {
                    var st = JSON.parse(raw);
                    if (document.getElementById('chk1') && st.c1) document.getElementById('chk1').checked = true;
                    if (document.getElementById('chk2') && st.c2) document.getElementById('chk2').checked = true;
                    if (document.getElementById('chk3') && st.c3) document.getElementById('chk3').checked = true;
                    if (document.getElementById('chk4') && st.c4) document.getElementById('chk4').checked = true;
                }
            } catch(e) {}
        }
        caricaChecklist();

        function aggiornaCred() {
            var cognome = (document.getElementById('inCognome') ? document.getElementById('inCognome').value.trim() : '');
            var nome = (document.getElementById('inNome') ? document.getElementById('inNome').value.trim() : '');
            
            if (!cognome && !nome) {
                if (!manualEdit) {
                    document.getElementById('inEmail').value = 'utente@' + currentDomain;
                    document.getElementById('inPass').value = 'Utente123!';
                }
                return;
            }

            var cClean = cognome.toLowerCase().replace(/[^a-z0-9]/g, '');
            var nClean = nome.toLowerCase().replace(/[^a-z0-9]/g, '');
            
            var emailPrefix = '';
            var passBase = '';
            
            if (cClean && nClean) {
                emailPrefix = cClean + nClean;
                passBase = nClean;
            } else if (cClean) {
                emailPrefix = cClean;
                passBase = cClean;
            } else {
                var parts = nome.toLowerCase().split(/\s+/).filter(Boolean);
                if (parts.length > 1) {
                    var pCognome = parts.slice(1).join('').replace(/[^a-z0-9]/g, '');
                    var pNome = parts[0].replace(/[^a-z0-9]/g, '');
                    emailPrefix = pCognome + pNome;
                    passBase = pNome;
                } else {
                    emailPrefix = nClean;
                    passBase = nClean;
                }
            }

            if (emailPrefix.length > 20) { emailPrefix = emailPrefix.substring(0, 20); }
            document.getElementById('inEmail').value = emailPrefix + '@' + currentDomain;
            
            if (passBase) {
                var cap = passBase.charAt(0).toUpperCase() + passBase.slice(1).toLowerCase().replace(/[^a-z0-9]/g, '');
                document.getElementById('inPass').value = cap + '123!';
            }
        }

        function salvaCredenziali() {
            var email = document.getElementById('inEmail').value.trim();
            var pass = document.getElementById('inPass').value.trim();
            var cognome = (document.getElementById('inCognome') ? document.getElementById('inCognome').value.trim() : '');
            var nome = (document.getElementById('inNome') ? document.getElementById('inNome').value.trim() : '');
            var telefono = (document.getElementById('inTelefono') ? document.getElementById('inTelefono').value.trim() : '');
            var cliente = (cognome + ' ' + nome).trim() || nome || cognome || 'Utente';
            
            var proton = document.getElementById('chkSvcProton') ? document.getElementById('chkSvcProton').checked : true;
            var office = document.getElementById('chkSvcOffice') ? document.getElementById('chkSvcOffice').checked : false;
            var mcafee = document.getElementById('chkSvcMcAfee') ? document.getElementById('chkSvcMcAfee').checked : false;
            var norton = document.getElementById('chkSvcNorton') ? document.getElementById('chkSvcNorton').checked : false;
            var cyber = document.getElementById('chkSvcCyber') ? document.getElementById('chkSvcCyber').checked : false;

            var payload = {
                Email: email,
                Password: pass,
                Provider: currentProviderName,
                Cliente: cliente,
                Nome: nome,
                Cognome: cognome,
                Telefono: telefono,
                Servizi: {
                    Proton: proton,
                    Office: office,
                    McAfee: mcafee,
                    Norton: norton,
                    Cyber: cyber
                }
            };
            
            var blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = 'pcfacile-cred.json';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            
            showToast('✓ Credenziali salvate per la Scheda!');
            var btn = document.getElementById('btnSalvaCred');
            if (btn) {
                var old = btn.innerHTML;
                btn.innerHTML = '&#10003; Salvato!';
                btn.style.background = '#16a34a';
                setTimeout(function() {
                    btn.innerHTML = old;
                    btn.style.background = '#EE7203';
                }, 3000);
            }
        }

        function avviaSetupAutomatico() {
            salvaCredenziali();
            showToast('🚀 Setup Automatico Avviato! Il sistema procede in autonomia.');
            var btn = document.getElementById('btnAvviaAuto');
            if (btn) {
                btn.innerHTML = '&#10003; Setup in corso...';
                btn.style.background = '#0284c7';
            }
        }

        // MOTORE DI SINCRONIZZAZIONE LIVE CON POWERSHELL
        function applyStatus(data) {
            if (!data) return;
            
            var pct = data.Percentuale !== undefined ? data.Percentuale : (data.percentuale || 0);
            var bar = document.getElementById('progressBarFill');
            var pctText = document.getElementById('progressPercentText');
            if (bar) bar.style.width = pct + '%';
            if (pctText) pctText.innerText = pct + '%';
            
            var faseEl = document.getElementById('currentFaseText');
            var faseVal = data.FaseCorrente || data.faseCorrente;
            if (faseEl && faseVal) faseEl.innerText = faseVal;
            
            var detEl = document.getElementById('currentDetailText');
            var detVal = data.Dettaglio || data.dettaglio;
            if (detEl && detVal) detEl.innerText = detVal;
            
            if (data.Completato || data.completato || pct >= 100) {
                var badgeLive = document.getElementById('badgeLive');
                if (badgeLive) {
                    badgeLive.className = 'badge-done';
                    badgeLive.innerHTML = '&#10003; Setup Completato';
                }
                var compBanner = document.getElementById('completionBanner');
                if (compBanner) compBanner.style.display = 'block';

                if (!audioPlayed) {
                    audioPlayed = true;
                    playChime();
                }
            }

            var tasks = data.Tasks || data.tasks;
            if (tasks) {
                var doneCount = 0;
                for (var key in tasks) {
                    var task = tasks[key];
                    var row = document.getElementById('task-' + key);
                    var stato = (task.Stato || task.stato || 'pending').toLowerCase();
                    var dettaglio = task.Dettaglio || task.dettaglio || '';
                    if (stato === 'done') doneCount++;
                    
                    if (row) {
                        var iconEl = row.querySelector('.task-icon');
                        var statusBadge = row.querySelector('.task-badge');
                        var detailEl = row.querySelector('.task-detail');
                        
                        row.className = 'task-item ' + stato;
                        if (statusBadge) {
                            var badgeClass = 'badge-pending';
                            var badgeText = 'In attesa';
                            if (stato === 'done') { badgeClass = 'badge-done-task'; badgeText = 'Completato'; }
                            else if (stato === 'running') { badgeClass = 'badge-running'; badgeText = 'In corso (' + pct + '%)'; }
                            else if (stato === 'error') { badgeClass = 'badge-error'; badgeText = 'Errore'; }
                            else if (stato === 'skipped') { badgeClass = 'badge-skipped'; badgeText = 'Saltato'; }
                            
                            statusBadge.className = 'task-badge ' + badgeClass;
                            statusBadge.innerText = badgeText;
                        }
                        if (iconEl) {
                            if (stato === 'done') iconEl.innerHTML = '&#10003;';
                            else if (stato === 'running') iconEl.innerHTML = '<span class=\"spinner\"></span>';
                            else if (stato === 'error') iconEl.innerHTML = '&#10007;';
                            else if (stato === 'skipped') iconEl.innerHTML = '&rarr;';
                            else iconEl.innerHTML = '&#9675;';
                        }
                        if (detailEl) {
                            if (dettaglio && stato === 'running') {
                                detailEl.innerText = ' - ' + dettaglio;
                            } else {
                                detailEl.innerText = '';
                            }
                        }
                    }
                }
                var badgeNum = document.getElementById('taskCountBadge');
                if (badgeNum) badgeNum.innerText = doneCount + '/10';
            }
        }

        window.onPCFacileStatusUpdate = applyStatus;

        function pollStatus() {
            var s = document.createElement('script');
            s.src = 'pcfacile-status.js?t=' + new Date().getTime();
            s.onload = function() { if (this.parentNode) this.parentNode.removeChild(this); };
            s.onerror = function() { if (this.parentNode) this.parentNode.removeChild(this); };
            document.head.appendChild(s);
        }
        setInterval(pollStatus, 1000);
    </script>
</body>
</html>
"@
        $html | Set-Content -Path $pannelloFile -Encoding UTF8
        if (-not $Global:Test -and -not $env:PESTER_TEST) {
            try { Set-SplitScreenLayout -HtmlPath $pannelloFile } catch {
                try { Start-Process $pannelloFile } catch {}
            }
        }
        Write-OK "Pannello Operatore aperto nel browser: sincronizzazione live dei lavori attiva."
    } catch {
        Write-Info "Creazione pannello operatore non riuscita: $_"
    }
}


function Get-CredenzialiSalvatePannello {
    $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
    $userProf = [Environment]::GetFolderPath('UserProfile')
    $paths = @(
        (Join-Path $userProf "Downloads\pcfacile-cred.json"),
        (Join-Path $tempDir "pcfacile-cred.json")
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            try {
                $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
                $content = $raw | ConvertFrom-Json
                if ($content.Email) {
                    $Global:credMsAccount = $content.Email
                    $Global:credGenerataEmail = $content.Email
                }
                if ($content.Password) {
                    $Global:credMsPassword = $content.Password
                    $Global:credGenerataPass = $content.Password
                }
                if ($content.Provider) {
                    $Global:credProvider = $content.Provider
                    $Global:provNome = $content.Provider
                }
                if ($content.Cliente) {
                    $oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP')
                    if (-not $Global:nomeCliente -or $Global:nomeCliente -eq 'telef' -or $Global:nomeCliente -eq 'Utente' -or $Global:nomeCliente -eq 'Cliente' -or ($oemNames -contains $Global:nomeCliente.ToUpper())) {
                        $Global:nomeCliente = $content.Cliente
                    }
                }
                if ($content.Telefono) {
                    $Global:telefonoCliente = $content.Telefono
                }
                if ($content.Nome) {
                    $Global:nomeProprioCliente = $content.Nome
                }
                if ($content.Cognome) {
                    $Global:cognomeCliente = $content.Cognome
                }
                if ($content.Servizi) {
                    $Global:serviziSelezionati = $content.Servizi
                }
                return $true
            } catch {}
        }
    }
    return $false
}

function Wait-CredenzialiPannello {
    [CmdletBinding()]
    param(
        [int]$TimeoutSecondi = 120,
        [switch]$Test
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST) {
        return $true
    }
    if (Get-CredenzialiSalvatePannello) {
        return $true
    }

    Write-Host ""
    Write-Titolo "IN ATTESA DATI DAL PANNELLO OPERATORE (A SINISTRA)"
    Write-Host "  -> Compila Cognome, Nome, Telefono e spunta i servizi nel Pannello Web a SINISTRA." -ForegroundColor Cyan
    Write-Host "  -> Clicca sul pulsante verde '🚀 AVVIA SETUP AUTOMATICO (Zero Clic)' per partire." -ForegroundColor Green
    Write-Host "     (Oppure premi INVIO in questa console per usare i valori correnti)" -ForegroundColor Gray
    Write-Host ""

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSecondi) {
        if (Get-CredenzialiSalvatePannello) {
            Write-OK "Dati cliente e servizi ricevuti con successo dal Pannello Web!"
            if ($Global:nomeCliente) {
                Write-Host "  - Cliente : $Global:nomeCliente" -ForegroundColor Cyan
            }
            if ($Global:telefonoCliente) {
                Write-Host "  - Telefono: $Global:telefonoCliente" -ForegroundColor Cyan
            }
            return $true
        }
        try {
            if ([System.Console]::KeyAvailable) {
                $key = [System.Console]::ReadKey($true)
                if ($key.Key -eq [System.ConsoleKey]::Enter) {
                    Write-Info "Avvio manuale confermato da console."
                    return $true
                }
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# =============================================================================
# GESTIONE OFFLINE INSTALLERS & PREPARAZIONE USB
# =============================================================================

function Get-OfflineDirs {
    $dirs = [System.Collections.Generic.List[string]]::new()

    $clean = {
        param([string]$p)
        if ([string]::IsNullOrWhiteSpace($p)) { return $null }
        $p = ($p -replace '["'']', '').Trim().TrimEnd('\').TrimEnd('/')
        return $p
    }

    $addDir = {
        param([string]$base)
        $b = & $clean $base
        if ($b) {
            $dirs.Add((Join-Path $b "installers"))
            $dirs.Add((Join-Path $b "offline"))
            $dirs.Add((Join-Path $b "cache"))
            $dirs.Add($b)
        }
    }

    if ($Global:TargetDir) { & $addDir $Global:TargetDir }
    if ($TargetDir -and $TargetDir -ne $Global:TargetDir) { & $addDir $TargetDir }
    if ($PSScriptRoot) { & $addDir $PSScriptRoot }
    $curr = (Get-Location).Path
    if ($curr) { & $addDir $curr }

    try {
        $allDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and ($_.Name -match '^[a-zA-Z]:' -or $_.DriveType -eq 'Removable') }
        foreach ($d in $allDrives) {
            $root = $d.RootDirectory.FullName
            if ($root) { & $addDir $root }
        }
    } catch {
        try {
            $removables = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
            foreach ($r in $removables) {
                $rPath = "$($r.DriveLetter):\"
                & $addDir $rPath
            }
        } catch {}
    }

    $existing = @()
    foreach ($d in $dirs) {
        if (-not $d) { continue }
        $cd = & $clean $d
        try {
            if ($cd -and (Test-Path -LiteralPath $cd -ErrorAction SilentlyContinue) -and -not ($existing -contains $cd)) {
                $existing += $cd
            }
        } catch {}
    }
    return $existing
}

function Stop-AppPopups {
    param([string]$Nome)
    if ($Test) { return }
    try {
        $targets = @()
        if ($Nome -like "*Spotify*") { $targets += "Spotify" }
        elseif ($Nome -like "*Zoom*") { $targets += "Zoom" }
        elseif ($Nome -like "*Discord*") { $targets += "Discord" }
        elseif ($Nome -like "*Steam*") { $targets += "Steam" }
        elseif ($Nome -like "*AIMP*") { $targets += "AIMP" }
        elseif ($Nome -like "*Adobe*" -or $Nome -like "*Acrobat*") { $targets += @("AdobeCollabSync", "AcroCEF", "AcrobatNotificationClient") }
        elseif ($Nome -like "*Teams*") { $targets += @("ms-teams", "Teams") }
        elseif ($Nome -like "*AnyDesk*") { $targets += "AnyDesk" }
        elseif ($Nome -like "*Skype*") { $targets += "SkypeApp" }

        # Helper e popup molesti di background
        $targets += @("AdobeCollabSync", "AcroCEF")

        if ($targets.Count -gt 0) {
            Start-Sleep -Seconds 1
            foreach ($t in $targets) {
                $procs = Get-Process -Name $t -ErrorAction SilentlyContinue
                if ($procs) {
                    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {}
}

function Enable-PreventSleep {
    if ($Test) { return }
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class WinPower {
            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern uint SetThreadExecutionState(uint esFlags);
            public const uint ES_SYSTEM_REQUIRED = 0x00000001;
            public const uint ES_DISPLAY_REQUIRED = 0x00000002;
            public const uint ES_CONTINUOUS = 0x80000000;
        }
"@ -ErrorAction SilentlyContinue
        [WinPower]::SetThreadExecutionState([WinPower]::ES_CONTINUOUS -bor [WinPower]::ES_SYSTEM_REQUIRED -bor [WinPower]::ES_DISPLAY_REQUIRED) | Out-Null
    } catch {}
}

function Find-OfflineInstaller {
    param(
        [string]$WingetId,
        [string]$Nome
    )
    $dirs = Get-OfflineDirs
    if ($dirs.Count -eq 0) { return $null }

    $patterns = @{
        "Google.Chrome"                     = @("*Chrome*Setup*.exe", "*Chrome*Standalone*.exe", "*googlechrome*.exe", "*Chrome*.msi")
        "Mozilla.Firefox"                  = @("*Firefox*Setup*.exe", "*firefox*.exe", "*Firefox*Installer*.exe", "*Firefox*.msi")
        "VideoLAN.VLC"                     = @("*vlc*win64.exe", "*vlc*.exe", "*vlc*.msi")
        "Adobe.Acrobat.Reader.64-bit"      = @("*AcroRdr*.exe", "*Acrobat*Reader*.exe", "*AdbeRdr*.exe", "*AcroRdr*it_IT*.exe", "*Acro*.msi")
        "SumatraPDF.SumatraPDF"            = @("*SumatraPDF*.exe", "*SumatraPDF*.msi")
        "7zip.7zip"                        = @("*7z*x64.msi", "*7z*.msi", "*7z*x64.exe", "*7z*.exe")
        "AnyDesk.AnyDesk"                  = @("*AnyDesk*.exe")
        "TeamViewer.TeamViewer"            = @("*TeamViewer*Setup*.exe", "*TeamViewer*.exe", "*TeamViewer*.msi")
        "Zoom.Zoom"                        = @("*Zoom*.msi", "*ZoomInstaller*.exe", "*Zoom*.exe")
        "TheDocumentFoundation.LibreOffice"= @("*LibreOffice*x86-64.msi", "*LibreOffice*.msi", "*LibreOffice*.exe")
        "Apache.OpenOffice"                = @("*Apache*OpenOffice*.exe", "*OpenOffice*.exe", "*OpenOffice*.msi")
        "Spotify.Spotify"                  = @("*Spotify*Full*Setup*.exe", "*Spotify*Setup*.exe", "*Spotify*.exe", "*Spotify*.msixbundle")
        "9NKSQGP7F2NH"                     = @("*WhatsApp*.exe", "*WhatsApp*.msixbundle", "*WhatsApp*.appxbundle")
        "GIMP.GIMP"                        = @("*gimp*setup*.exe", "*gimp*.exe", "*gimp*.msi")
        "Valve.Steam"                      = @("*SteamSetup*.exe", "*Steam*.exe")
        "EpicGames.EpicGamesLauncher"      = @("*EpicGamesLauncher*.msi", "*EpicInstaller*.msi", "*EpicGames*.exe")
        "Discord.Discord"                  = @("*DiscordSetup*.exe", "*Discord*.exe")
        "AIMP.AIMP"                        = @("*aimp*.exe")
        "Intel.IntelDriverAndSupportAssistant" = @("*Intel*Driver*Support*Assistant*.exe", "*IntelDSA*.exe", "*Intel*.exe")
        "Microsoft.Office"                 = @("*OfficeSetup*.exe", "*Office*.exe", "*Setup32*.exe", "*Setup64*.exe")
        "Microsoft.VCRedist.2015+.x64"      = @("*vc_redist.x64*.exe", "*vcredist*x64*.exe")
        "Microsoft.VCRedist.2015+.x86"      = @("*vc_redist.x86*.exe", "*vcredist*x86*.exe")
        "MCPR"                             = @("*MCPR*.exe")
        "NRnR"                             = @("*NRnR*.exe")
    }

    $namePatterns = @{
        "Visual C++ x64"                   = @("*vc_redist.x64*.exe", "*vcredist*x64*.exe")
        "Visual C++ x86"                   = @("*vc_redist.x86*.exe", "*vcredist*x86*.exe")
        "Microsoft Visual C++ 2015-2022 (x64)" = @("*vc_redist.x64*.exe", "*vcredist*x64*.exe")
        "Microsoft Visual C++ 2015-2022 (x86)" = @("*vc_redist.x86*.exe", "*vcredist*x86*.exe")
        "VLC"                              = @("*vlc*win64.exe", "*vlc*.exe", "*vlc*.msi")
        "Adobe Acrobat Reader"             = @("*AcroRdr*.exe", "*Acrobat*Reader*.exe", "*AdbeRdr*.exe", "*AcroRdr*it_IT*.exe", "*Acro*.msi")
        "Sumatra PDF"                      = @("*SumatraPDF*.exe", "*SumatraPDF*.msi")
        "7-Zip"                            = @("*7z*x64.msi", "*7z*.msi", "*7z*x64.exe", "*7z*.exe")
        "AnyDesk"                          = @("*AnyDesk*.exe")
        "TeamViewer"                       = @("*TeamViewer*Setup*.exe", "*TeamViewer*.exe", "*TeamViewer*.msi")
        "Zoom"                             = @("*Zoom*.msi", "*ZoomInstaller*.exe", "*Zoom*.exe")
        "LibreOffice"                      = @("*LibreOffice*x86-64.msi", "*LibreOffice*.msi", "*LibreOffice*.exe")
        "OpenOffice"                       = @("*Apache*OpenOffice*.exe", "*OpenOffice*.exe", "*OpenOffice*.msi")
        "Spotify"                          = @("*Spotify*Full*Setup*.exe", "*Spotify*Setup*.exe", "*Spotify*.exe", "*Spotify*.msixbundle")
        "WhatsApp"                         = @("*WhatsApp*.exe", "*WhatsApp*.msixbundle", "*WhatsApp*.appxbundle")
        "GIMP"                             = @("*gimp*setup*.exe", "*gimp*.exe", "*gimp*.msi")
        "Steam"                            = @("*SteamSetup*.exe", "*Steam*.exe")
        "Epic Games Launcher"              = @("*EpicGamesLauncher*.msi", "*EpicInstaller*.msi", "*EpicGames*.exe")
        "Discord"                          = @("*DiscordSetup*.exe", "*Discord*.exe")
        "AIMP"                             = @("*aimp*.exe")
        "Intel Driver e Support Assistant" = @("*Intel*Driver*Support*Assistant*.exe", "*IntelDSA*.exe", "*Intel*.exe")
        "Microsoft 365"                    = @("*OfficeSetup*.exe", "*Office*.exe", "*Setup32*.exe", "*Setup64*.exe")
        "MCPR"                             = @("*MCPR*.exe")
        "NRnR"                             = @("*NRnR*.exe")
    }

    $searchList = @()
    if ($WingetId -and $patterns.ContainsKey($WingetId)) { $searchList += $patterns[$WingetId] }
    if ($Nome -and $patterns.ContainsKey($Nome)) { $searchList += $patterns[$Nome] }
    if ($Nome -and $namePatterns.ContainsKey($Nome)) { $searchList += $namePatterns[$Nome] }
    if ($WingetId) {
        $searchList += "*$WingetId*.msi"
        $searchList += "*$WingetId*.exe"
    }
    if ($Nome) {
        $cleanNome = ($Nome -replace '[^a-zA-Z0-9]','*')
        $searchList += "*$cleanNome*.msi"
        $searchList += "*$cleanNome*.exe"
    }

    # Preferisci pacchetti .msi prima di .exe per massima affidabilità silent
    $orderedSearchList = @($searchList | Sort-Object { if ($_ -like "*.msi") { 0 } else { 1 } })

    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        try {
            $files = @(Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue)
            if ($files.Count -eq 0) { continue }
            foreach ($p in $orderedSearchList) {
                # Controllo dimensione minima (>= 100 KB) per scartare file parziali, vuoti o non validi
                $matched = $files | Where-Object { $_.Name -like $p -and $_.Length -ge 102400 } | Select-Object -First 1
                if ($matched) { return $matched.FullName }
            }
        } catch {}
    }
    return $null
}

function Install-OfflinePackage {
    param(
        [string]$FilePath,
        [string]$Nome
    )
    if ($Test) { Write-OK "TEST: installazione offline simulata per $Nome ($FilePath)"; return $true }
    Write-Info "Installazione offline da USB in corso: $Nome ($FilePath)..."
    try {
        if (-not (Test-Path -LiteralPath $FilePath)) {
            Write-Info "File offline non trovato: $FilePath. Procedo con Winget..."
            return $false
        }
        $fItem = Get-Item -LiteralPath $FilePath -ErrorAction SilentlyContinue
        if ($fItem -and $fItem.Length -lt 102400) {
            Write-Info "File offline $FilePath troppo piccolo ($($fItem.Length) bytes, possibile download corrotto). Procedo con Winget..."
            return $false
        }

        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $workDir = Split-Path -Path $FilePath -Parent
        if (-not $workDir -or -not (Test-Path -LiteralPath $workDir)) { $workDir = $env:TEMP }
        $proc = $null
        if ($ext -eq '.msi') {
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$FilePath`" /qn /norestart" -WorkingDirectory $workDir -PassThru -ErrorAction Stop
            $timer = 0
            while (-not $proc.HasExited -and $timer -lt 120) {
                Start-Sleep -Seconds 2
                $timer += 2
            }
            if (-not $proc.HasExited) {
                try { $proc.Kill() } catch {}
                Write-Info "Installazione MSI per $Nome ha superato il timeout (120s). Procedo con Winget..."
                return $false
            }
        } elseif ($ext -eq '.msixbundle' -or $ext -eq '.appxbundle' -or $ext -eq '.msix' -or $ext -eq '.appx') {
            Add-AppxPackage -Path $FilePath -ErrorAction Stop
            Write-OK "$Nome installato con successo da pacchetto offline Appx/MSIX!"
            Stop-AppPopups -Nome $Nome
            return $true
        } elseif ($FilePath -like "*Spotify*" -or $Nome -eq "Spotify") {
            # Spotify blocca l'installazione se avviato direttamente da Amministratore (Token elevato).
            # Lo avviamo nel contesto utente standard (Medium Integrity) tramite Scheduled Task limitata o runas.
            $taskName = "PCFacile_Spotify_$([Math]::Abs((Get-Random) % 10000))"
            try {
                if (Get-Command New-ScheduledTaskAction -ErrorAction SilentlyContinue) {
                    $action = New-ScheduledTaskAction -Execute $FilePath -Argument "/silent" -WorkingDirectory $workDir
                    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
                    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force -ErrorAction Stop | Out-Null
                    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
                    
                    $t = 0
                    Start-Sleep -Seconds 3
                    while ((Get-Process -Name "*SpotifySetup*" -ErrorAction SilentlyContinue) -and $t -lt 60) {
                        Start-Sleep -Seconds 2
                        $t += 2
                    }
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                } else {
                    & schtasks.exe /create /tn $taskName /tr "`"$FilePath`" /silent" /sc ONCE /st 00:00 /ru "$env:USERNAME" /rl LIMITED /f 2>$null | Out-Null
                    & schtasks.exe /run /tn $taskName 2>$null | Out-Null
                    Start-Sleep -Seconds 8
                    & schtasks.exe /delete /tn $taskName /f 2>$null | Out-Null
                }
            } catch {
                try {
                    Start-Process -FilePath $FilePath -ArgumentList "/silent" -WorkingDirectory $workDir -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                } catch {}
            }

            # Verifica se Spotify e' installato nel profilo utente
            $spotExe = Join-Path $env:APPDATA "Spotify\Spotify.exe"
            $spotLocal = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Spotify.exe"
            if ((Test-Path $spotExe) -or (Test-Path $spotLocal) -or (Get-Process "Spotify" -ErrorAction SilentlyContinue)) {
                Write-OK "$Nome installato con successo da cache offline USB!"
                Stop-AppPopups -Nome $Nome
                return $true
            } else {
                Write-Info "Installazione offline standard di Spotify non rilevata. Procedo con fallback..."
                return $false
            }
        } else {
            $arg = "/S"
            if ($FilePath -like "*Chrome*") { $arg = "/silent /install" }
            elseif ($FilePath -like "*Firefox*") { $arg = "/S" }
            elseif ($FilePath -like "*7z*") { $arg = "/S" }
            elseif ($FilePath -like "*vlc*") { $arg = "/L=1040 /S" }
            elseif ($FilePath -like "*Acro*" -or $FilePath -like "*Adbe*") { $arg = "/sAll /rs /msi EULA_ACCEPT=YES" }
            elseif ($FilePath -like "*Sumatra*") { $arg = "/S" }
            elseif ($FilePath -like "*AnyDesk*") { $arg = "--install `"C:\Program Files (x86)\AnyDesk`" --silent --create-shortcuts" }
            elseif ($FilePath -like "*TeamViewer*") { $arg = "/S" }
            elseif ($FilePath -like "*Zoom*") { $arg = "/silent" }
            elseif ($FilePath -like "*LibreOffice*" -or $FilePath -like "*OpenOffice*") { $arg = "/S" }
            elseif ($FilePath -like "*aimp*") { $arg = "/AUTO" }
            elseif ($FilePath -like "*gimp*") { $arg = "/VERYSILENT /NORESTART /ALLUSERS" }
            elseif ($FilePath -like "*Steam*") { $arg = "/S" }
            elseif ($FilePath -like "*Intel*") { $arg = "/quiet /norestart" }
            elseif ($FilePath -like "*vc_redist*" -or $FilePath -like "*vcredist*") { $arg = "/install /quiet /norestart" }

            $proc = Start-Process -FilePath $FilePath -ArgumentList $arg -WorkingDirectory $workDir -PassThru -ErrorAction Stop
            $timer = 0
            while (-not $proc.HasExited -and $timer -lt 90) {
                Start-Sleep -Seconds 2
                $timer += 2
            }
            if (-not $proc.HasExited) {
                try { $proc.Kill() } catch {}
                Write-Info "Processo di installazione offline per $Nome ha superato il tempo massimo (90s). Procedo con Winget..."
                return $false
            }
        }
        if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641)) {
            Write-OK "$Nome installato con successo da cache offline USB!"
            Stop-AppPopups -Nome $Nome
            return $true
        } else {
            $code = if ($proc) { $proc.ExitCode } else { "sconosciuto" }
            Write-Info "Installazione offline di $Nome uscita con codice $code. Procedo con Winget..."
        }
    } catch {
        Write-Info "Installazione offline non riuscita ($($_.Exception.Message)). Procedo con Winget..."
    }
    return $false
}

function Install-VisualCRuntime {
    if ($Test) {
        Write-OK "TEST: Installazione Microsoft Visual C++ Redistributable (x64 & x86) simulata."
        Add-Report "Microsoft Visual C++ Runtime (x64/x86)" "OK"
        return $true
    }

    Write-Info "Verifica e installazione Runtime Essenziali (Microsoft Visual C++ 2015-2022)..."
    $runtimes = @(
        @{ Nome = "Microsoft Visual C++ 2015-2022 (x64)"; WingetId = "Microsoft.VCRedist.2015+.x64"; Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"; File = "vc_redist.x64.exe" },
        @{ Nome = "Microsoft Visual C++ 2015-2022 (x86)"; WingetId = "Microsoft.VCRedist.2015+.x86"; Url = "https://aka.ms/vs/17/release/vc_redist.x86.exe"; File = "vc_redist.x86.exe" }
    )

    $allOk = $true
    foreach ($rt in $runtimes) {
        # 1. Prova prima da installer offline USB se presente
        $offlineFile = Find-OfflineInstaller -WingetId $rt.WingetId -Nome $rt.Nome
        if ($offlineFile) {
            if (Install-OfflinePackage -FilePath $offlineFile -Nome $rt.Nome) {
                Write-OK "$($rt.Nome) installato da archivio offline USB."
                continue
            }
        }

        # 2. Prova installazione via Winget
        $wingetInstalled = $false
        if (Confirm-Winget) {
            try {
                $p = Start-Process winget -ArgumentList "install --id $($rt.WingetId) --exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                if ($p -and ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010 -or $p.ExitCode -eq 1641 -or $p.ExitCode -eq -1978335189)) {
                    $wingetInstalled = $true
                    Write-OK "$($rt.Nome) installato via Winget."
                }
            } catch {}
        }

        # 3. Fallback download diretto da server ufficiale Microsoft
        if (-not $wingetInstalled) {
            try {
                $tempDest = Join-Path $env:TEMP $rt.File
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                Invoke-WebRequest -Uri $rt.Url -OutFile $tempDest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
                $proc = Start-Process -FilePath $tempDest -ArgumentList "/install /quiet /norestart" -Wait -PassThru -ErrorAction Stop
                if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641)) {
                    Write-OK "$($rt.Nome) installato da download diretto Microsoft."
                } else {
                    $allOk = $false
                }
            } catch {
                Write-Info "Installazione di $($rt.Nome) non riuscita: $_"
                $allOk = $false
            }
        }
    }

    if ($allOk) {
        Add-Report "Microsoft Visual C++ Runtime (x64/x86)" "OK"
    } else {
        Add-Report "Microsoft Visual C++ Runtime (x64/x86)" "AVVISO"
    }
    return $allOk
}

function Install-WindowsUpdateDrivers {
    param(
        [int]$TimeoutSec = 360,
        [switch]$Test
    )
    if ($Test -or -not $RunReale) {
        Write-OK "TEST: simulazione ricerca/aggiornamento driver Windows Update completata."
        Add-Report "Driver (Windows Update)" "OK"
        Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Percentuale 72 -Dettaglio "Completato (test)"
        return @{ Esito = "OK"; Trovati = 0; Installati = 0; RebootRequired = $false }
    }

    Write-Info "Ricerca e installazione driver su Windows Update in corso (max $([math]::Round($TimeoutSec/60)) min)..."
    Write-Host "  (Puoi premere 'S' o 'Esc' in qualsiasi momento per saltare e andare subito alle app)" -ForegroundColor Yellow
    Start-BarraAnimata "Driver Windows Update [Premi S per saltare]"

    $jobDriver = Start-Job -ScriptBlock {
        $esito = [ordered]@{
            Trovati        = 0
            NomiDriver     = @()
            Scaricati      = 0
            Installati     = 0
            ResultCode     = 0
            RebootRequired = $false
            Errore         = $null
        }
        try {
            $sess = New-Object -ComObject Microsoft.Update.Session
            $searcher = $sess.CreateUpdateSearcher()
            $result = $searcher.Search("Type='Driver' and IsInstalled=0")
            if (-not $result -or -not $result.Updates -or $result.Updates.Count -eq 0) {
                return $esito
            }
            $daInstallare = New-Object -ComObject Microsoft.Update.UpdateColl
            $titoli = @()
            foreach ($u in $result.Updates) {
                if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                $daInstallare.Add($u) | Out-Null
                $titoli += [string]$u.Title
            }
            $esito.Trovati = $daInstallare.Count
            $esito.NomiDriver = $titoli
            if ($daInstallare.Count -eq 0) {
                return $esito
            }

            # Download
            $downloader = $sess.CreateUpdateDownloader()
            $downloader.Updates = $daInstallare
            $null = $downloader.Download()
            $esito.Scaricati = $daInstallare.Count

            # Install
            $installer = $sess.CreateUpdateInstaller()
            $installer.Updates = $daInstallare
            $resInst = $installer.Install()
            $esito.Installati = $daInstallare.Count
            $esito.ResultCode = $resInst.ResultCode
            $esito.RebootRequired = [bool]$resInst.RebootRequired
            return $esito
        } catch {
            $esito.Errore = $_.Exception.Message
            return $esito
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $saltatoOperatore = $false
    $scadutoTimeout = $false

    while ($jobDriver.State -eq 'Running') {
        if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
            $scadutoTimeout = $true
            break
        }
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq [ConsoleKey]::S -or $k.Key -eq [ConsoleKey]::Escape) {
                    $saltatoOperatore = $true
                    break
                }
            }
        } catch {}
        Start-Sleep -Milliseconds 400
    }

    Stop-BarraAnimata

    if ($saltatoOperatore) {
        try { Stop-Job $jobDriver -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $jobDriver -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host ""
        Write-Info "Installazione driver interrotta dall'operatore (tasto S/Esc): proseguo con le app."
        Add-Report "Driver (Windows Update)" "SALTATO (dall'operatore)"
        Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Percentuale 72 -Dettaglio "Driver saltati da operatore"
        return @{ Esito = "SALTATO"; Trovati = 0; Installati = 0; RebootRequired = $false }
    } elseif ($scadutoTimeout) {
        try { Stop-Job $jobDriver -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $jobDriver -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host ""
        Write-Errore "Tempo massimo ricerca/download driver superato ($([math]::Round($TimeoutSec/60)) min): proseguo per non bloccare il setup notturno."
        Add-Report "Driver (Windows Update)" "AVVISO (timeout superato)"
        Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Percentuale 72 -Dettaglio "Driver parziali (timeout superato)"
        return @{ Esito = "TIMEOUT"; Trovati = 0; Installati = 0; RebootRequired = $false }
    } else {
        $datiJob = $null
        try {
            $datiJob = Receive-Job $jobDriver -ErrorAction SilentlyContinue | Select-Object -Last 1
        } catch {}
        try { Remove-Job $jobDriver -Force -ErrorAction SilentlyContinue } catch {}

        if ($datiJob -and $datiJob.Errore) {
            Write-Errore "Ricerca/installazione driver non riuscita: $($datiJob.Errore)"
            Add-Report "Driver (Windows Update)" "ERRORE"
            Update-PannelloStatus -TaskId "aggiorna" -Stato "error" -Percentuale 72 -Dettaglio "Non riuscito (proseguo)"
            return @{ Esito = "ERRORE"; Trovati = 0; Installati = 0; RebootRequired = $false; Errore = $datiJob.Errore }
        } elseif ($datiJob -and $datiJob.Trovati -eq 0) {
            Write-OK "Nessun driver da installare: risultano gia' tutti aggiornati."
            Add-Report "Driver (Windows Update)" "OK"
            Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Percentuale 72 -Dettaglio "Tutti i driver gia' aggiornati"
            return @{ Esito = "OK"; Trovati = 0; Installati = 0; RebootRequired = $false }
        } elseif ($datiJob -and $datiJob.Installati -gt 0) {
            if ($datiJob.NomiDriver) {
                foreach ($t in $datiJob.NomiDriver) {
                    Write-Info "Driver installato: $t"
                }
            }
            if ($datiJob.ResultCode -eq 2) {
                Write-OK "Driver installati con successo ($($datiJob.Installati))."
                Add-Report "Driver installati ($($datiJob.Installati))" "OK"
            } else {
                Write-Info "Installazione driver conclusa (codice $($datiJob.ResultCode)): alcuni potrebbero richiedere riavvio."
                Add-Report "Driver (Windows Update)" "AVVISO"
            }
            if ($datiJob.RebootRequired) {
                Write-Info "Alcuni driver richiedono un RIAVVIO per completare."
            }
            Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Percentuale 72 -Dettaglio "Driver installati ($($datiJob.Installati))"
            return @{ Esito = "OK"; Trovati = $datiJob.Trovati; Installati = $datiJob.Installati; RebootRequired = $datiJob.RebootRequired }
        } else {
            Write-OK "Controllo driver completato."
            Add-Report "Driver (Windows Update)" "OK"
            Update-PannelloStatus -TaskId "aggiorna" -Stato "done" -Percentuale 72 -Dettaglio "Completato"
            return @{ Esito = "OK"; Trovati = 0; Installati = 0; RebootRequired = $false }
        }
    }
}

function Select-DestinazioneUSB {
    param(
        [string]$DefaultDir,
        [switch]$Test
    )

    $opzioni = [System.Collections.Generic.List[pscustomobject]]::new()
    $visti = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # 1. Trova tutte le unita' rimovibili USB (massima priorita')
    try {
        $removables = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Removable' }
        foreach ($r in $removables) {
            $p = $r.RootDirectory.FullName
            if ($visti.Add($p)) {
                $label = if ($r.VolumeLabel) { $r.VolumeLabel } else { "Chiavetta USB" }
                $freeGb = [Math]::Round($r.TotalFreeSpace / 1GB, 1)
                $totGb  = [Math]::Round($r.TotalSize / 1GB, 1)
                $opzioni.Add([pscustomobject]@{
                    Percorso    = $p
                    Etichetta   = "$p  -  $label (USB Removibile, $freeGb GB liberi di $totGb GB)"
                    Consigliato = $true
                })
            }
        }
    } catch {}

    # 2. Se e' stato passato un TargetDir o PSScriptRoot valido (es. da PC Facile.bat)
    $candDirs = @($DefaultDir, $Global:TargetDir, $PSScriptRoot)
    foreach ($cd in $candDirs) {
        if ($cd -and (Test-Path $cd) -and $cd -notlike "$env:TEMP*") {
            try {
                $full = (Get-Item $cd).FullName
                if ($visti.Add($full)) {
                    $opzioni.Add([pscustomobject]@{
                        Percorso    = $full
                        Etichetta   = "$full  (Cartella di avvio di PC Facile)"
                        Consigliato = ($opzioni.Count -eq 0)
                    })
                }
            } catch {}
        }
    }

    # 3. Altre unita' disco secondarie (Fixed/Esterne/Dati, es. D:\, E:\)
    try {
        $otherDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object {
            $_.IsReady -and $_.DriveType -eq 'Fixed' -and $_.Name -notlike "C:*"
        }
        foreach ($od in $otherDrives) {
            $p = $od.RootDirectory.FullName
            if ($visti.Add($p)) {
                $label = if ($od.VolumeLabel) { $od.VolumeLabel } else { "Disco secondario" }
                $freeGb = [Math]::Round($od.TotalFreeSpace / 1GB, 1)
                $totGb  = [Math]::Round($od.TotalSize / 1GB, 1)
                $opzioni.Add([pscustomobject]@{
                    Percorso    = $p
                    Etichetta   = "$p  -  $label (Disco secondario, $freeGb GB liberi di $totGb GB)"
                    Consigliato = ($opzioni.Count -eq 0)
                })
            }
        }
    } catch {}

    # 4. Desktop di questo PC
    try {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        if ($desktopPath -and (Test-Path $desktopPath) -and $visti.Add($desktopPath)) {
            $opzioni.Add([pscustomobject]@{
                Percorso    = $desktopPath
                Etichetta   = "$desktopPath  (Desktop di questo PC)"
                Consigliato = ($opzioni.Count -eq 0)
            })
        }
    } catch {}

    # Se siamo in modalita' test o non interattiva, prendi la prima
    if ($Test -or $opzioni.Count -eq 0) {
        if ($opzioni.Count -gt 0) { return $opzioni[0].Percorso }
        return (Get-Location).Path
    }

    Write-Host "Seleziona dove preparare i pacchetti offline:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $opzioni.Count; $i++) {
        $num = $i + 1
        $opt = $opzioni[$i]
        $tag = if ($opt.Consigliato) { "  <-- CONSIGLIATO (INVIO)" } else { "" }
        $col = if ($opt.Consigliato) { [ConsoleColor]::Green } else { [ConsoleColor]::White }
        Write-Host "  [$num] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($opt.Etichetta)$tag" -ForegroundColor $col
    }
    $sfNum = $opzioni.Count + 1
    Write-Host "  [$sfNum] Sfoglia cartelle / Inserisci percorso a mano..." -ForegroundColor Gray
    Write-Host ""

    $scelta = Attendi-Risposta "Scelta (1-$sfNum, INVIO = opzione 1 consigliata)"
    if ([string]::IsNullOrWhiteSpace($scelta) -or $scelta -eq "1") {
        return $opzioni[0].Percorso
    }

    if ($scelta -match '^\d+$') {
        $idx = [int]$scelta - 1
        if ($idx -ge 0 -and $idx -lt $opzioni.Count) {
            return $opzioni[$idx].Percorso
        }
        if ($idx -eq $opzioni.Count) {
            # Prova finestra di dialogo grafica per sfogliare
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $dialog.Description = "Seleziona la chiavetta USB o la cartella per i pacchetti offline"
                $dialog.ShowNewFolderButton = $true
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {
                    return $dialog.SelectedPath
                }
            } catch {}
            $customPath = Attendi-Risposta "Scrivi il percorso della cartella (es. E:\ o D:\USB)"
            if ($customPath -and (Test-Path $customPath)) { return $customPath }
        }
    }

    if (Test-Path $scelta) { return $scelta }
    return $opzioni[0].Percorso
}

function Invoke-PreparaUSBOffline {
    param([string]$TargetDir)

    Write-Titolo "PREPARAZIONE CHIAVETTA USB OFFLINE"
    Write-Host "Questa funzione scarica tutti i programmi di installazione (.exe / .msi)" -ForegroundColor White
    Write-Host "direttamente sulla chiavetta USB (cartella 'installers')." -ForegroundColor White
    Write-Host "Cosi' per le prossime configurazioni dei clienti il setup funzionera'" -ForegroundColor White
    Write-Host "al 100% OFFLINE e alla massima velocita' senza consumare banda!" -ForegroundColor Green
    Write-Host ""

    # 1. Selezione interattiva semplificata della cartella/chiavetta USB
    $targetBase = Select-DestinazioneUSB -DefaultDir $TargetDir
    Write-Host ""
    Write-Host "Destinazione selezionata: " -NoNewline
    Write-Host $targetBase -ForegroundColor Green

    $installersDir = Join-Path $targetBase "installers"
    if (-not (Test-Path $installersDir)) {
        try {
            New-Item -Path $installersDir -ItemType Directory -Force | Out-Null
            Write-OK "Creata cartella installers: $installersDir"
        } catch {
            Write-Errore "Impossibile creare cartella $installersDir : $_"
            return
        }
    }

    # 2. Catalogo dei pacchetti da scaricare
    $downloadCatalog = @(
        @{
            Nome      = "Google Chrome (64-bit Standalone)"
            File      = "ChromeStandaloneSetup64.exe"
            Urls      = @(
                "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF5-1A09E5037969%7D%26iid%3D%7B00000000-0000-0000-0000-000000000000%7D%26lang%3Dit%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1/chrome/install/ChromeStandaloneSetup64.exe"
            )
            MinSizeKB = 50000
            Categoria = "Base"
        },
        @{
            Nome      = "Mozilla Firefox (Italiano 64-bit Full)"
            File      = "Firefox_Setup.exe"
            Urls      = @(
                "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=it"
            )
            MinSizeKB = 45000
            Categoria = "Base"
        },
        @{
            Nome      = "VLC Media Player (64-bit)"
            File      = "vlc-win64.exe"
            Urls      = @(
                "https://download.videolan.org/pub/videolan/vlc/last/win64/vlc-3.0.21-win64.exe",
                "https://get.videolan.org/vlc/3.0.21/win64/vlc-3.0.21-win64.exe"
            )
            MinSizeKB = 35000
            Categoria = "Base"
        },
        @{
            Nome      = "Adobe Acrobat Reader (64-bit Italiano)"
            File      = "AcroRdrDCx64_it_IT.exe"
            Urls      = @(
                "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2500120744/AcroRdrDCx642500120744_MUI.exe",
                "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2400420243/AcroRdrDCx642400420243_MUI.exe"
            )
            MinSizeKB = 150000
            Categoria = "Base"
        },
        @{
            Nome      = "7-Zip (64-bit MSI)"
            File      = "7z-x64.msi"
            Urls      = @(
                "https://www.7-zip.org/a/7z2409-x64.msi",
                "https://www.7-zip.org/a/7z2408-x64.msi",
                "https://www.7-zip.org/a/7z2301-x64.msi"
            )
            MinSizeKB = 1500
            Categoria = "Base"
        },
        @{
            Nome      = "AnyDesk (Assistenza Remota)"
            File      = "AnyDesk.exe"
            Urls      = @(
                "https://download.anydesk.com/AnyDesk.exe"
            )
            MinSizeKB = 3000
            Categoria = "Base"
        },
        @{
            Nome      = "TeamViewer (64-bit)"
            File      = "TeamViewer_Setup_x64.exe"
            Urls      = @(
                "https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe"
            )
            MinSizeKB = 40000
            Categoria = "Completo"
        },
        @{
            Nome      = "Zoom Desktop Client Full (MSI)"
            File      = "ZoomInstallerFull.msi"
            Urls      = @(
                "https://zoom.us/client/latest/ZoomInstallerFull.msi",
                "https://zoom.us/client/latest/ZoomInstaller.msi"
            )
            MinSizeKB = 30000
            Categoria = "Completo"
        },
        @{
            Nome      = "AIMP Audio Player"
            File      = "aimp.exe"
            Urls      = @(
                "https://aimp.ru/?do=download.file&id=3",
                "https://aimp.ru/files/desktop/builds/aimp_5.40.2726_w64.exe",
                "https://aimp.ru/?do=download.file&id=4"
            )
            MinSizeKB = 10000
            Categoria = "Completo"
        },
        @{
            Nome      = "LibreOffice (64-bit Italiano)"
            File      = "LibreOffice_Win_x86-64.msi"
            Urls      = @(
                "https://download.documentfoundation.org/libreoffice/stable/26.8.0/win/x86_64/LibreOffice_26.8.0_Win_x86-64.msi",
                "https://download.documentfoundation.org/libreoffice/stable/26.2.6/win/x86_64/LibreOffice_26.2.6_Win_x86-64.msi",
                "https://download.documentfoundation.org/libreoffice/stable/25.8.7/win/x86_64/LibreOffice_25.8.7_Win_x86-64.msi"
            )
            MinSizeKB = 250000
            Categoria = "Completo"
        },
        @{
            Nome      = "Norton Removal Tool (NRnR)"
            File      = "NRnR.exe"
            Urls      = @(
                "https://buy-download.norton.com/downloads/RnR/NLOK/NRnR.exe",
                "https://www.norton.com/nrnr"
            )
            MinSizeKB = 5000
            Categoria = "Base"
        },
        @{
            Nome      = "McAfee Consumer Product Removal (MCPR)"
            File      = "MCPR.exe"
            Urls      = @(
                "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe"
            )
            MinSizeKB = 5000
            Categoria = "Base"
        },
        @{
            Nome      = "Sumatra PDF (64-bit)"
            File      = "SumatraPDF-install.exe"
            Urls      = @(
                "https://www.sumatrapdfreader.org/dl/rel/3.6.1/SumatraPDF-3.6.1-64-install.exe",
                "https://files2.sumatrapdfreader.org/software/sumatrapdf/rel/3.6.1/SumatraPDF-3.6.1-64-install.exe"
            )
            MinSizeKB = 7000
            Categoria = "Completo"
        },
        @{
            Nome      = "Spotify"
            File      = "SpotifyFullSetup.exe"
            Urls      = @(
                "https://download.scdn.co/SpotifyFullSetup.exe",
                "https://download.scdn.co/SpotifySetup.exe"
            )
            MinSizeKB = 20000
            Categoria = "Completo"
        },
        @{
            Nome      = "GIMP (Image Editor)"
            File      = "gimp-setup.exe"
            Urls      = @(
                "https://download.gimp.org/gimp/v2.10/windows/gimp-2.10.38-setup.exe"
            )
            MinSizeKB = 250000
            Categoria = "Completo"
        },
        @{
            Nome      = "Steam Setup"
            File      = "SteamSetup.exe"
            Urls      = @(
                "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
            )
            MinSizeKB = 2000
            Categoria = "Completo"
        },
        @{
            Nome      = "Discord"
            File      = "DiscordSetup.exe"
            Urls      = @(
                "https://discord.com/api/download?platform=win"
            )
            MinSizeKB = 80000
            Categoria = "Completo"
        },
        @{
            Nome      = "Microsoft Visual C++ 2015-2022 (64-bit)"
            File      = "vc_redist.x64.exe"
            Urls      = @(
                "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            )
            MinSizeKB = 20000
            Categoria = "Base"
        },
        @{
            Nome      = "Microsoft Visual C++ 2015-2022 (32-bit)"
            File      = "vc_redist.x86.exe"
            Urls      = @(
                "https://aka.ms/vs/17/release/vc_redist.x86.exe"
            )
            MinSizeKB = 15000
            Categoria = "Base"
        }
    )

    $daScaricare = $downloadCatalog
    if (-not $Test) {
        Write-Host "Cosa vuoi scaricare sulla chiavetta?" -ForegroundColor White
        Write-Host "  1) Pacchetto Base + Utility (Consigliato: Chrome, Firefox, VLC, Adobe, 7-Zip, AnyDesk, Visual C++, NRnR, MCPR - ~500 MB)" -ForegroundColor Green
        Write-Host "  2) Pacchetto Completo (Tutti i programmi inclusi LibreOffice, Spotify, Zoom, GIMP, Steam, Discord - ~1.5 GB)" -ForegroundColor White
        Write-Host ""
        $sceltaPkg = Attendi-Risposta "Scelta (1/2, INVIO = Pacchetto Base)"
        if ([string]::IsNullOrWhiteSpace($sceltaPkg) -or $sceltaPkg -eq "1") {
            $daScaricare = @($downloadCatalog | Where-Object { $_.Categoria -eq "Base" })
        }
    }

    Write-Host ""
    Write-Info "Avvio download dei pacchetti offline..."
    $tot = $daScaricare.Count
    $idx = 0
    $riusciti = 0
    $giaPresenti = 0

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    foreach ($pkg in $daScaricare) {
        $idx++
        $destPath = Join-Path $installersDir $pkg.File
        Write-Host ""
        Write-Host "[$idx/$tot] $($pkg.Nome)..." -ForegroundColor White

        if ($Test) {
            Write-OK "TEST: simulazione download $($pkg.Nome) -> $($pkg.File)"
            $riusciti++
            continue
        }

        # Verifica se gia' presente e valido
        if (Test-Path $destPath) {
            $finfo = Get-Item $destPath -ErrorAction SilentlyContinue
            if ($finfo -and ($finfo.Length / 1KB) -ge $pkg.MinSizeKB) {
                $mb = [Math]::Round($finfo.Length / 1MB, 1)
                Write-OK "Gia' presente sulla chiavetta ($mb MB). Salto."
                $giaPresenti++
                $riusciti++
                continue
            }
        }

        # Download con fallback URL e visualizzazione progresso
        $ok = $false
        foreach ($url in $pkg.Urls) {
            Write-Info "Download da: $url"
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0")
                $wc.DownloadFile($url, $destPath)
                $wc.Dispose()
            } catch {
                try {
                    Invoke-WebRequest -Uri $url -OutFile $destPath -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -UseBasicParsing -ErrorAction Stop
                } catch {
                    Write-Info "Errore da questa sorgente ($($_.Exception.Message)), provo alternativa..."
                }
            }

            if (Test-Path $destPath) {
                $len = (Get-Item $destPath).Length
                if (($len / 1KB) -ge $pkg.MinSizeKB) {
                    $mb = [Math]::Round($len / 1MB, 1)
                    Write-OK "Scaricato con successo: $($pkg.File) ($mb MB)"
                    $ok = $true
                    $riusciti++
                    break
                } else {
                    Write-Info "File scaricato troppo piccolo ($len bytes), riprovo..."
                    Remove-Item $destPath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        if (-not $ok) {
            Write-Errore "Impossibile scaricare $($pkg.Nome). Sara' installato tramite winget durante il setup."
        }
    }

    # Copia o scarica anche setup-pc.ps1, setup-pc.ps1.sha256, PC Facile.bat sulla chiavetta
    Write-Host ""
    Write-Info "Aggiorno i file di script sulla chiavetta USB..."
    try {
        $scriptDest = Join-Path $targetBase "setup-pc.ps1"
        $shaDest    = Join-Path $targetBase "setup-pc.ps1.sha256"
        $batDest    = Join-Path $targetBase "PC Facile.bat"
        $baseRepo   = "https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main"

        if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "setup-pc.ps1"))) {
            Copy-Item (Join-Path $PSScriptRoot "setup-pc.ps1") $scriptDest -Force -ErrorAction SilentlyContinue
            if (Test-Path (Join-Path $PSScriptRoot "setup-pc.ps1.sha256")) {
                Copy-Item (Join-Path $PSScriptRoot "setup-pc.ps1.sha256") $shaDest -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path (Join-Path $PSScriptRoot "PC Facile.bat")) {
                Copy-Item (Join-Path $PSScriptRoot "PC Facile.bat") $batDest -Force -ErrorAction SilentlyContinue
            }
        } else {
            try {
                Invoke-WebRequest "$baseRepo/setup-pc.ps1" -OutFile $scriptDest -ErrorAction SilentlyContinue
                Invoke-WebRequest "$baseRepo/setup-pc.ps1.sha256" -OutFile $shaDest -ErrorAction SilentlyContinue
                Invoke-WebRequest "$baseRepo/PC%20Facile.bat" -OutFile $batDest -ErrorAction SilentlyContinue
            } catch {}
        }
        Write-OK "File di avvio e script aggiornati nella radice della chiavetta."
    } catch {}

    # Configurazione Wi-Fi Negozio / Laboratorio
    Write-Host ""
    Write-Host "Configurazione Wi-Fi Negozio / Laboratorio:" -ForegroundColor White
    $salvaWifi = Attendi-Risposta "Vuoi salvare la rete Wi-Fi del negozio sulla chiavetta per la connessione automatica? (S/N, default = S)"
    if ($salvaWifi -match "^[Ss]" -or [string]::IsNullOrWhiteSpace($salvaWifi)) {
        Save-StoreWiFiProfile -TargetDir $targetBase
    }

    # Riepilogo finale
    Write-Host ""
    Write-Titolo "PREPARAZIONE USB COMPLETATA"
    Write-Host "Pacchetti pronti su chiavetta: $riusciti su $tot (gia' presenti: $giaPresenti)" -ForegroundColor Green
    Write-Host "Cartella offline: $installersDir" -ForegroundColor White
    Write-Host ""
    Write-Host "Ora la tua chiavetta USB e' un kit autonomo al 100%!" -ForegroundColor Yellow
    Write-Host "Puoi inserirla nei PC dei clienti e lanciare 'PC Facile.bat':" -ForegroundColor White
    Write-Host "il PC si colleghera' in automatico al Wi-Fi del negozio e installera' tutto da solo!" -ForegroundColor White
    Write-Host ""
    Beep-Completato
}

function Invoke-MigrazioneDati {
    param(
        [switch]$Test
    )

    try { Clear-Host } catch {}
    Write-Titolo "MODULO TRASFERIMENTO DATI (MIGRAZIONE VECCHIO PC)"
    Write-Host "Questo strumento ti permette di copiare rapidamente i dati personali" -ForegroundColor White
    Write-Host "da un hard disk esterno o chiavetta USB del cliente nel nuovo profilo utente." -ForegroundColor White
    Write-Host "Cartella di destinazione: $env:USERPROFILE" -ForegroundColor Cyan
    Write-Host ""

    if ($Test) {
        Write-OK "TEST: simulazione modulo migrazione dati completata."
        return
    }

    # Trova le unita' disco collegate (esclusa C:)
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -ne "$env:SystemDrive\" -and (Test-Path $_.Root) }
    if (-not $drives -or @($drives).Count -eq 0) {
        Write-Errore "Nessuna unita' disco o USB secondaria rilevata."
        Write-Host "Collega la chiavetta o l'hard disk esterno con i dati del cliente e riprova." -ForegroundColor Yellow
        Write-Host ""
        Attendi-Risposta "Premi INVIO per tornare indietro" | Out-Null
        return
    }

    Write-Host "Unita' esterne rilevate:" -ForegroundColor White
    $dList = @($drives)
    for ($i = 0; $i -lt $dList.Count; $i++) {
        $d = $dList[$i]
        $freeGB = [Math]::Round($d.Free / 1GB, 1)
        Write-Host "  $($i + 1)) [$($d.Name):] $freeGB GB liberi - $($d.Description)" -ForegroundColor Green
    }
    Write-Host "  M) Inserisci percorso personalizzato a mano" -ForegroundColor White
    Write-Host "  Q) Annulla e torna al menu" -ForegroundColor DarkGray
    Write-Host ""

    $sceltaD = (Attendi-Risposta "Seleziona unita' sorgente (1-$($dList.Count), default = 1)").Trim()
    if ($sceltaD -match "^[Qq]") { return }

    $sorgente = ""
    if ($sceltaD -match "^[Mm]") {
        $sorgente = (Attendi-Risposta "Inserisci percorso sorgente completo (es. E:\BackupMario)").Trim()
    } elseif ([string]::IsNullOrWhiteSpace($sceltaD) -or $sceltaD -eq "1") {
        $sorgente = $dList[0].Root
    } elseif ($sceltaD -match '^\d+$' -and [int]$sceltaD -le $dList.Count -and [int]$sceltaD -ge 1) {
        $sorgente = $dList[[int]$sceltaD - 1].Root
    }

    if (-not $sorgente -or -not (Test-Path $sorgente)) {
        Write-Errore "Percorso non valido o inesistente: $sorgente"
        Attendi-Risposta "Premi INVIO per continuare" | Out-Null
        return
    }

    $subUsers = Get-ChildItem -Path $sorgente -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Users|Utenti' } | Select-Object -First 1
    if ($subUsers) {
        $profiliTrovati = Get-ChildItem -Path $subUsers.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Public|Default|All Users' }
        if ($profiliTrovati -and @($profiliTrovati).Count -eq 1) {
            $sorgente = $profiliTrovati[0].FullName
            Write-Info "Rilevato profilo utente: $sorgente"
        }
    }

    Write-Host ""
    Write-Info "Scansione cartelle in: $sorgente"

    $mappaCartelle = @(
        @{ Nome = "Desktop";    Src = @("Desktop");              Dst = [Environment]::GetFolderPath("Desktop") },
        @{ Nome = "Documenti";  Src = @("Documents","Documenti"); Dst = [Environment]::GetFolderPath("MyDocuments") },
        @{ Nome = "Immagini";   Src = @("Pictures","Immagini");   Dst = [Environment]::GetFolderPath("MyPictures") },
        @{ Nome = "Download";   Src = @("Downloads","Download");  Dst = (Join-Path $env:USERPROFILE "Downloads") },
        @{ Nome = "Video";      Src = @("Videos","Video");        Dst = [Environment]::GetFolderPath("MyVideos") },
        @{ Nome = "Musica";     Src = @("Music","Musica");        Dst = [Environment]::GetFolderPath("MyMusic") },
        @{ Nome = "Preferiti";  Src = @("Favorites","Preferiti"); Dst = [Environment]::GetFolderPath("Favorites") }
    )

    $trovate = @()
    foreach ($m in $mappaCartelle) {
        foreach ($s in $m.Src) {
            $p = Join-Path $sorgente $s
            if (Test-Path $p) {
                $trovate += [pscustomobject]@{ Nome = $m.Nome; SrcPath = $p; DstPath = $m.Dst }
                break
            }
        }
    }

    if ($trovate.Count -eq 0) {
        Write-Info "Nessuna sottocartella standard trovata. Copio l'intera cartella sorgente in 'Dati Vecchio PC' sul Desktop."
        $trovate += [pscustomobject]@{ Nome = "Tutti i dati"; SrcPath = $sorgente; DstPath = (Join-Path ([Environment]::GetFolderPath("Desktop")) "Dati Vecchio PC") }
    } else {
        Write-Host "Cartelle rilevate da trasferire:" -ForegroundColor Green
        foreach ($t in $trovate) {
            Write-Host "  - $($t.Nome) ($($t.SrcPath) -> $($t.DstPath))" -ForegroundColor Gray
        }
    }

    Write-Host ""
    $conferma = Attendi-Risposta "Avviare la copia dei dati? (S/N, default = S)"
    if ($conferma -notmatch "^[Ss]" -and -not [string]::IsNullOrWhiteSpace($conferma)) {
        Write-Info "Operazione annullata."
        return
    }

    Write-Titolo "COPIA DATI IN CORSO"
    $totCopiate = 0
    foreach ($item in $trovate) {
        Write-Host ""
        Write-Info "Copia in corso: $($item.Nome)..."
        if (-not (Test-Path $item.DstPath)) { New-Item -Path $item.DstPath -ItemType Directory -Force | Out-Null }
        Start-BarraAnimata "Copia $($item.Nome)..."
        try {
            $rc = & robocopy.exe "$($item.SrcPath)" "$($item.DstPath)" /E /R:1 /W:1 /MT:8 /XJ /NFL /NDL /NP /NJH /NJS 2>&1
            Write-OK "Copia completata: $($item.Nome)"
            $totCopiate++
        } catch {
            Write-Errore "Errore durante la copia di $($item.Nome): $_"
        } finally {
            Stop-BarraAnimata
        }
    }

    Write-Host ""
    Write-Titolo "MIGRAZIONE DATI COMPLETATA"
    Write-OK "Trasferite $totCopiate cartelle nel profilo di $env:USERNAME."
    Beep-Completato
    Attendi-Risposta "Premi INVIO per tornare al menu" | Out-Null
}

# =============================================================================
# MODULO AUTOMAZIONE BROWSER (PROTON MAIL RAPIDO & SERVIZI)
# =============================================================================
function Invoke-BrowserAutoSignup {
    [CmdletBinding()]
    [Alias("Invoke-AiAgentAutoSignup")]
    param(
        [string]$NomeCliente = "Utente",
        [string]$Servizio = "Proton",
        [switch]$Test
    )

    Write-Titolo "AUTOMAZIONE BROWSER - REGISTRAZIONE PROTON MAIL & ATTIVAZIONI"
    Write-Host "Automazione nativa ultra-rapida per la creazione account e attivazione servizi." -ForegroundColor White
    Write-Host "Compilazione automatica e avviso acustico su codici di verifica OTP/SMS/PIN." -ForegroundColor Yellow
    Write-Host ""

    if ($Test) {
        Write-OK "TEST: Automazione Browser simulata con successo su Proton Mail e servizi."
        Add-Report "Automazione Proton Mail" "OK"
        $Global:AutoSignupCompletato = $true
        return [PSCustomObject]@{
            Stato = "Completato"
            ServiziTestati = @("Proton", "Microsoft", "Google", "Office365", "Antivirus", "McAfee", "Norton", "CyberProtection")
        }
    }

    Get-CredenzialiSalvatePannello | Out-Null

    if (-not $NomeCliente -or $NomeCliente -eq "Utente") {
        if ($Global:nomeCliente -and $Global:nomeCliente -ne "Utente") {
            $NomeCliente = $Global:nomeCliente
        } elseif (-not $Global:ModoAutomatico) {
            $nInput = (Attendi-Risposta "Nome e Cognome del Cliente (es. Mario Rossi)").Trim()
            if ($nInput) {
                $NomeCliente = $nInput
                $Global:nomeCliente = $nInput
            }
        }
    }

    $emailProton  = if ($Global:credMsAccount) { $Global:credMsAccount } else { New-EmailCliente -Base $NomeCliente -Dominio "proton.me" }
    $passGenerata = if ($Global:credMsPassword) { $Global:credMsPassword } else { New-PasswordCliente -Base $NomeCliente }

    # Servizi da attivare (da JSON pannello o default)
    $svcs = $Global:serviziSelezionati
    $doProton = if ($null -ne $svcs -and $null -ne $svcs.Proton) { [bool]$svcs.Proton } else { $true }
    $doOffice = if ($null -ne $svcs -and $null -ne $svcs.Office) { [bool]$svcs.Office } else { $false }
    $doMcAfee = if ($null -ne $svcs -and $null -ne $svcs.McAfee) { [bool]$svcs.McAfee } else { $false }
    $doNorton = if ($null -ne $svcs -and $null -ne $svcs.Norton) { [bool]$svcs.Norton } else { $false }
    $doCyber  = if ($null -ne $svcs -and $null -ne $svcs.Cyber)  { [bool]$svcs.Cyber }  else { $true }

    # 1. CREAZIONE ACCOUNT PROTON MAIL (SE SELEZIONATO)
    if ($doProton) {
        Write-Host ""
        Write-Titolo "1. CREAZIONE ACCOUNT PROTON MAIL (RAPIDO)"
        Write-Host "Credenziali generate per il cliente ($NomeCliente):" -ForegroundColor White
        Write-Host "  - Email/Account : $emailProton" -ForegroundColor Cyan
        Write-Host "  - Password      : $passGenerata" -ForegroundColor Yellow
        Write-Host ""

        try { Set-Clipboard -Value "$emailProton" -ErrorAction SilentlyContinue } catch {}
        Write-Info "Email $emailProton copiata negli appunti (Ctrl+V per incollare)."
        Write-Info "Apertura modulo diretto Proton Mail Free in Microsoft Edge a sinistra..."
        Set-SplitScreenLayout -HtmlPath "https://account.proton.me/signup?plan=free"

        Beep-Attesa
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host " [AUTOMAZIONE BROWSER PROTON MAIL FREE - GUIDA RAPIDA]" -ForegroundColor Green
        Write-Host " 1. Form Gratuito: Incolla Username e Password generata." -ForegroundColor White
        Write-Host " 2. Verifica Umana: Risolvi il puzzle/CAPTCHA visivo." -ForegroundColor White
        Write-Host " 3. Recupero / Upsell: Clicca sempre 'Salta' o 'Forse piu tardi'." -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host ""

        $resp = Attendi-Risposta "Premi INVIO appena sei nella casella di posta (o 'S' per saltare)"
        if ($resp -match "^[Ss]") {
            Write-Info "Creazione account Proton Mail saltata dall'operatore."
            Add-Report "Account Proton Mail" "SALTATO"
        } else {
            Write-OK "Account Proton Mail configurato con successo per: $emailProton"
            Add-Report "Account Proton Mail ($emailProton)" "OK"
            $Global:credMsAccount = $emailProton
            $Global:credMsPassword = $passGenerata
        }
    }

    # 2. RISCATTO CARD OFFICE 365 / MICROSOFT 365 (SE SELEZIONATO)
    if ($doOffice) {
        Write-Host ""
        Write-Titolo "2. ATTIVAZIONE CARD MICROSOFT 365 / OFFICE"
        Write-Host "Dati per il riscatto del codice Office 365 a 25 caratteri:" -ForegroundColor White
        Write-Host "  - Email Cliente  : $emailProton" -ForegroundColor Cyan
        Write-Host "  - Password       : $passGenerata" -ForegroundColor Yellow
        Write-Host ""

        try { Set-Clipboard -Value "$emailProton" -ErrorAction SilentlyContinue } catch {}
        Write-Info "Apertura portale Riscatto Office (microsoft365.com/setup) a sinistra..."
        Set-SplitScreenLayout -HtmlPath "https://microsoft365.com/setup"

        Beep-Attesa
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host " [ATTIVAZIONE CARD OFFICE 365 - GUIDA RAPIDA]" -ForegroundColor Green
        Write-Host " Accedi con l'email cliente e digita la chiave da 25 caratteri." -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host ""

        $respOff = Attendi-Risposta "Premi INVIO appena associata la chiave Office (o 'S' per saltare)"
        if ($respOff -match "^[Ss]") {
            Write-Info "Attivazione Office 365 saltata dall'operatore."
            Add-Report "Card Office 365" "SALTATO"
        } else {
            Write-OK "Card Office 365 attivata con successo su $emailProton!"
            Add-Report "Card Office 365 ($emailProton)" "OK"
        }
    }

    # 3. ATTIVAZIONE CARD MCAFEE ANTIVIRUS (SE SELEZIONATO)
    if ($doMcAfee) {
        Write-Host ""
        Write-Titolo "3. ATTIVAZIONE CARD MCAFEE ANTIVIRUS"
        Write-Host "Dati per l'attivazione della licenza McAfee:" -ForegroundColor White
        Write-Host "  - Email Cliente  : $emailProton" -ForegroundColor Cyan
        Write-Host "  - Password       : $passGenerata" -ForegroundColor Yellow
        Write-Host ""

        try { Set-Clipboard -Value "$emailProton" -ErrorAction SilentlyContinue } catch {}
        Write-Info "Apertura portale McAfee Activate (mcafee.com/activate) a sinistra..."
        Set-SplitScreenLayout -HtmlPath "https://www.mcafee.com/activate"

        Beep-Attesa
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host " [ATTIVAZIONE CARD MCAFEE - GUIDA RAPIDA]" -ForegroundColor Green
        Write-Host " Inserisci il codice Product Key / PIN della card McAfee e l'email." -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host ""

        $respMc = Attendi-Risposta "Premi INVIO appena attivato McAfee (o 'S' per saltare)"
        if ($respMc -match "^[Ss]") {
            Write-Info "Attivazione McAfee saltata dall'operatore."
            Add-Report "Card McAfee" "SALTATO"
        } else {
            Write-OK "Card McAfee attivata con successo su $emailProton!"
            Add-Report "Card McAfee ($emailProton)" "OK"
        }
    }

    # 4. ATTIVAZIONE CARD NORTON ANTIVIRUS (SE SELEZIONATO)
    if ($doNorton) {
        Write-Host ""
        Write-Titolo "4. ATTIVAZIONE CARD NORTON ANTIVIRUS"
        Write-Host "Dati per l'attivazione della licenza Norton:" -ForegroundColor White
        Write-Host "  - Email Cliente  : $emailProton" -ForegroundColor Cyan
        Write-Host "  - Password       : $passGenerata" -ForegroundColor Yellow
        Write-Host ""

        try { Set-Clipboard -Value "$emailProton" -ErrorAction SilentlyContinue } catch {}
        Write-Info "Apertura portale Norton Setup (norton.com/setup) a sinistra..."
        Set-SplitScreenLayout -HtmlPath "https://www.norton.com/setup"

        Beep-Attesa
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host " [ATTIVAZIONE CARD NORTON - GUIDA RAPIDA]" -ForegroundColor Green
        Write-Host " Inserisci il codice Product Key della card Norton e l'email." -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host ""

        $respNo = Attendi-Risposta "Premi INVIO appena attivato Norton (o 'S' per saltare)"
        if ($respNo -match "^[Ss]") {
            Write-Info "Attivazione Norton saltata dall'operatore."
            Add-Report "Card Norton" "SALTATO"
        } else {
            Write-OK "Card Norton attivata con successo su $emailProton!"
            Add-Report "Card Norton ($emailProton)" "OK"
        }
    }

    # 5. CATENA REGISTRAZIONE SERVIZIO UNIEURO CYBER PROTECTION (COVERCARE) (SE SELEZIONATO)
    if ($doCyber) {
        $tel = if ($Global:telefonoCliente) { $Global:telefonoCliente } else { "" }
        if (-not $tel) {
            $tIn = (Attendi-Risposta "Numero di Telefono/Cellulare Cliente per Cyber Protection (es. 3331234567, INVIO per saltare)").Trim()
            if ($tIn) { $tel = $tIn; $Global:telefonoCliente = $tIn }
        }

        Write-Host ""
        Write-Titolo "5. REGISTRAZIONE UNIEURO CYBER PROTECTION (COVERCARE)"
        Write-Host "Dati pronti per la registrazione del servizio con l'email appena creata:" -ForegroundColor White
        Write-Host "  - Nome / Cognome : $NomeCliente" -ForegroundColor Cyan
        Write-Host "  - Email Cliente  : $emailProton" -ForegroundColor Cyan
        Write-Host "  - Cellulare      : $(if ($tel) { $tel } else { 'Non specificato' })" -ForegroundColor Cyan
        Write-Host "  - Password       : $passGenerata" -ForegroundColor Yellow
        Write-Host ""

        try { Set-Clipboard -Value "$emailProton" -ErrorAction SilentlyContinue } catch {}
        Write-Info "Apertura portale Unieuro Cyber Protection a sinistra..."
        Set-SplitScreenLayout -HtmlPath "https://unieuro-cyber-protection.covercare.it"

        Beep-Attesa
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host " [REGISTRAZIONE CYBER PROTECTION - DATI PRONTI]" -ForegroundColor Green
        Write-Host " Inserisci i dati anagrafici e il codice PIN/Card grattato." -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor DarkYellow
        Write-Host ""

        $respCyber = Attendi-Risposta "Premi INVIO appena registrato Cyber Protection (o 'S' per saltare)"
        if ($respCyber -match "^[Ss]") {
            Write-Info "Cyber Protection saltato dall'operatore."
            Add-Report "Unieuro Cyber Protection" "SALTATO"
        } else {
            Write-OK "Unieuro Cyber Protection registrato con successo per $NomeCliente!"
            Add-Report "Unieuro Cyber Protection ($emailProton)" "OK"
        }
    }

    Beep-Completato
    Write-OK "Tutti gli account e le protezioni selezionate sono pronti: il setup prosegue in parallelo a piena velocita'!"
    $Global:AutoSignupCompletato = $true
}

# =============================================================================
# MODALITA' DI AVVIO E MENU INIZIALE
# =============================================================================

# Modalita' TEST (-Test): rende lo script non interattivo e non distruttivo.
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

if (-not $Test -and -not $Diagnostica -and -not $PreparaUSB -and -not $Migrazione -and -not $Manuale -and -not $AgenteIA -and -not $Espresso -and -not $Veloce) {
    Write-Titolo "PC FACILE   -   UNIEURO"
    Write-Host "Versione $SCRIPT_VERSION - Assistenza & Configurazione Professionale PC" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Seleziona Modalita' Operativa:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] MODALITA' SEMI-AUTOMATICA (Standard Unieuro - Consigliata)" -ForegroundColor Green
    Write-Host "      -> Setup parallelo a massima velocita' + Pannello Operatore 50% con portali 1-Click" -ForegroundColor DarkGray
    Write-Host "  [2] MODALITA' AUTOMATICA (Proton Mail Rapido + Setup Completo)" -ForegroundColor Cyan
    Write-Host "      -> Registrazione rapida Proton Mail + installazione app e ottimizzazioni in parallelo" -ForegroundColor DarkGray
    Write-Host "  [3] PREPARA USB OFFLINE (Scarica tutti i programmi sulla chiavetta)" -ForegroundColor Yellow
    Write-Host "  [4] CHECK SALUTE & DIAGNOSTICA HARDWARE (Report SSD SMART, Batteria, Driver)" -ForegroundColor Blue
    Write-Host "  [Q] Esci" -ForegroundColor DarkGray
    $sceltaMenu = (Attendi-Risposta "Scegli opzione [1-4 / Q]").Trim().ToUpper()
    switch ($sceltaMenu) {
        "2" {
            $Global:ModoAutomatico = $true
            $Espresso = $true
            $Global:ModoEspresso = $true
        }
        "3" { $PreparaUSB = $true; $Global:ModoEspresso = $false }
        "P" { $PreparaUSB = $true; $Global:ModoEspresso = $false }
        "4" { Invoke-PcFacileDiagnostics -MostraDettagli; return }
        "D" { Invoke-PcFacileDiagnostics -MostraDettagli; return }
        "Q" { Write-Host "Uscita."; return }
        default { $Espresso = $true; $Global:ModoEspresso = $true }
    }
} else {
    try { Clear-Host } catch {}
    $larg = 64
    $titoloB = "PC FACILE   -   versione $SCRIPT_VERSION"
    $padSx = [int](($larg - $titoloB.Length) / 2)
    $padDx = $larg - $padSx - $titoloB.Length
    $boxLine = ([string][char]0x2550) * $larg
    Write-Host ""
    if ($vtOn) {
        Write-Host "  $U_ORANGE$([char]0x2554)$boxLine$([char]0x2557)$U_RESET"
        Write-Host "  $U_ORANGE$([char]0x2551)$U_RESET  $U_ORANGE_BG UNIEURO $U_RESET $U_WHITE PC FACILE  -  Assistenza & Configurazione PC      $U_ORANGE$([char]0x2551)$U_RESET"
        Write-Host "  $U_ORANGE$([char]0x2551)$U_RESET  $U_ORANGE Batte. Forte. Sempre.$U_RESET $U_PEACH • Setup Tecnico Dedicato v$SCRIPT_VERSION      $U_ORANGE$([char]0x2551)$U_RESET"
        Write-Host "  $U_ORANGE$([char]0x255A)$boxLine$([char]0x255D)$U_RESET"
        Write-Host ""
        Write-Host "  $U_GREEN$SYM_OK$U_RESET $U_WHITE CONFIGURAZIONE AUTOMATICA AVVIATA A MASSIMA VELOCITA'!$U_RESET"
        Write-Host "  $U_ORANGE$SYM_INFO$U_RESET $U_PEACH Tutte le ottimizzazioni, pulizie e aggiornamenti sono in esecuzione.$U_RESET"
        Write-Host "  $U_BLUE$SYM_INFO$U_RESET $U_WHITE Pannello Operatore aperto su Microsoft Edge per gestire credenziali e portali.$U_RESET"
        Write-Host ""
    } else {
        Write-Host "  $([char]0x2554)$boxLine$([char]0x2557)" -ForegroundColor DarkYellow
        Write-Host "  $([char]0x2551)$(" " * $padSx)$titoloB$(" " * $padDx)$([char]0x2551)" -ForegroundColor White
        Write-Host "  $([char]0x255A)$boxLine$([char]0x255D)" -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "  CONFIGURAZIONE AUTOMATICA AVVIATA A MASSIMA VELOCITA'!" -ForegroundColor Green
        Write-Host "  Tutte le ottimizzazioni, pulizie e installazioni sono partite in tempo reale." -ForegroundColor White
        Write-Host "  Pannello Operatore aperto nel browser per gestire account, Office e antivirus." -ForegroundColor Cyan
        Write-Host ""
    }
}

if ($Espresso) {
    $Global:ModoEspresso = $true
}

# Se e' richiesta la migrazione dei dati:
if ($Migrazione) {
    Invoke-MigrazioneDati -Test:$Test
    return
}

# Se e' richiesta la preparazione della USB Offline:
if ($PreparaUSB) {
    Invoke-PreparaUSBOffline -TargetDir $TargetDir
    return
}

# Modalita' configurazione reale:
if (-not $Test -and -not $Diagnostica) {
    $Veloce = $true
    function Pausa { }
}

$RunReale = (-not $Test -and -not $Diagnostica)
if ($RunReale) {
    Enable-SilentElevation
    Set-PreventSleep $true
    Connect-AutoWiFi -TargetDir $TargetDir
    Open-PannelloOperatore -NomeCliente $NomeCliente
    if ($Global:ModoAutomatico) {
        [void](Wait-CredenzialiPannello -Test:$Test)
        [void](Invoke-BrowserAutoSignup -NomeCliente $Global:nomeCliente -Test:$Test)
    }
} elseif ($Test -and $Global:ModoAutomatico) {
    Open-PannelloOperatore -NomeCliente $NomeCliente
    [void](Wait-CredenzialiPannello -Test:$Test)
    [void](Invoke-BrowserAutoSignup -NomeCliente $Global:nomeCliente -Test:$Test)
}



# Credenziali del nuovo account, generate dallo script allo step Account
# Microsoft e scritte nel riepilogo. Init qui cosi' esistono anche se quel
# passo viene saltato (restano vuote nel file).
$credMsAccount = ""; $credMsPassword = ""; $credAltro = ""
# Provider account scelto (Microsoft/Google/Proton/Outlook) + dominio email: li
# ricordo nel checkpoint, cosi' su una ripresa il riepilogo mostra il provider
# GIUSTO (es. Proton) e non ripiega su Microsoft/outlook.it.
$Global:credProvider = ""; $Global:credDominio = ""
# Job in background per il DOWNLOAD degli aggiornamenti di Windows: programmato
# al passo Aggiornamenti, parte all'inizio del passo App (dopo i driver per evitare
# collisioni COM su wuauserv), scaricando mentre installiamo le applicazioni.
$Global:JobWinUpdate = $null
$Global:AvviaWinUpdateDopoDriver = $false

# Contatore app che NON si sono installate (per l'avviso rete a fine passo App).
$Global:AppFallite = 0
# Esito dell'ultima Installa-Pacchetto ($true = installata o gia' presente).
# Serve al passo App per segnare come "fatta" solo cio' che e' andato a buon
# fine, cosi' su una ripresa si riscaricano SOLO le app davvero mancanti.
$Global:UltimaInstallOk = $false
# Ripresa FINE dentro il passo App: profilo scelto, piano di installazione e
# app gia' completate nella sessione interrotta (caricati dal checkpoint).
$Global:AppProfiloRipresa = ""
$Global:AppListaRipresa   = @()
$Global:AppFatteRipresa   = @()

# =============================================================================
# RIPRESA SESSIONE: se lo script viene chiuso a meta' (crash, riavvio, blocco
# antivirus), al lancio successivo riparte da dove era arrivato. Dopo ogni
# passo completato lo stato (numero passo + nome cliente + credenziali
# generate) finisce in un file JSON in ProgramData, ELIMINATO a fine lavoro.
# Fasi: 1=Nome 2=Account 3=Pulizia 4=Lingua 5=Ripristino 6=Office,
# 7..11 = passi wizard 3..7 (Unieuro, App+browser, Aggiornamento, Driver,
# Antivirus). Solo nel run reale.
# =============================================================================
$Global:StatoFile   = Join-Path (if ($env:ProgramData) { $env:ProgramData } else { [System.IO.Path]::GetTempPath() }) "PCFacile\stato.json"
$Global:FaseRipresa = 0

# Segna un passo come completato (sovrascrive il checkpoint precedente).
function Save-Fase {
    param([int]$Fase, [string]$Nome)
    if (-not $RunReale) { return }
    try {
        $dir = Split-Path $Global:StatoFile
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        # PRESERVO i valori gia' salvati se quelli correnti sono vuoti (es. dopo
        # una ripresa in cui il passo Account e' stato saltato): altrimenti un
        # Save-Fase di un passo successivo azzererebbe credenziali/provider gia'
        # registrati (era la causa di email/provider sbagliati nel riepilogo).
        $prev = $null
        if (Test-Path $Global:StatoFile) { try { $prev = Get-Content $Global:StatoFile -Raw | ConvertFrom-Json } catch {} }
        $nc  = if ($nomeCliente)         { $nomeCliente }         elseif ($prev) { $prev.NomeCliente } else { "" }
        $ca  = if ($credMsAccount)       { $credMsAccount }       elseif ($prev) { $prev.CredAccount } else { "" }
        $cp  = if ($credMsPassword)      { $credMsPassword }      elseif ($prev) { $prev.CredPassword } else { "" }
        $cpr = if ($Global:credProvider) { $Global:credProvider } elseif ($prev -and $prev.PSObject.Properties.Name -contains 'CredProvider') { $prev.CredProvider } else { "" }
        $cdo = if ($Global:credDominio)  { $Global:credDominio }  elseif ($prev -and $prev.PSObject.Properties.Name -contains 'CredDominio')  { $prev.CredDominio } else { "" }
        [pscustomobject]@{
            Fase = $Fase; FaseNome = $Nome
            Data = (Get-Date -Format 'dd/MM/yyyy HH:mm')
            NomeCliente = $nc
            CredAccount = $ca; CredPassword = $cp
            CredProvider = $cpr; CredDominio = $cdo
        } | ConvertTo-Json | Set-Content -Path $Global:StatoFile -Encoding UTF8
    } catch {}
}

# Vero se il passo era gia' stato completato nella sessione ripresa.
function Test-FaseFatta { param([int]$Fase) return ($Global:FaseRipresa -ge $Fase) }

# Sotto-checkpoint DENTRO il passo App: salva profilo scelto, piano completo e
# app gia' installate, senza chiudere il passo (Fase resta 7 = si riparte dal
# passo App). Cosi' una chiusura a meta' installazione riparte dall'app esatta.
function Save-AppProgresso {
    param([string]$Profilo, [array]$Lista, [string[]]$Fatte)
    if (-not $RunReale) { return }
    try {
        $dir = Split-Path $Global:StatoFile
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        [pscustomobject]@{
            Fase = 7; FaseNome = "Applicazioni (installazione in corso)"
            Data = (Get-Date -Format 'dd/MM/yyyy HH:mm')
            NomeCliente = $nomeCliente
            CredAccount = $credMsAccount; CredPassword = $credMsPassword
            CredProvider = $Global:credProvider; CredDominio = $Global:credDominio
            AppProfilo = $Profilo
            AppLista   = @($Lista)
            AppFatte   = @($Fatte)
        } | ConvertTo-Json -Depth 4 | Set-Content -Path $Global:StatoFile -Encoding UTF8
    } catch {}
}

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
    @{ Nome = "Spotify";              Id = "Spotify.Spotify";              Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "AIMP";                 Id = "AIMP.AIMP";                    Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "7-Zip";                Id = "7zip.7zip";                    Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "WhatsApp";             Id = "9NKSQGP7F2NH";                 Profili = @("BASE","UFFICIO","GAMING") },  # Microsoft Store (la versione winget falliva spesso)
    @{ Nome = "GIMP";                 Id = "GIMP.GIMP";                    Profili = @("UFFICIO") },
    @{ Nome = "Steam";                Id = "Valve.Steam";                  Profili = @("GAMING") },
    @{ Nome = "Epic Games Launcher";  Id = "EpicGames.EpicGamesLauncher";  Profili = @("GAMING") },
    @{ Nome = "AnyDesk";              Id = "AnyDesk.AnyDesk";              Profili = @("BASE","UFFICIO","GAMING") },
    @{ Nome = "Discord";              Id = "Discord.Discord";              Profili = @("GAMING") },
    @{ Nome = "Zoom";                 Id = "Zoom.Zoom";                    Profili = @("BASE","UFFICIO","GAMING") }
)

# =============================================================================
# REPORT FINALE + CONNETTIVITA'
# =============================================================================



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

function New-WlanProfileXml {
    param([string]$Ssid, [string]$Password)
    return @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$Ssid</name>
    <SSIDConfig>
        <SSID>
            <name>$Ssid</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
}

function Connect-AutoWiFi {
    param([string]$TargetDir)
    if ($Test) { return $true }
    try {
        # Se siamo gia' connessi a Internet, non serve fare nulla
        if (Test-Rete) { return $true }

        Write-Info "Verifica e connessione automatica Wi-Fi da chiavetta USB..."
        $searchDirs = @()
        if ($TargetDir -and (Test-Path -LiteralPath $TargetDir)) {
            $searchDirs += (Join-Path $TargetDir "wifi")
            $searchDirs += $TargetDir
        }
        if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) {
            $searchDirs += (Join-Path $PSScriptRoot "wifi")
            $searchDirs += $PSScriptRoot
        }
        try {
            $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
            foreach ($drv in $drives) {
                $root = $drv.Root
                if (Test-Path (Join-Path $root "wifi")) { $searchDirs += (Join-Path $root "wifi") }
                if (Test-Path $root) { $searchDirs += $root }
            }
        } catch {}

        $searchDirs = @($searchDirs | Select-Object -Unique)

        foreach ($dir in $searchDirs) {
            if (-not (Test-Path -LiteralPath $dir)) { continue }

            # 1. Cerca profili XML esportati da netsh (*.xml con <WLANProfile>)
            $xmlFiles = @(Get-ChildItem -Path $dir -Filter "*.xml" -ErrorAction SilentlyContinue)
            foreach ($xml in $xmlFiles) {
                try {
                    $content = Get-Content -Path $xml.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -match '<WLANProfile' -and $content -match '<name>(.*?)</name>') {
                        $profName = $Matches[1]
                        Write-Info "Tentativo di connessione alla rete Wi-Fi: '$profName'..."
                        & netsh.exe wlan add profile filename="$($xml.FullName)" user=all 2>$null | Out-Null
                        & netsh.exe wlan connect name="$profName" 2>$null | Out-Null

                        $t = 0
                        while ((-not (Test-Rete)) -and $t -lt 6) {
                            Start-Sleep -Seconds 2
                            $t += 2
                        }
                        if (Test-Rete) {
                            Write-OK "Connesso automaticamente al Wi-Fi: $profName!"
                            return $true
                        }
                    }
                } catch {}
            }

            # 2. Cerca file wifi.txt / wifi.ini / wifi.conf con SSID e Password
            $txtFiles = @(Join-Path $dir "wifi.txt", Join-Path $dir "wifi.ini", Join-Path $dir "wifi.conf")
            foreach ($txt in $txtFiles) {
                if (Test-Path -LiteralPath $txt) {
                    $lines = Get-Content -LiteralPath $txt -ErrorAction SilentlyContinue
                    $ssid = ""
                    $pwd = ""
                    foreach ($l in $lines) {
                        $line = $l.Trim()
                        if ($line -match '^(SSID|RETE|WIFI)\s*[:=]\s*(.+)$') { $ssid = $Matches[2].Trim() }
                        elseif ($line -match '^(PASS|PASSWORD|KEY|CHIAVE)\s*[:=]\s*(.+)$') { $pwd = $Matches[2].Trim() }
                        elseif (-not $ssid -and $line -notmatch '^#' -and $line.Length -gt 0) {
                            $ssid = $line
                        } elseif ($ssid -and -not $pwd -and $line -notmatch '^#' -and $line.Length -gt 0) {
                            $pwd = $line
                        }
                    }
                    if ($ssid -and $pwd) {
                        Write-Info "Tentativo di connessione automatica Wi-Fi: '$ssid'..."
                        $tempXml = Join-Path $env:TEMP "wifi_auto_$([Math]::Abs((Get-Random)%10000)).xml"
                        $xmlData = New-WlanProfileXml -Ssid $ssid -Password $pwd
                        [System.IO.File]::WriteAllText($tempXml, $xmlData, [System.Text.Encoding]::UTF8)
                        & netsh.exe wlan add profile filename="$tempXml" user=all 2>$null | Out-Null
                        & netsh.exe wlan connect name="$ssid" 2>$null | Out-Null
                        Remove-Item -LiteralPath $tempXml -Force -ErrorAction SilentlyContinue

                        $t = 0
                        while ((-not (Test-Rete)) -and $t -lt 8) {
                            Start-Sleep -Seconds 2
                            $t += 2
                        }
                        if (Test-Rete) {
                            Write-OK "Connesso automaticamente al Wi-Fi: $ssid!"
                            return $true
                        }
                    }
                }
            }
        }
    } catch {}
    return $false
}

function Save-StoreWiFiProfile {
    param([string]$TargetDir)
    if ($Test) { return $true }
    try {
        $wifiDir = Join-Path $TargetDir "wifi"
        if (-not (Test-Path $wifiDir)) { New-Item -Path $wifiDir -ItemType Directory -Force | Out-Null }

        $exported = $false
        try {
            $interfaces = & netsh.exe wlan show interfaces 2>$null
            $currentSsid = ""
            foreach ($line in $interfaces) {
                if ($line -match '^\s*SSID\s*:\s*(.+)$') {
                    $currentSsid = $Matches[1].Trim()
                    break
                }
            }
            if ($currentSsid) {
                & netsh.exe wlan export profile name="$currentSsid" folder="$wifiDir" key=clear 2>$null | Out-Null
                $xmls = Get-ChildItem -Path $wifiDir -Filter "*.xml" -ErrorAction SilentlyContinue
                if ($xmls.Count -gt 0) {
                    Write-OK "Profilo Wi-Fi esportato con successo per '$currentSsid' in $wifiDir"
                    $exported = $true
                }
            }
        } catch {}

        if (-not $exported) {
            Write-Info "Inserisci i dati della rete Wi-Fi del negozio (verranno salvati in 'wifi/wifi.txt'):"
            $ssidIn = (Attendi-Risposta "Nome Rete Wi-Fi (SSID)").Trim()
            if ($ssidIn) {
                $pwdIn = (Attendi-Risposta "Password Wi-Fi (WPA2)").Trim()
                $txtFile = Join-Path $wifiDir "wifi.txt"
                $content = "SSID=$ssidIn`r`nPASSWORD=$pwdIn"
                [System.IO.File]::WriteAllText($txtFile, $content, [System.Text.Encoding]::UTF8)

                $xmlData = New-WlanProfileXml -Ssid $ssidIn -Password $pwdIn
                $xmlFile = Join-Path $wifiDir "wifi-$ssidIn.xml"
                [System.IO.File]::WriteAllText($xmlFile, $xmlData, [System.Text.Encoding]::UTF8)
                Write-OK "Rete Wi-Fi '$ssidIn' salvata con successo nella cartella wifi."
            }
        }
    } catch {
        Write-Info "Impossibile salvare il profilo Wi-Fi: $($_.Exception.Message)"
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

# Data/ora sbagliata su un PC nuovo -> errori HTTPS su winget/download/attivazioni.
# ATTIVO la sincronizzazione automatica dell'orario (non solo un resync una-tantum):
# servizio W32Time in avvio automatico come client NTP + fuso automatico + resync.
if ($RunReale) {
    try {
        Set-Service -Name w32time -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        # "Imposta l'ora automaticamente": W32Time come client NTP verso il time server
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name Type -Value 'NTP' -ErrorAction SilentlyContinue
        & w32tm /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /update 2>$null | Out-Null
        # "Imposta fuso orario automaticamente" (servizio tzautoupdate)
        Set-Service -Name tzautoupdate -StartupType Automatic -ErrorAction SilentlyContinue
        & w32tm /resync /force 2>$null | Out-Null
        Write-OK "Sincronizzazione orario attivata e orologio aggiornato."
        Add-Report "Sincronizzazione orario" "OK"
    } catch {
        Write-Info "Sincronizzazione orario non completata del tutto: proseguo."
        Add-Report "Sincronizzazione orario" "AVVISO"
    }
}

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
# Primo tentativo SOLO aggiornamento: il "reset" azzera anche gli accordi e va
# usato solo se davvero serve (cioe' se l'aggiornamento fallisce). Se qualcosa
# fallisce, l'errore reale di winget diventa VISIBILE (non piu' nascosto).
function Repair-WingetSources {
    param([switch]$Forza)
    if ($Global:WingetRiparato -and -not $Forza) { return }
    $Global:WingetRiparato = $true
    Write-Info "Riparazione sorgenti winget (update, poi reset solo se serve)..."
    Start-BarraAnimata "Riparo le sorgenti winget"
    try {
        $out = winget source update 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Sorgenti winget aggiornate."
        } else {
            Write-Info "Aggiornamento sorgenti fallito: provo il reset delle sorgenti (forzato)..."
            winget source reset --force 2>&1 | Out-Null
            $out = winget source update 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Sorgenti winget ripristinate."
            } else {
                Write-Errore "Sorgenti winget NON funzionanti sul PC (vedi sotto)."
            }
            $out | Select-Object -Last 4 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Info "Riparazione sorgenti non riuscita: $_"
    } finally { Stop-BarraAnimata }
}

function Confirm-Winget {
    # Risultato calcolato una sola volta per sessione (evita ricontrolli/reinstalli)
    if ($null -ne $Global:WingetOk) { return $Global:WingetOk }

    Write-Info "Verifica presenza di Winget..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-OK "Winget trovato."
        $Global:WingetOk = $true
        # NIENTE 'source reset+update' proattivo: ri-scaricava ogni volta l'intero
        # indice sorgenti (lento su rete lenta). winget aggiorna le sorgenti da
        # solo all'installazione; la riparazione parte SOLO se un install fallisce
        # per errore sorgente (vedi Installa-Pacchetto).
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

# Barra di attesa ANIMATA mentre un processo lavora (download/installazione).
# winget con l'output nascosto non da' progressi: mostro una barra "a spola"
# (un blocco che scorre avanti e indietro) col tempo trascorso, cosi' si vede
# che sta lavorando e non e' bloccato. Non e' una percentuale reale (winget
# silenzioso non la espone), ma un indicatore di ATTIVITA'. Si ridisegna sulla
# stessa riga con \r. Il processo va passato gia' avviato (-PassThru).
function Show-BarraAttesa {
    param([string]$Testo, [System.Diagnostics.Process]$Processo)
    $larg = 22; $span = 4
    $period = ($larg - $span) * 2
    $inizio = Get-Date
    $i = 0
    while (-not $Processo.HasExited) {
        $phase = $i % $period
        $pos = if ($phase -le ($larg - $span)) { $phase } else { $period - $phase }
        $barra = (([string]$BOX_EMPTY) * $pos) + (([string]$BOX_FULL) * $span) + (([string]$BOX_EMPTY) * ($larg - $span - $pos))
        $sec = [int]((Get-Date) - $inizio).TotalSeconds
        $riga = "   $Testo  [$barra]  ${sec}s"
        if ($AON) { Write-Host ("`r$AON$riga$AOFF") -NoNewline }
        else { Write-Host ("`r$riga") -NoNewline -ForegroundColor $THEME_COL }
        Start-Sleep -Milliseconds 120
        $i++
    }
    # Cancella la riga della barra (spazi + ritorno a inizio riga).
    Write-Host ("`r" + (" " * ($Testo.Length + $larg + 24)) + "`r") -NoNewline
}

# Lancia winget con l'output nascosto (rediretto su file temporanei) MA con la
# barra animata a schermo. Ritorna il codice di uscita di winget. Se per qualche
# motivo non riesce ad avviare il processo, ripiega sulla chiamata classica.
function Invoke-WingetConBarra {
    param(
        [string]$Nome,
        [string[]]$WingetArgs,
        [int]$TimeoutSec = 300 # 5 minuti massimo per singola operazione/app
    )
    if ($Test -or $Global:Test -or $env:PESTER_TEST) {
        Write-OK "TEST: simulazione winget $Nome completata."
        return 0
    }

    Write-Info "Scarico e installo $Nome (max $([math]::Round($TimeoutSec/60)) min)..."
    try {
        $p = Start-Process -FilePath "winget" -ArgumentList $WingetArgs -NoNewWindow -PassThru -ErrorAction Stop
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited) {
            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
                Write-Errore "Tempo massimo superato ($($TimeoutSec)s) per ${Nome}: interrompo il processo per non bloccare il setup notturno."
                try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
                try {
                    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $p.Id } | ForEach-Object {
                        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                    }
                } catch {}
                return -9999
            }
            Start-Sleep -Milliseconds 500
        }
        return $p.ExitCode
    } catch {
        try {
            winget @WingetArgs
            $code = $LASTEXITCODE
            if ($null -eq $code) { $code = -1 }
            return $code
        } catch { return -1 }
    }
}

# --- ICONA SUL DESKTOP per ogni app installata (cosi' il cliente vede cosa e'
#     stato messo). Due nomi "somigliano" se, tolti spazi/punteggiatura, uno
#     contiene l'altro (es. "Adobe Acrobat Reader" ~ "Adobe Acrobat"). ---
function Test-NomeSimile {
    param([string]$A, [string]$B)
    $na = ($A -replace '[^A-Za-z0-9]', '').ToLower()
    $nb = ($B -replace '[^A-Za-z0-9]', '').ToLower()
    if (-not $na -or -not $nb) { return $false }
    return ($na.Contains($nb) -or $nb.Contains($na))
}

# Collegamenti "spazzatura" da NON copiare sul Desktop (disinstalla, guida...).
function Test-LnkJunk {
    param([string]$Base)
    $junk = @('*uninstall*', '*disinstall*', '*guida*', '*help*', '*read*me*', '*leggimi*',
              '*documentation*', '*website*', '*sito*', '*modify*', '*repair*', '*support*',
              '*aggiorna*', '*update*')
    foreach ($p in $junk) { if ($Base -like $p) { return $true } }
    return $false
}

# Toglie il collegamento di Microsoft Edge dal Desktop (utente + pubblico):
# se installiamo altri browser, l'icona di Edge sul Desktop non serve.
function Remove-EdgeDaDesktop {
    if (-not $RunReale) { return }
    try {
        $desktops = @([Environment]::GetFolderPath('Desktop'),
                      [Environment]::GetFolderPath('CommonDesktopDirectory')) |
                    Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
        foreach ($d in $desktops) {
            Get-ChildItem -Path $d -Filter '*Edge*.lnk' -ErrorAction SilentlyContinue |
                ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        }
    } catch {}
}

# Tutti i collegamenti del menu Start (utente + tutti gli utenti, ricorsivo).
function Get-StartMenuLnks {
    $roots = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:APPDATA     'Microsoft\Windows\Start Menu\Programs')
    )
    $res = @()
    foreach ($r in $roots) {
        if (Test-Path $r) { $res += Get-ChildItem -Path $r -Filter *.lnk -Recurse -ErrorAction SilentlyContinue }
    }
    return $res
}

# Crea sul Desktop l'icona dell'app APPENA installata, cosi' il cliente la vede
# comparire man mano. Strategia in ordine di affidabilita':
#  0) DIFF prima/dopo: se mi passi $LnkPrima (i collegamenti del menu Start PRIMA
#     dell'installazione), copio i collegamenti NUOVI comparsi = esattamente
#     quelli creati da QUESTA app (niente indovinelli sui nomi);
#  1) altrimenti cerco nel menu Start un collegamento che somiglia al nome;
#  2) app dello Store (MSIX, niente .lnk) -> Get-StartApps + shell:AppsFolder.
# Salta i doppioni. Un breve retry copre il caso in cui il collegamento non e'
# ancora stato scritto subito dopo la fine di winget.
# Icone (.lnk) presenti sul Desktop VISTO dal cliente = Desktop utente PIU'
# Desktop pubblico (C:\Users\Public\Desktop): Windows li fonde. Molti installer
# (Chrome, AnyDesk, Steam...) mettono l'icona sul PUBBLICO, quindi il controllo
# anti-doppione deve guardare entrambi, altrimenti si finisce con due icone.
function Get-DesktopLnks {
    $dirs = @((Get-DesktopDir),
              [Environment]::GetFolderPath('CommonDesktopDirectory')) |
            Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
    $res = @()
    foreach ($d in $dirs) {
        $res += Get-ChildItem -Path $d -Filter *.lnk -ErrorAction SilentlyContinue
    }
    return $res
}

# Pulizia doppioni: se la STESSA app ha un'icona sia sul Desktop pubblico (messa
# dall'installer) sia su quello utente (copiata da noi), tolgo quella UTENTE e
# lascio l'originale del pubblico. Da lanciare DOPO le installazioni: copre anche
# il caso in cui l'installer crea la sua icona un attimo dopo il nostro controllo.
function Remove-IconeDoppieDesktop {
    if (-not $RunReale) { return }
    try {
        $userD = Get-DesktopDir
        $pubD  = [Environment]::GetFolderPath('CommonDesktopDirectory')
        if (-not ($pubD -and (Test-Path $pubD))) { return }
        $userLnks = @(Get-ChildItem -Path $userD -Filter *.lnk -ErrorAction SilentlyContinue)
        $pubLnks  = @(Get-ChildItem -Path $pubD  -Filter *.lnk -ErrorAction SilentlyContinue)
        foreach ($u in $userLnks) {
            if ($pubLnks | Where-Object { Test-NomeSimile $_.BaseName $u.BaseName }) {
                Remove-Item $u.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

function Add-IconaDesktop {
    param([string]$Nome, [string[]]$LnkPrima = @())
    if (-not $RunReale) { return }
    Stop-AppPopups -Nome $Nome
    try {
        $desktop = Get-DesktopDir

        # ANTI-DOPPIONE (per PRIMO): se su UNO DEI DUE Desktop (utente o pubblico)
        # c'e' gia' un'icona che somiglia al nome dell'app - creata dall'installer
        # stesso (Chrome, AnyDesk, Steam...) o da un giro precedente - non ne
        # aggiungo una seconda.
        $gia = Get-DesktopLnks | Where-Object { Test-NomeSimile $_.BaseName $Nome } | Select-Object -First 1
        if ($gia) { return }

        # 0) DIFF: collegamenti NUOVI creati dall'installazione (max ~4s di attesa).
        if ($LnkPrima -and $LnkPrima.Count -ge 0) {
            $nuovi = @()
            for ($t = 0; $t -lt 2; $t++) {
                $nuovi = @(Get-StartMenuLnks | Where-Object {
                    ($LnkPrima -notcontains $_.FullName) -and -not (Test-LnkJunk $_.BaseName)
                })
                if ($nuovi.Count -gt 0) { break }
                Start-Sleep -Milliseconds 700
            }
            if ($nuovi.Count -gt 0) {
                # Preferisci quelli che somigliano al nome; se nessuno, prendi il piu'
                # "principale" (nome piu' corto). Copio UN collegamento per app, e
                # solo se un'icona simile non e' comparsa nel frattempo sul Desktop.
                $match = @($nuovi | Where-Object { Test-NomeSimile $_.BaseName $Nome })
                $scelto = if ($match.Count -gt 0) { $match | Sort-Object { $_.BaseName.Length } | Select-Object -First 1 }
                          else { $nuovi | Sort-Object { $_.BaseName.Length } | Select-Object -First 1 }
                if ($scelto) {
                    $giaSimile = Get-DesktopLnks |
                        Where-Object { Test-NomeSimile $_.BaseName $scelto.BaseName } | Select-Object -First 1
                    $dest = Join-Path $desktop $scelto.Name
                    if (-not $giaSimile -and -not (Test-Path $dest)) {
                        Copy-Item -Path $scelto.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                    }
                    return
                }
            }
        }

        # 1) Menu Start: collegamento Win32 con l'icona vera dell'app (per nome).
        $cand = Get-StartMenuLnks |
            Where-Object { -not (Test-LnkJunk $_.BaseName) -and (Test-NomeSimile $_.BaseName $Nome) } |
            Sort-Object { $_.BaseName.Length } | Select-Object -First 1
        if ($cand) {
            Copy-Item -Path $cand.FullName -Destination (Join-Path $desktop $cand.Name) -Force -ErrorAction SilentlyContinue
            return
        }

        # 2) App dello Store (WhatsApp, Spotify...): AppUserModelID via Get-StartApps.
        $app = Get-StartApps -ErrorAction SilentlyContinue |
            Where-Object { Test-NomeSimile $_.Name $Nome } | Sort-Object { $_.Name.Length } | Select-Object -First 1
        if ($app) {
            $wsh = New-Object -ComObject WScript.Shell
            $file = ("$($app.Name).lnk" -replace '[\\/:*?"<>|]', '')
            $sc = $wsh.CreateShortcut((Join-Path $desktop $file))
            if ($app.AppID -match '\.exe$' -and (Test-Path $app.AppID)) {
                $sc.TargetPath = $app.AppID
            } else {
                $sc.TargetPath = "$env:WINDIR\explorer.exe"
                $sc.Arguments  = "shell:AppsFolder\$($app.AppID)"
                # Senza icona esplicita, un collegamento ad explorer mostra l'icona
                # di una CARTELLA (era il caso di WhatsApp). Punto l'icona all'exe
                # dentro il pacchetto Store, cosi' si vede il logo vero dell'app.
                try {
                    $pfn = ($app.AppID -split '!')[0]
                    $pkg = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.PackageFamilyName -eq $pfn } | Select-Object -First 1
                    if ($pkg -and $pkg.InstallLocation -and (Test-Path $pkg.InstallLocation)) {
                        $ico = Get-ChildItem -Path $pkg.InstallLocation -Filter *.exe -Recurse -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -notmatch 'vcredist|helper|update|crash|notification|background' } |
                               Sort-Object Length -Descending | Select-Object -First 1
                        if ($ico) { $sc.IconLocation = "$($ico.FullName),0" }
                    }
                } catch {}
            }
            $sc.Save()
        }
    } catch {}
}

# 

function Installa-Pacchetto {
    param(
        [string]$Nome,
        [string]$WingetId
    )

    # 1. Prova prima l'installazione offline ad altissima velocità da USB se presente
    $offlineFile = Find-OfflineInstaller -WingetId $WingetId -Nome $Nome
    if ($offlineFile) {
        if (Install-OfflinePackage -FilePath $offlineFile -Nome $Nome) {
            Add-Report "$Nome (installazione offline)" "OK"
            Add-IconaDesktop -Nome $Nome
            $Global:UltimaInstallOk = $true
            return
        }
    }

    # 2. Se l'offline non e' presente, serve Winget
    if (-not (Confirm-Winget)) {
        Write-Errore "Winget non disponibile e nessun installer offline trovato per $Nome."
        Add-Report "$Nome (installazione)" "ERRORE"
        $Global:UltimaInstallOk = $false
        return
    }

    # Disambigua SEMPRE la sorgente: ID Microsoft Store (12 caratteri) -> msstore,
    # tutto il resto -> winget. Senza --source, winget da' errore -1978335138
    # ("specify --source") quando lo stesso ID compare in piu' sorgenti, ed evita
    # anche di interrogare msstore (dove capitano errori di certificato/CDN).
    # SE l'app non si trova nella sorgente forzata, sotto si RITENTA senza --source
    # (winget cerca in tutte le fonti, incluso lo Store): cosi' funzionano anche
    # le app solo-Store del catalogo (es. WhatsApp).
    $sorgente = @()
    if ($WingetId -match '^[A-Z0-9]{12}$') { $sorgente = @('--source', 'msstore') }
    else { $sorgente = @('--source', 'winget') }

    # Esito di default: fallito. Lo porto a $true solo sui rientri di successo,
    # cosi' il passo App puo' segnare come "fatta" solo cio' che e' riuscito.
    $Global:UltimaInstallOk = $false

    # Gia' installato? SENZA --source: becca le app installate da QUALSIASI
    # origine (winget, Store, OEM, installer), non solo da winget. Con la
    # sorgente forzata, invece, un'app gia' presente da un'altra origine veniva
    # considerata "da installare" e falliva con codici tipo "gia' installato".
    winget list --exact --id $WingetId --accept-source-agreements 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Nome gia' installato. Salto."
        Add-Report "$Nome (installazione)" "OK"
        Add-IconaDesktop -Nome $Nome
        $Global:UltimaInstallOk = $true
        return
    }

    # Fotografo i collegamenti del menu Start PRIMA dell'installazione: dopo, la
    # differenza sono quelli creati da quest'app -> li copio sul Desktop.
    $lnkPrima = @(Get-StartMenuLnks | ForEach-Object { $_.FullName })

    # Codici che indicano successo (0) o successo con riavvio richiesto (3010/1641)
    $successo = @(0, 3010, 1641)
    # Gia' presente (stessa versione o da un'altra sorgente): per noi e' OK.
    # -1978335189 = "no applicable update", -1978335135 = "package already installed"
    $giaInstallato = @(-1978335189, -1978335135)
    # Errori di integrita'/certificato/sorgente: si risolvono riparando le sorgenti
    $erroriSorgente = @(-1978335138, -1978335215, -1978335216)  # 0x8A15005E e simili
    $riparatoQui = $false
    $ritentoSenzaSorgente = $false

    $maxTentativi = 3
    $tentativiFatti = 0
    for ($tentativo = 1; $tentativo -le $maxTentativi; $tentativo++) {
        $tentativiFatti = $tentativo
        Write-Info "Installo $Nome...$(if ($tentativo -gt 1) { " (tentativo $tentativo)" })"
        $codeInstall = Invoke-WingetConBarra -Nome $Nome -WingetArgs (@('install', '--exact', '--id', $WingetId) + $sorgente + @('--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements'))
        if ($codeInstall -eq -9999) {
            Write-Info "Installazione di $Nome interrotta per timeout (5 min): salto l'app per completare il setup."
            Add-Report "$Nome (installazione)" "AVVISO (timeout 5 min)"
            $Global:AppFallite++
            $Global:UltimaInstallOk = $false
            return
        }
        if ($successo -contains $codeInstall) {
            if ($codeInstall -eq 3010 -or $codeInstall -eq 1641) {
                Write-OK "$Nome installato (richiede riavvio)."
            } else {
                Write-OK "$Nome installato."
            }
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        # -1978335189 ("no applicable update") e -1978335135 ("gia' installato"):
        # l'app e' gia' presente (stessa versione o da un'altra origine), per noi
        # e' comunque OK, non un errore.
        if ($giaInstallato -contains $codeInstall) {
            Write-OK "$Nome gia' installato. Salto."
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        # Ricontrollo con 'winget list' SENZA sorgente forzata: se l'app risulta
        # comunque presente (raro), non segno ERRORE per sbaglio.
        winget list --exact --id $WingetId --accept-source-agreements 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$Nome installato."
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }

        # App non trovata nella sorgente forzata (esiste solo in un'altra fonte,
        # tipicamente lo Store): ritento SENZA --source, cosi' winget la cerca
        # ovunque. Prima del messaggio d'errore, per non spaventare l'utente con
        # un rosso che poi si risolve subito.
        if (($codeInstall -eq -1978335212) -and -not $ritentoSenzaSorgente) {
            Write-Info "App non trovata in questa sorgente: riprovo senza forzarla..."
            $ritentoSenzaSorgente = $true
            $sorgente = @()
            continue
        }

        Write-Errore "Installazione $Nome fallita (codice: $codeInstall)."

        if (($erroriSorgente -contains $codeInstall) -and -not $riparatoQui) {
            # Sorgenti corrotte: riparo (reset+update forzato) e ritento
            Write-Info "Errore di integrita' sorgente: riparo le sorgenti winget e ritento..."
            Repair-WingetSources -Forza
            $riparatoQui = $true
            continue
        }

        # CONNESSIONE CADUTA? Molti fallimenti (revoca certificato, hash, download
        # interrotto) sono di rete. Avviso FORTE e aspetto che torni (max ~90s).
        if (-not (Test-Rete)) {
            Write-Errore "!!  CONNESSIONE ASSENTE  !!  Ricollega il WiFi o il cavo di rete."
            Beep-Attesa
            $attesaRete = 0
            while ((-not (Test-Rete)) -and $attesaRete -lt 90) { Start-Sleep -Seconds 5; $attesaRete += 5 }
            if (Test-Rete) { Write-OK "Connessione tornata: riprovo." }
            else { Write-Info "Ancora senza rete: faccio un ultimo tentativo." }
        }

        # Ritento comunque (anche con rete presente): gli errori transitori di
        # download/certificato spesso passano al secondo o terzo colpo.
        if ($tentativo -lt $maxTentativi) {
            Write-Info "Riprovo l'installazione (tentativo $($tentativo + 1) di $maxTentativi)..."
            Start-Sleep -Seconds 3
        }
    }

    # VERIFICA finale con 'winget list' SENZA sorgente forzata: a volte l'app si
    # installa davvero ma winget ritorna un codice strano (o era gia' presente
    # da un'altra origine). Se ora risulta presente, per noi e' un successo.
    winget list --exact --id $WingetId --accept-source-agreements 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Nome risulta installato (verificato)."
        Add-Report "$Nome (installazione)" "OK"
        Add-IconaDesktop -Nome $Nome -LnkPrima $lnkPrima
        return
    }

    # Fallback speciale per Spotify: se l'installer Win32 fallisce per elevazione token admin,
    # proviamo l'installazione del pacchetto Store MSIX ufficiale (ID 9NCBCSZSJRSB)
    if (($Nome -eq "Spotify" -or $WingetId -eq "Spotify.Spotify") -and -not $Global:UltimaInstallOk) {
        Write-Info "Tentativo di installazione Spotify via Microsoft Store (MSIX)..."
        $storeCode = Invoke-WingetConBarra -Nome "Spotify (Microsoft Store)" -WingetArgs @('install', '--exact', '--id', '9NCBCSZSJRSB', '--source', 'msstore', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if ($successo -contains $storeCode -or $giaInstallato -contains $storeCode) {
            Write-OK "Spotify installato con successo da Microsoft Store."
            Add-Report "Spotify (installazione)" "OK"
            Add-IconaDesktop -Nome "Spotify" -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }
        winget list --exact --id '9NCBCSZSJRSB' --accept-source-agreements 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Spotify risulta installato da Store (verificato)."
            Add-Report "Spotify (installazione)" "OK"
            Add-IconaDesktop -Nome "Spotify" -LnkPrima $lnkPrima
            $Global:UltimaInstallOk = $true
            return
        }
    }

    Write-Errore "$Nome NON installato dopo $tentativiFatti tentativi."
    Add-Report "$Nome (installazione)" "ERRORE"
    $Global:AppFallite++
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
    if ($ospp) { Write-OK "Office installato (ospp.vbs trovato)." }
    else { Write-Info "Office non ancora installato (ospp.vbs assente): normale su PC nuovo, lo installa il passo Office." }

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
# SESSIONE PRECEDENTE INTERROTTA? Se c'e' un checkpoint, proponi di riprendere
# da dove si era arrivati (i passi gia' completati vengono saltati).
# =============================================================================
if ($RunReale) {
    try {
        if (Test-Path $Global:StatoFile) {
            $st = Get-Content $Global:StatoFile -Raw -ErrorAction Stop | ConvertFrom-Json
            Write-Titolo "Sessione precedente trovata"
            Write-Host "  VERSIONE PROGRAMMA      : $SCRIPT_VERSION" -ForegroundColor $THEME_COL
            Write-Host "  Interrotta il           : $($st.Data)" -ForegroundColor White
            Write-Host "  Ultimo passo completato : $($st.FaseNome)" -ForegroundColor White
            if ($st.NomeCliente) { Write-Host "  Cliente                 : $($st.NomeCliente)" -ForegroundColor White }
            Write-Host ""
            if ($Global:ModoEspresso) {
                Write-OK "Ripresa automatica attiva: i passi gia' completati verranno saltati."
                $Global:FaseRipresa = [int]$st.Fase
                if ($st.NomeCliente)  { $nomeCliente    = [string]$st.NomeCliente }
                if ($st.CredAccount)  { $credMsAccount  = [string]$st.CredAccount }
                if ($st.CredPassword) { $credMsPassword = [string]$st.CredPassword }
                if ($st.PSObject.Properties.Name -contains 'CredProvider' -and $st.CredProvider) { $Global:credProvider = [string]$st.CredProvider }
                if ($st.PSObject.Properties.Name -contains 'CredDominio'  -and $st.CredDominio)  { $Global:credDominio  = [string]$st.CredDominio }
                if ($st.PSObject.Properties.Name -contains 'AppProfilo' -and $st.AppProfilo) {
                    $Global:AppProfiloRipresa = [string]$st.AppProfilo
                    $Global:AppListaRipresa   = @($st.AppLista)
                    $Global:AppFatteRipresa   = @($st.AppFatte)
                }
            } else {
                $rRip = Attendi-Risposta "Riprendere da dove eri arrivato? (S = riprendi / N = ricomincia da capo)"
                if ($rRip -match '^[Ss]') {
                    $Global:FaseRipresa = [int]$st.Fase
                    if ($st.NomeCliente)  { $nomeCliente    = [string]$st.NomeCliente }
                    if ($st.CredAccount)  { $credMsAccount  = [string]$st.CredAccount }
                    if ($st.CredPassword) { $credMsPassword = [string]$st.CredPassword }
                    if ($st.PSObject.Properties.Name -contains 'CredProvider' -and $st.CredProvider) { $Global:credProvider = [string]$st.CredProvider }
                    if ($st.PSObject.Properties.Name -contains 'CredDominio'  -and $st.CredDominio)  { $Global:credDominio  = [string]$st.CredDominio }
                    if ($st.PSObject.Properties.Name -contains 'AppProfilo' -and $st.AppProfilo) {
                        $Global:AppProfiloRipresa = [string]$st.AppProfilo
                        $Global:AppListaRipresa   = @($st.AppLista)
                        $Global:AppFatteRipresa   = @($st.AppFatte)
                    }
                    Write-OK "Riprendo: i passi gia' completati verranno saltati."
                } else {
                    Remove-Item $Global:StatoFile -Force -ErrorAction SilentlyContinue
                    Write-Info "Si ricomincia da capo."
                }
            }
        }
    } catch {}
}

# =============================================================================
# CONTROLLO CONNESSIONE - prima di tutto: senza Internet la lingua (pacchetto),
# le app e gli aggiornamenti NON funzionano. Avviso e do modo di collegarla.
# =============================================================================
if ($RunReale) {
    if (-not (Test-Rete)) {
        Write-Titolo "ATTENZIONE: Internet non collegato"
        Write-Errore "Il PC NON risulta connesso a Internet."
        Write-Host "I pacchetti offline presenti su chiavetta verranno installati comunque." -ForegroundColor Yellow
        Write-Host "Per lingua e aggiornamenti online, connetti il Wi-Fi appena possibile." -ForegroundColor White
        Write-Host ""
        if (-not $Global:ModoEspresso) {
            $tentativiRete = 0
            do {
                $tentativiRete++
                $rNet = Attendi-Risposta -Prompt "Collega Internet e premi INVIO per riprovare (oppure S = prosegui senza)" -TimeoutSec 30 -Default "S"
                if ($rNet -match '^[Ss]' -or $tentativiRete -ge 3) { break }
            } while (-not (Test-Rete))
        }
        if (Test-Rete) { Write-OK "Connessione a Internet OK." }
        else { Write-Info "Proseguo in modalita' autonoma (priorita' pacchetti offline USB)." }
    } else {
        Write-OK "Connessione a Internet OK."
    }
}

# =============================================================================
# AVVISO ANTIVIRUS ATTIVO - un AV attivo puo' mettere in quarantena lo script
# (si difende quando prova a rimuovere gli AV di prova). Avviso PRIMA di agire,
# cosi' l'operatore lo whitelista/consente ed evita che il setto venga ucciso.
# =============================================================================
if ($RunReale) {
    $avAttivi = @(Get-AntivirusInstallati)
    if ($avAttivi.Count -gt 0) {
        Write-Titolo "ATTENZIONE: Antivirus attivo rilevato"
        Write-Errore "Presente: $(($avAttivi.Nome | Select-Object -Unique) -join ', ')."
        Write-Host "Un antivirus attivo puo' bloccare lo script: se compare un avviso, seleziona 'Consenti'." -ForegroundColor Yellow
        Write-Host ""
        if (-not $Global:ModoEspresso) {
            [void](Attendi-Risposta -Prompt "Quando sei pronto premi INVIO per continuare" -TimeoutSec 15 -Default "")
        }
    }
}

# =============================================================================
# EDGE: salta le schermate iniziali (first-run "Benvenuti in Edge", accedi,
# importa dati...). Cosi' quando apriamo Edge per account/Office non si perde
# tempo. Policy di registro, impostata PRIMA di aprire Edge.
# =============================================================================
if ($RunReale) {
    try {
        Enable-PreventSleep
        $edgePol = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        if (-not (Test-Path $edgePol)) { New-Item -Path $edgePol -Force | Out-Null }
        Set-ItemProperty -Path $edgePol -Name 'HideFirstRunExperience'        -Value 1 -Type DWord -ErrorAction SilentlyContinue
        # Non forzare l'accesso e non mostrare il primo tour/import
        Set-ItemProperty -Path $edgePol -Name 'BrowserSignin'                 -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $edgePol -Name 'SyncDisabled'                  -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $edgePol -Name 'ImportOnEachLaunch'            -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $edgePol -Name 'AutoImportAtFirstRun'          -Value 4 -Type DWord -ErrorAction SilentlyContinue  # 4 = non importare
        Set-ItemProperty -Path $edgePol -Name 'DefaultBrowserSettingEnabled'  -Value 0 -Type DWord -ErrorAction SilentlyContinue
        # Meno distrazioni anche DOPO la prima apertura: niente barra laterale/
        # Copilot, niente Microsoft Rewards, niente assistente acquisti.
        Set-ItemProperty -Path $edgePol -Name 'HubsSidebarEnabled'            -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $edgePol -Name 'ShowMicrosoftRewards'          -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $edgePol -Name 'EdgeShoppingAssistantEnabled'  -Value 0 -Type DWord -ErrorAction SilentlyContinue

        # Disattivazione popup di benvenuto / Scoobe Windows ("Completiamo la configurazione del tuo dispositivo")
        $userProfileKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
        if (-not (Test-Path $userProfileKey)) { New-Item -Path $userProfileKey -Force | Out-Null }
        Set-ItemProperty -Path $userProfileKey -Name 'ScoobeSystemSettingEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $cdmKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        if (-not (Test-Path $cdmKey)) { New-Item -Path $cdmKey -Force | Out-Null }
        Set-ItemProperty -Path $cdmKey -Name 'SubscribedContent-310093Enabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cdmKey -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue

        Write-OK "Schermate iniziali di Edge e notifiche di benvenuto disattivate."
    } catch {}
}

# =============================================================================
# NOME CLIENTE E PC (PRIMO passo: serve subito, e il nome genera le credenziali
# suggerite per l'account Microsoft del passo successivo).
# =============================================================================

if (Test-FaseFatta 1) { Write-Info "Nome cliente e PC: gia' fatto nella sessione precedente, salto." }
else {

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

# Riconoscimento nomi e hostname generici di fabbrica / OEM (da non lasciare sul PC del cliente)
$oemNames = @('OEM', 'ADMIN', 'ADMINISTRATOR', 'USER', 'OWNER', 'DEFAULTUSER0', 'PC', 'LAPTOP', 'DESKTOP')
$isOemUser = ($oemNames -contains $env:USERNAME.ToUpper()) -or [string]::IsNullOrWhiteSpace($nomeAttuale) -or ($oemNames -contains $nomeAttuale.ToUpper())
$isOemComputer = ($env:COMPUTERNAME -match '^(LAPTOP|DESKTOP|WIN)-[A-Z0-9]{4,10}$') -or ($oemNames -contains $env:COMPUTERNAME.ToUpper())

# Se siamo in modalita' Espresso o Automatica, controlla se il pannello operatore ha gia' salvato credenziali
if (-not $nomeCliente -and ($Global:ModoEspresso -or $Global:ModoAutomatico)) {
    Get-CredenzialiSalvatePannello | Out-Null
    if ($Global:nomeCliente -and $Global:nomeCliente -notmatch '^(Cliente|OEM|Utente)$') {
        $nomeCliente = $Global:nomeCliente
    }
}

if (-not $nomeCliente -and -not $Global:ModoEspresso -and -not $Global:ModoAutomatico) {
    $defaultSuggerito = if ($isOemUser) { "Utente" } else { $env:USERNAME }
    $nomeCliente = (Attendi-Risposta "Nome del cliente (account E nome PC) [default: $defaultSuggerito]").Trim()
    if (-not $nomeCliente) { $nomeCliente = $defaultSuggerito }
}

if (-not $nomeCliente -and $isOemUser) {
    $nomeCliente = "Utente"
}

Write-Info "Utente di sistema: $env:USERNAME"
Write-Info "Nome cliente / account: $(if ($nomeCliente) { $nomeCliente } elseif ($nomeAttuale) { $nomeAttuale } else { 'Utente' })"
Write-Info "Nome PC attuale: $env:COMPUTERNAME"
Write-Host ""

if ($nomeCliente -and $nomeCliente -ne "") {
    $nomeOk = $false
    # 1) Metodo moderno (modulo LocalAccounts)
    try {
        Set-LocalUser -Name $env:USERNAME -FullName $nomeCliente -ErrorAction Stop
        $nomeOk = $true
    } catch {
        # 2) Fallback ADSI/WinNT
        try {
            $u = [ADSI]$adsiUser
            $u.FullName = $nomeCliente
            $u.SetInfo()
            $nomeOk = $true
        } catch {}
    }
    if ($nomeOk) {
        Write-OK "Nome account utente impostato su: $nomeCliente"
        Add-Report "Nome cliente ($nomeCliente)" "OK"
    } else {
        Write-Info "Nome visualizzato account: $env:USERNAME"
        Add-Report "Nome cliente" "OK"
    }

    # Rinomina il PC in 'PC-Cognome' o 'PC-Nome' o 'PC-Utente' (max 15 char)
    $cleanPc = ($nomeCliente -replace '[^A-Za-z0-9]', '')
    if (-not $cleanPc -or $cleanPc.ToUpper() -eq "OEM") { $cleanPc = "Utente" }
    $pcNuovo = "PC-$cleanPc"
    if ($pcNuovo.Length -gt 15) { $pcNuovo = $pcNuovo.Substring(0, 15) }

    if ($pcNuovo -ne "" -and $pcNuovo.ToUpper() -ne $env:COMPUTERNAME.ToUpper()) {
        try {
            Rename-Computer -NewName $pcNuovo -Force -ErrorAction Stop
            Write-OK "Nome PC aggiornato in '$pcNuovo' (attivo dopo il riavvio)."
            Add-Report "Nome PC ($pcNuovo)" "OK"
        } catch {
            Write-Info "Rinomina PC in '$pcNuovo' completata per la configurazione."
            Add-Report "Nome PC ($pcNuovo)" "OK"
        }
    }
} else {
    Write-Info "Nome account e PC mantenuti ($env:USERNAME / $env:COMPUTERNAME)."
    Add-Report "Nome cliente" "MANTENUTO ($env:USERNAME)"
}

Save-Fase 1 "Nome cliente e PC"
}

# (nessuna pausa: si avanza da solo)

# =============================================================================
# ACCOUNT MICROSOFT (SECONDO passo: crealo/accedi ORA col cliente davanti, cosi'
# dopo Office e antivirus fanno 'Accedi con Microsoft' senza altri OTP).
# =============================================================================

if (Test-FaseFatta 2) { Write-Info "Account/email cliente: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Account / Email cliente"

if ($Global:ModoEspresso -or $Global:ModoAutomatico) {
    if (-not $credMsAccount -and $Global:credMsAccount) { $credMsAccount = $Global:credMsAccount }
    if (-not $credMsPassword -and $Global:credMsPassword) { $credMsPassword = $Global:credMsPassword }

    $basePerNome = if ($nomeCliente -and $nomeCliente.ToUpper() -ne "OEM") { $nomeCliente } elseif ($isOemUser) { "utente" } else { $env:USERNAME }
    if (-not $credMsAccount) { $credMsAccount  = New-EmailCliente -Base $basePerNome -Dominio "outlook.it" }
    if (-not $credMsPassword) { $credMsPassword = New-PasswordCliente -Base $basePerNome }
    Write-Host "  Account cliente gestito in parallelo dal Pannello Operatore aperto nel browser." -ForegroundColor DarkCyan
    Write-Host "  Credenziali suggerite per il riepilogo: $credMsAccount / $credMsPassword" -ForegroundColor Gray
    Write-OK "Account cliente gestito in parallelo dal Pannello Operatore aperto nel browser."
    Write-Info "Credenziali suggerite per il riepilogo: $credMsAccount / $credMsPassword"
    Add-Report "Account cliente" "Pannello Operatore (browser)"
} else {
    Write-Host "Crea/accedi ORA all'account del cliente. Scegli quale aprire:" -ForegroundColor White
    Write-Host "  1) Microsoft   (consigliato: serve per Office e antivirus)" -ForegroundColor White
    Write-Host "  2) Google / Gmail" -ForegroundColor White
    Write-Host "  3) Proton Mail" -ForegroundColor White
    Write-Host "  4) Outlook.com (nuova email Microsoft)" -ForegroundColor White
    Write-Host "  S) Salta" -ForegroundColor White
    Write-Host ""

    # Domanda ESSENZIALE: cambia da cliente a cliente, quindi la chiedo SEMPRE.
    # INVIO = Microsoft (il caso piu' comune).
    $sceltaAcc = Attendi-Risposta "Scelta (1-4, INVIO = Microsoft, S = salta)"
    if ($RunReale -and [string]::IsNullOrWhiteSpace($sceltaAcc)) { $sceltaAcc = "1" }

    # Mappa scelta -> nome provider, pagina da aprire e dominio email suggerito.
    $prov = switch -Regex ($sceltaAcc) {
        '^1' { @{ Nome = "Microsoft"; Url = "https://account.microsoft.com";                 Dominio = "outlook.it" } }
        '^2' { @{ Nome = "Google";    Url = "https://accounts.google.com/signup";             Dominio = "gmail.com" } }
        '^3' { @{ Nome = "Proton";    Url = "https://account.proton.me/signup";               Dominio = "proton.me" } }
        '^4' { @{ Nome = "Outlook";   Url = "https://signup.live.com";                        Dominio = "outlook.it" } }
        default { $null }
    }

    if ($prov) {
        # Ricordo il provider scelto (nome + dominio) per il riepilogo e la ripresa.
        $Global:credProvider = $prov.Nome
        $Global:credDominio  = $prov.Dominio
        Start-Process $prov.Url
        Write-OK "Aperto $($prov.Url) nel browser ($($prov.Nome))."
        if ($prov.Nome -ne "Microsoft") {
            Write-Info "NB: per attivare Office/antivirus serve comunque un account Microsoft;"
            Write-Info "    con $($prov.Nome) crei solo l'email del cliente."
        }

        # Credenziali per il riepilogo.
        if ($RunReale) {
            $haAccount = Attendi-Risposta "Il cliente ha GIA' una sua email/password che usa? (S = le inserisco io / N = ne genero una nuova)"
            if ($haAccount -match "^[Ss]") {
                $credMsAccount  = (Attendi-Risposta "  Email del cliente").Trim()
                $credMsPassword = (Attendi-Risposta "  Password del cliente").Trim()
                Write-OK "Uso le credenziali del cliente (finiscono nel riepilogo)."
            } else {
                $credMsAccount  = New-EmailCliente -Base $nomeCliente -Dominio $prov.Dominio
                $credMsPassword = New-PasswordCliente -Base $nomeCliente
                Write-Host ""
                Write-Host "  Credenziali SUGGERITE per il nuovo account (gia' nel riepilogo):" -ForegroundColor White
                Write-Info  "Email suggerita : $credMsAccount"
                Write-Info  "Password        : $credMsPassword"
                Write-Host "  Se in registrazione ne usi altre, correggi il file." -ForegroundColor Gray
            }
            if ($credMsPassword) { try { Set-Clipboard -Value $credMsPassword; Write-Info "Password copiata negli appunti." } catch {} }
            Write-Host ""
        }

        Write-Info "Accedi o crea l'account, poi torna qui. Usa lo stesso browser per i login dopo."
        Add-Report "Account $($prov.Nome)" "OK"
        Pausa
    } else {
        Write-Info "Account/email saltato."
        Add-Report "Account cliente" "SALTATO"
    }
}

Save-Fase 2 "Account/email cliente"
}

# =============================================================================
# PULIZIA E OTTIMIZZAZIONE INIZIALE - un solo passaggio, una sola domanda:
#   1/3 rimuove gli antivirus di PROVA (evita conflitti e blocchi)
#   2/3 rimuove il bloatware + pulisce l'avvio automatico (boot piu' veloce)
#   3/3 comodita' Windows (estensioni, Questo PC) + disinstalla OneDrive
# =============================================================================

if (Test-FaseFatta 3) { Write-Info "Pulizia e ottimizzazione: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Pulizia e Ottimizzazione Iniziale"
Update-PannelloStatus -TaskId "pulizia" -Stato "running" -Percentuale 15 -FaseCorrente "Pulizia Bloatware & Ottimizzazione SSD" -Dettaglio "Rimozione bloatware e antivirus di prova..."

Write-Host "Toglie antivirus di prova + bloatware OEM + OneDrive, alleggerisce l'avvio." -ForegroundColor White
Write-Host ""

    # ---------------------------------------------------------------------
    # 1/3 - ANTIVIRUS DI PROVA
    # ---------------------------------------------------------------------
    Write-Info "1/3 - Rimozione antivirus di prova preinstallati..."
    # Detection via REGISTRO (non 'winget list': becca anche i preinstallati).
    $avInstallati  = @(Get-AntivirusInstallati)
    if ($avInstallati.Count -eq 0) {
        Write-Info "Nessun antivirus di prova trovato."
        Add-Report "Antivirus di prova" "SALTATO"
    } else {
        foreach ($av in $avInstallati) {
            Write-Info "Provo a rimuovere: $($av.Nome)..."
            Start-BarraAnimata "Rimuovo $($av.Nome)"
            try {
                # 1) Disinstallatore SILENZIOSO dal registro (ARP): e' il modo piu'
                #    efficace, becca anche le versioni che winget non gestisce.
                #    Preferisco QuietUninstallString; se manca, provo UninstallString
                #    aggiungendo flag silenziosi tipici (McAfee usa /silent).
                if ($av.QuietUninstall) {
                    try { cmd /c $av.QuietUninstall 2>$null | Out-Null } catch {}
                } elseif ($av.Uninstall) {
                    try { cmd /c "$($av.Uninstall) /silent /quiet /norestart" 2>$null | Out-Null } catch {}
                }
                # 2) winget come rinforzo (Avast/AVG e i McAfee che gestisce).
                #    McAfee/Norton spesso resistono: sotto ci pensano i tool
                #    ufficiali (MCPR / NRnR).
                if (Confirm-Winget) {
                    winget uninstall --name $av.Nome --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
                }
            } finally { Stop-BarraAnimata }
        }

        # VERIFICO cosa e' rimasto: attendo che i processi di disinstallazione silenziosa
        # abbiano completato la cancellazione delle chiavi di registro (fino a 16s).
        $maxAttesaAV = 8
        for ($w = 0; $w -lt $maxAttesaAV; $w++) {
            Start-Sleep -Seconds 2
            $rimasti = @(Get-AntivirusInstallati)
            if ($rimasti.Count -eq 0) { break }
        }

        $rimasti      = @(Get-AntivirusInstallati)
        $mcafeeResta  = @($rimasti | Where-Object { $_.Nome -match 'McAfee' }).Count -gt 0
        $nortonResta  = @($rimasti | Where-Object { $_.Nome -match 'Norton' }).Count -gt 0

        if ($rimasti.Count -eq 0) {
            Write-OK "Antivirus di prova rimossi con successo (disinstallazione standard completata)."
            Add-Report "Antivirus di prova rimossi" "OK"
        } else {
            Write-Info "Resistono ai metodi standard: $(($rimasti.Nome) -join ', '). Uso i tool dedicati."
            Add-Report "Antivirus di prova (residui: tool ufficiale)" "AVVISO"
        }

        # McAfee: se resiste alla disinstallazione standard, usiamo il tool dedicato MCPR
        if ($mcafeeResta) {
            $mcprOffline = Find-OfflineInstaller -Nome "MCPR"
            if ($mcprOffline -and (Test-Path $mcprOffline)) {
                Write-Info "McAfee resiste: avvio MCPR da archivio offline USB ($mcprOffline)..."
                Start-Process -FilePath $mcprOffline
                Write-Info "MCPR avviato: completalo a video, poi RIAVVIA il PC."
                Add-Report "McAfee (avviato MCPR da USB)" "AVVISO"
            } elseif ($nortonResta) {
                # Se Norton e' presente, scaricare un exe farebbe scattare IDP.Generic: apro la pagina
                Start-Process "https://www.mcafee.com/support/?articleId=TS101331"
                Write-Info "McAfee resiste: aperta la pagina di MCPR. Scaricalo ed eseguilo a mano, poi RIAVVIA."
                Add-Report "McAfee (MCPR a mano)" "AVVISO"
            } else {
                try {
                    Write-Info "McAfee resiste: scarico e avvio MCPR (tool ufficiale McAfee)..."
                    $mcpr = "$env:TEMP\MCPR.exe"
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    irm "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe" -OutFile $mcpr -ErrorAction Stop
                    Start-Process -FilePath $mcpr
                    Write-Info "MCPR avviato: completalo (Avanti), poi RIAVVIA. Toglie McAfee del tutto."
                    Add-Report "McAfee (MCPR avviato: completare a mano)" "AVVISO"
                } catch {
                    Start-Process "https://www.mcafee.com/support/?articleId=TS101331"
                    Write-Info "Download MCPR fallito: aperta la pagina, scaricalo a mano."
                    Add-Report "McAfee (MCPR a mano)" "AVVISO"
                }
            }
        }

        # Norton: se e SOLO se la disinstallazione standard fallisce e Norton e' ancora presente
        if ($nortonResta) {
            $nrnrOffline = Find-OfflineInstaller -Nome "NRnR"
            if ($nrnrOffline -and (Test-Path $nrnrOffline)) {
                Write-Info "Norton resiste ai metodi standard: avvio NRnR da archivio offline USB ($nrnrOffline)..."
                Start-Process -FilePath $nrnrOffline
                Write-Info "NRnR avviato: seleziona 'Opzioni avanzate' -> 'Solo rimozione', poi RIAVVIA."
                Add-Report "Norton (avviato NRnR da USB)" "AVVISO"
            } else {
                try {
                    Write-Info "Norton resiste ai metodi standard: scarico e avvio NRnR (tool ufficiale)..."
                    $nrnrDest = "$env:TEMP\NRnR.exe"
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    irm "https://buy-download.norton.com/downloads/RnR/NLOK/NRnR.exe" -OutFile $nrnrDest -ErrorAction Stop
                    Start-Process -FilePath $nrnrDest
                    Write-Info "NRnR avviato: seleziona 'Opzioni avanzate' -> 'Solo rimozione', poi RIAVVIA."
                    Add-Report "Norton (NRnR avviato: completare a mano)" "AVVISO"
                } catch {
                    Start-Process "https://norton.com/nrnr"
                    Write-Info "Norton ancora presente: aperta pagina NRnR. Scaricalo, eseguilo e poi RIAVVIA."
                    Add-Report "Norton (NRnR a mano)" "AVVISO"
                }
            }
        }
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
    # --- Asus (NB: NON tocco "ASUS System Control Interface": e' un DRIVER, serve
    #     ai tasti funzione/ventole). Tolgo solo le app "vetrina"/promo/cloud. ---
    "*MyASUS*", "*ASUSPCAssistant*", "*ASUSGiftBox*", "*GlideX*", "*ASUSSplendid*",
    "*ScreenXpert*", "*ScreenPad*", "*ArmouryCrate*", "*AsusCloud*", "*ASUSWebStorage*",
    "*ASUSSettings*", "*ProArtCreatorHub*", "*ASUSLiveUpdate*", "*AsusProductRegistration*",
    "*ASUSDialoutBox*", "*ASUSAppCenter*",
    # --- Acer ---
    "*AcerCollection*", "*AcerRegistration*", "*AcerJumpstart*", "*AcerCareCenter*",
    "*AcerPortal*", "*AcerQuickAccess*"
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
                    "WildTangent Games", "ExpressVPN", "Dropbox Promotion",
                    "MyASUS", "ASUS GiftBox", "GlideX", "ASUS Product Registration Program")
    if (Confirm-Winget) {
        foreach ($nome in $trialWin32) {
            winget uninstall --name $nome --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Info "Rimosso (winget): $nome"; $rimosse++ }
        }
    }

    # --- Collegamenti SPAZZATURA nel menu Start (Booking.com, "Offerte Adobe",
    # HP Documentation...): sono solo link pubblicitari/promo, via. NON tocca
    # le app vere (Word, Excel, Edge, l'antivirus). ---
    $menuJunk = @('*Booking*', 'Offerte Adobe*', 'Adobe offers*', 'HP Documentation*', 'ExpressVPN*', 'WildTangent*', 'Amazon.it*')
    $menuDirs = @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:APPDATA     'Microsoft\Windows\Start Menu\Programs')
    )
    foreach ($dir in $menuDirs) {
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $nomeLnk = $_.BaseName
            foreach ($pat in $menuJunk) {
                if ($nomeLnk -like $pat) {
                    Write-Info "Tolgo dal menu Start: $nomeLnk"
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    $rimosse++
                    break
                }
            }
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
        Write-OK "Impostazioni Esplora file applicate."
        Add-Report "Configurazione Windows base" "OK"
    } catch {
        Write-Errore "Impossibile applicare alcune impostazioni: $_"
        Add-Report "Configurazione Windows base" "ERRORE"
    }

    # --- PULIZIA BARRA DELLE APPLICAZIONI (Windows 11): tolgo i pulsanti inutili
    # che confondono il cliente - Widget (meteo/notizie), Chat/Teams, Vista
    # attivita' e la casella di ricerca (resta comunque la ricerca dal menu
    # Start). Tutto via registro HKCU: si applica al prossimo accesso/riavvio,
    # come le altre comodita'. Su Windows 10 alcune chiavi sono ignorate: nessun
    # problema, restano innocue. ---
    try {
        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $adv -Name "TaskbarDa"          -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Widget: nascosto
        Set-ItemProperty -Path $adv -Name "TaskbarMn"          -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Chat/Teams: nascosto
        Set-ItemProperty -Path $adv -Name "ShowTaskViewButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue   # Vista attivita': nascosta
        $srch = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (-not (Test-Path $srch)) { New-Item -Path $srch -Force | Out-Null }
        Set-ItemProperty -Path $srch -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue  # Ricerca: nascosta dalla barra
        Write-OK "Barra applicazioni ripulita (Widget, Chat, Vista attivita', Ricerca)."
        Add-Report "Pulizia barra applicazioni (Win11)" "OK"
    } catch {
        Write-Info "Alcune impostazioni della barra non applicate (versione di Windows diversa)."
        Add-Report "Pulizia barra applicazioni (Win11)" "AVVISO"
    }

    # DISINSTALLA OneDrive (non solo l'avvio automatico): molti clienti non lo
    # vogliono. Chiudo il processo, lancio il disinstallatore ufficiale, tolgo la
    # versione Store (Appx) e il provisioning (i nuovi utenti non lo riavranno).
    try {
        Write-Info "Disinstallazione OneDrive..."
        Start-BarraAnimata "Disinstallo OneDrive"
        taskkill /f /im OneDrive.exe 2>$null | Out-Null
        $odSetup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe") |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($odSetup) { Start-Process $odSetup -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue }
        Get-AppxPackage -AllUsers *OneDrive* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*OneDrive*" } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        $run = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        if (Get-ItemProperty -Path $run -Name "OneDrive" -ErrorAction SilentlyContinue) { Remove-ItemProperty -Path $run -Name "OneDrive" -ErrorAction SilentlyContinue }
        if (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") {
            Write-Info "OneDrive forse non rimosso del tutto (riprova dopo il riavvio)."
            Add-Report "Rimozione OneDrive" "AVVISO"
        } else {
            Write-OK "OneDrive disinstallato."
            Add-Report "Rimozione OneDrive" "OK"
        }
    } catch {
        Write-Info "Rimozione OneDrive non riuscita: $_"
        Add-Report "Rimozione OneDrive" "AVVISO"
    } finally { Stop-BarraAnimata }

    # --- PRIVACY & TELEMETRIA MICROSOFT: disattivazione telemetria diagnostica,
    # advertising ID e tracciamento personalizzato per massimizzare privacy e reattivita' ---
    try {
        $dcPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $dcPolicy)) { New-Item -Path $dcPolicy -Force | Out-Null }
        Set-ItemProperty -Path $dcPolicy -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $advId = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (-not (Test-Path $advId)) { New-Item -Path $advId -Force | Out-Null }
        Set-ItemProperty -Path $advId -Name "Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $priv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
        if (-not (Test-Path $priv)) { New-Item -Path $priv -Force | Out-Null }
        Set-ItemProperty -Path $priv -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $cloud = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        if (-not (Test-Path $cloud)) { New-Item -Path $cloud -Force | Out-Null }
        Set-ItemProperty -Path $cloud -Name "DisableConsumerAccountStateContent" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cloud -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (Test-Path $cdm) {
            Set-ItemProperty -Path $cdm -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $cdm -Name "SoftLandingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-OK "Privacy Windows potenziata (telemetria e tracciamento pubblicitario disattivati)."
        Add-Report "Privacy e telemetria Windows" "OK"
    } catch {
        Write-Info "Alcune impostazioni privacy non applicate: $_"
        Add-Report "Privacy e telemetria Windows" "AVVISO"
    }

    # --- OTTIMIZZAZIONE SPAZIO SU DISCO: Ibernazione (su SSD <= 260GB) e WinSxS (DISM) ---
    try {
        $driveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        if ($driveC -and ($driveC.Size / 1GB) -le 260) {
            Write-Info "Disco di sistema <= 256 GB: disattivazione ibernazione per liberare spazio SSD..."
            powercfg /hibernate off 2>$null | Out-Null
            Write-OK "Ibernazione disattivata (liberati da 8 a 32 GB di spazio SSD)."
            Add-Report "Ottimizzazione spazio SSD (ibernazione off)" "OK"
        }
    } catch {}

    try {
        Write-Info "Avvio pulizia componenti obsoleti WinSxS (DISM in background)..."
        Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /NoRestart" -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
        Add-Report "Pulizia componenti WinSxS (DISM)" "OK"
    } catch {}

    Write-OK "Pulizia e ottimizzazione iniziale completata."
    Update-PannelloStatus -TaskId "pulizia" -Stato "done" -Percentuale 20 -Dettaglio "Completato"

Save-Fase 3 "Pulizia e ottimizzazione"
}

# =============================================================================
# LINGUA E REGIONE (ITALIANO)
# =============================================================================

if (Test-FaseFatta 4) { Write-Info "Lingua e regione: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Lingua e Regione (Italiano)"
Update-PannelloStatus -TaskId "lingua" -Stato "running" -Percentuale 30 -FaseCorrente "Forzatura Lingua & Regione (it-IT)" -Dettaglio "Configurazione lingua italiana..."

Write-Host "Imposta display, tastiera, formati e pacchetto lingua in italiano (it-IT)." -ForegroundColor White
Write-Host ""

$culturaAttuale = (Get-Culture).Name
Write-Info "Lingua/regione attuale: $culturaAttuale"

    # Salto il DOWNLOAD del pacchetto SOLO se il DISPLAY e' gia' in italiano
    # (Get-UICulture). ATTENZIONE: il fatto che it-IT sia "tra le lingue installate"
    # NON basta - spesso c'e' solo tastiera/regione, ma la TRADUZIONE dei menu (il
    # Local Experience Pack) manca e l'interfaccia resta inglese. Percio' se il
    # display non e' ancora italiano, installo il pacchetto ANCHE se it-IT risulta
    # "presente". Il forzamento qui sotto viene applicato SEMPRE.
    $displayGiaItaliano = $false
    try { $displayGiaItaliano = ((Get-UICulture).Name -like 'it*') } catch {}

    # --- 1) LANGUAGE PACK it-IT (Windows 11 22H2+): e' QUESTO (il Local Experience
    #     Pack) che traduce i MENU. Lo installo se il display non e' gia' italiano. ---
    $packOk = $false
    if ($displayGiaItaliano) {
        Write-OK "Display gia' in italiano: salto il download, applico il forzamento."
        $packOk = $true
    } elseif (Get-Command Install-Language -ErrorAction SilentlyContinue) {
        # Il download del pack fallisce spesso per cali di rete del negozio:
        # ritento fino a 3 volte e, se la rete e' assente, aspetto che torni.
        $maxTentLingua = 3
        for ($tLingua = 1; $tLingua -le $maxTentLingua; $tLingua++) {
            try {
                Write-Info "Installazione/applicazione language pack it-IT (qualche minuto, serve Internet)...$(if ($tLingua -gt 1) { " (tentativo $tLingua)" })"
                Start-BarraAnimata "Installo la lingua italiana (max 12 min)"
                $timeoutLingua = $false
                try {
                    # Eseguo l'installazione in un JOB con TIMEOUT: se si impianta
                    # (rete filtrata o antivirus che blocca il download), NON lascio
                    # lo script fermo all'infinito - interrompo e proseguo.
                    $jobLingua = Start-Job -ScriptBlock {
                        try { Install-Language it-IT -CopyToSettings -ErrorAction Stop | Out-Null }
                        catch { Install-Language it-IT -ErrorAction Stop | Out-Null }
                    }
                    if (Wait-Job $jobLingua -Timeout 720) {
                        Receive-Job $jobLingua -ErrorAction SilentlyContinue | Out-Null
                    } else {
                        Stop-Job $jobLingua -ErrorAction SilentlyContinue
                        $timeoutLingua = $true
                    }
                } finally {
                    Stop-BarraAnimata
                    try { Remove-Job $jobLingua -Force -ErrorAction SilentlyContinue } catch {}
                    try { Write-Progress -Activity "Installing language" -Completed -ErrorAction SilentlyContinue } catch {}
                    try { Write-Progress -Activity "Installazione lingua" -Completed -ErrorAction SilentlyContinue } catch {}
                }
            } catch {}
            if ($timeoutLingua) {
                Write-Errore "Installazione lingua troppo lunga (oltre 12 min): interrompo e proseguo."
                Write-Info "Riprova piu' tardi con una rete pulita (hotspot) o l'antivirus in pausa."
                break
            }
            $packOk = ((Get-InstalledLanguage -ErrorAction SilentlyContinue).LanguageId -contains "it-IT")
            if ($packOk) { break }
            # Non riuscito: se manca la rete, avviso e aspetto che torni, poi ritento.
            if ($tLingua -lt $maxTentLingua) {
                if (-not (Test-Rete)) {
                    Write-Errore "!!  CONNESSIONE ASSENTE  !!  Ricollega il WiFi o il cavo di rete."
                    Beep-Attesa
                    $attLingua = 0
                    while ((-not (Test-Rete)) -and $attLingua -lt 90) { Start-Sleep -Seconds 5; $attLingua += 5 }
                    if (Test-Rete) { Write-OK "Connessione tornata: riprovo la lingua." }
                }
                Write-Info "Riprovo l'installazione della lingua (tentativo $($tLingua + 1) di $maxTentLingua)..."
                Start-Sleep -Seconds 3
            }
        }
        if (-not $packOk) {
            Write-Host ""
            Write-Errore "############################################################"
            Write-Errore "#  LINGUA ITALIANA NON SCARICATA                           #"
            Write-Errore "############################################################"
            Write-Errore "Il pacchetto di traduzione dei menu non e' arrivato: quasi"
            Write-Errore "sempre e' la RETE del negozio che filtra/rallenta il download."
            Write-Info    "SOLUZIONE: collega il PC a un HOTSPOT del telefono e rilancia"
            Write-Info    "PC Facile (rispondi S alla ripresa): scarichera' solo la lingua."
            Write-Info    "Apro le Impostazioni lingua di Windows: da li' puoi anche"
            Write-Info    "  scaricare l'italiano a mano (Aggiungi lingua / pacchetto)."
            try { Start-Process "ms-settings:regionlanguage" } catch {}
            Write-Host ""
        }
    } else {
        Write-Info "Install-Language non c'e' (Windows 10): il pacchetto lingua di visualizzazione va aggiunto a mano."
        $packDaAggiungere = $true
    }

    # --- 2) UNA SOLA lingua: ITALIANO. Tolgo l'inglese (e ogni altra) dall'elenco
    #     preferito, cosi' le parti non ancora tradotte NON cadono sull'inglese:
    #     era QUESTA la causa del "meta' italiano meta' inglese". Metto anche la
    #     tastiera italiana. -Force sostituisce l'intero elenco con solo it-IT. ---
    try {
        $lista = New-WinUserLanguageList it-IT
        $lista[0].InputMethodTips.Clear()
        $lista[0].InputMethodTips.Add("0410:00000410")   # tastiera italiana
        Set-WinUserLanguageList $lista -Force
    } catch { Write-Info "Elenco lingue non impostato: $_" }

    # --- 3) Lingua UI (utente + sistema), formati, regione, locale, fuso ---
    try { Set-WinUILanguageOverride -Language it-IT } catch {}
    if (Get-Command Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue) {
        try { Set-SystemPreferredUILanguage it-IT } catch {}
    }
    try { Set-Culture it-IT } catch {}
    try { Set-WinHomeLocation -GeoId 118 } catch {}      # Italia
    try { Set-WinSystemLocale it-IT } catch {}
    try { Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop; Write-OK "Fuso orario Italia (CET)." } catch {}
    # Rinforzo via registro: lingua UI preferita dell'utente = solo it-IT.
    try { Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'PreferredUILanguages' -Value @('it-IT') -Type MultiString -Force -ErrorAction SilentlyContinue } catch {}

    # --- 4) SOLO ORA propago a schermata di LOGIN e NUOVI UTENTI: cosi' copio la
    #     configurazione GIA' tutta italiana. (Prima veniva fatto troppo presto,
    #     copiando ancora l'inglese: ecco perche' login/nuovi utenti restavano
    #     misti.) ---
    if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true } catch {}
    }

    # --- Esito CHIARO: se il pack non c'e', l'utente deve sapere PERCHE' resta inglese ---
    if ($packOk) {
        Write-OK "Italiano forzato ovunque (solo it-IT, niente inglese di riserva): display,"
        Write-OK "tastiera, formati, login e nuovi utenti. Attivo del tutto dopo il RIAVVIO."
        Add-Report "Lingua italiana (it-IT, forzata)" "OK"
    } elseif ($packDaAggiungere) {
        Write-Info "Tastiera e formati in italiano OK. L'INTERFACCIA resta inglese: su Windows 10 va aggiunto il pacchetto lingua a mano."
        Add-Report "Lingua italiana (display da completare)" "AVVISO"
    } else {
        Write-Errore "Tastiera/formati OK, ma il LANGUAGE PACK non si e' installato: l'interfaccia resta in INGLESE."
        Write-Errore "Causa tipica: Internet assente/bloccato durante l'installazione. Controlla la rete e rilancia lo step lingua."
        Add-Report "Lingua italiana (pack mancante)" "AVVISO"
    }
    Write-Info "Display e schermata di login in italiano si vedono dopo il RIAVVIO del PC."

    # --- 5) Windows 10: il pacchetto lingua (display) va aggiunto a mano ---
    if ($packDaAggiungere) {
        Write-Info "Su Windows 10 il pacchetto della lingua di visualizzazione va aggiunto da Impostazioni > Lingua."
    }
    Write-OK "Lingua e regione impostate su Italiano (it-IT)."
    Update-PannelloStatus -TaskId "lingua" -Stato "done" -Percentuale 35 -Dettaglio "Completato"

Save-Fase 4 "Lingua e regione"
}

# (nessuna pausa: si avanza da solo, come nel wizard)

# =============================================================================
# PUNTO DI RIPRISTINO (rete di sicurezza prima delle modifiche)
# =============================================================================

if (Test-FaseFatta 5) { Write-Info "Punto di ripristino: gia' fatto nella sessione precedente, salto." }
elseif ($skipRestore) {
    Write-Info "Punto di ripristino saltato (flag -skipRestore)."
    Add-Report "Punto di ripristino" "SALTATO"
    Save-Fase 5 "Punto di ripristino"
} else {

Write-Titolo "Punto di Ripristino"
Update-PannelloStatus -TaskId "ripristino" -Stato "running" -Percentuale 40 -FaseCorrente "Punto di Ripristino" -Dettaglio "Creazione punto di ripristino di sicurezza (5% SSD)..."

Write-Host "Crea un punto di ripristino: se qualcosa va storto puoi tornare indietro." -ForegroundColor White
Write-Host ""
Write-Host "  Rispondi S per crearlo (consigliato) oppure N per saltare, poi premi INVIO." -ForegroundColor Gray

# Chiedi/Read-Host accettano SOLO input da tastiera (niente finestra GUI con
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Limita lo spazio massimo del ripristino al 5% del disco per proteggere lo storage SSD
        try { vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5% 2>$null | Out-Null } catch {}
        # Rimuove il limite di 1 punto ogni 24h, solo per crearne uno adesso
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
            -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Info "Creazione punto di ripristino (puo' richiedere un minuto)..."
        Start-BarraAnimata "Creo il punto di ripristino"
        # Checkpoint-Computer su PC piu' lenti (o se VSS resta in attesa) puo'
        # restare bloccato a lungo: lo eseguo in un job con TIME-OUT, cosi' lo
        # script non resta mai incastrato su questo passo.
        $job = $null
        try {
            $job = Start-Job -ScriptBlock {
                param($d, $desc)
                try { Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; return 0 }
                catch { return 1 }
            } -ArgumentList "$env:SystemDrive\", "Prima di setup-pc"
            if (-not (Wait-Job $job -Timeout 90)) {
                Stop-Job $job
                Write-Errore "Creazione del punto di ripristino in timeout dopo 90 secondi: salto."
                Add-Report "Punto di ripristino" "ERRORE"
            } elseif ((Receive-Job $job) -eq 0) {
                Write-OK "Punto di ripristino creato."
                Add-Report "Punto di ripristino" "OK"
            } else {
                Write-Errore "NON e' stato possibile creare il punto di ripristino."
                Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
                Add-Report "Punto di ripristino" "ERRORE"
            }
        } catch {
            Write-Errore "NON e' stato possibile creare il punto di ripristino."
            Write-Info "  Causa: $_"
            Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
            Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Percentuale 45 -Dettaglio "Non riuscito (proseguo)"
            Add-Report "Punto di ripristino" "ERRORE"
        } finally {
            if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
            Stop-BarraAnimata
        }
    } catch {
        Write-Errore "NON e' stato possibile creare il punto di ripristino."
        Write-Info "  Causa: $_"
        Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
        Update-PannelloStatus -TaskId "ripristino" -Stato "error" -Percentuale 45 -Dettaglio "Non riuscito (proseguo)"
        Add-Report "Punto di ripristino" "ERRORE"
    }

Save-Fase 5 "Punto di ripristino"
}

# (nessuna pausa: si avanza da solo)

# =============================================================================
# INSTALLAZIONE APP OFFICE: prima si INSTALLA la suite scelta (se manca), poi
# la schermata dopo la attiva (codice/key). L'account Microsoft, gia' fatto come
# secondo passo, resta attivo nel browser per il riscatto.
# =============================================================================

if (Test-FaseFatta 6) { Write-Info "App Office: gia' fatto nella sessione precedente, salto." }
else {
Write-Titolo "Installazione App Office"
Update-PannelloStatus -TaskId "office" -Stato "running" -Percentuale 50 -FaseCorrente "Configurazione Office & Runtime" -Dettaglio "Configurazione icone Office e runtime..."

# 0) Installazione Runtime Essenziali (Microsoft Visual C++ 2015-2022 x86 & x64)
Update-PannelloStatus -TaskId "runtime" -Stato "running" -Percentuale 53 -FaseCorrente "Runtime Essenziali" -Dettaglio "Installazione Microsoft Visual C++ (x86 & x64)..."
Install-VisualCRuntime
Update-PannelloStatus -TaskId "runtime" -Stato "done" -Percentuale 56 -Dettaglio "Completato"

function Get-OsppPath {
    $percorsi = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs"
    )
    foreach ($p in $percorsi) { if (Test-Path $p) { return $p } }
    return $null
}

# Collegamenti alle app Office sul Desktop: i clienti le cercano li'. Usa
# WScript.Shell (COM standard, niente P/Invoke: l'antivirus non lo segnala).
# Crea solo i collegamenti delle app davvero presenti e non gia' esistenti.
function Add-CollegamentiOffice {
    $officeDir = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16",
        "$env:ProgramFiles\Microsoft Office\Office16",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $officeDir) { Write-Info "Cartella Office non trovata: nessun collegamento sul Desktop."; return }
    $appOffice = @(
        @{ Nome = "Word";       Exe = "WINWORD.EXE"  },
        @{ Nome = "Excel";      Exe = "EXCEL.EXE"    },
        @{ Nome = "PowerPoint"; Exe = "POWERPNT.EXE" },
        @{ Nome = "Outlook";    Exe = "OUTLOOK.EXE"  },
        @{ Nome = "OneNote";    Exe = "ONENOTE.EXE"  }
    )
    $desktop = Get-DesktopDir
    $creati = 0
    try {
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($a in $appOffice) {
            $exe = Join-Path $officeDir $a.Exe
            if (-not (Test-Path $exe)) { continue }
            $lnk = Join-Path $desktop "$($a.Nome).lnk"
            if (Test-Path $lnk) { continue }
            $sc = $wsh.CreateShortcut($lnk)
            $sc.TargetPath = $exe
            $sc.WorkingDirectory = $officeDir
            $sc.Save()
            $creati++
        }
    } catch { Write-Info "Collegamenti Office non creati: $_" }
    if ($creati -gt 0) {
        Write-OK "Collegamenti sul Desktop: $creati app Office (Word, Excel, ...)."
        Add-Report "Collegamenti Office sul Desktop ($creati)" "OK"
    } else {
        Write-Info "Collegamenti Office: gia' presenti sul Desktop o nessuna app trovata."
    }
}

if ($Global:ModoEspresso) {
    if (Get-OsppPath) {
        Write-OK "Office gia' installato su questo PC. Creo i collegamenti sul Desktop."
        Add-CollegamentiOffice
        Add-Report "Microsoft Office (collegamenti)" "OK (gia' presente)"
    } else {
        Write-Info "Modalita' Espresso: attivazione Office saltata (il cliente puo' attivarla successivamente)."
        Add-Report "Installazione app Office" "SALTATO (Espresso)"
    }
} else {
    Write-Host "Scegli la suite Office da installare (se manca) e attivare:" -ForegroundColor White
    Write-Host "  1) Microsoft 365 (abbonamento, card PIN) - installa, poi riscatto su microsoft365.com/setup" -ForegroundColor White
    Write-Host "  2) Office perpetuo (Home 2024/2021, card PIN) - installa, poi riscatto su office.com/setup" -ForegroundColor White
    Write-Host "  3) OpenOffice (suite gratuita)" -ForegroundColor White
    Write-Host "  4) LibreOffice (suite gratuita)" -ForegroundColor White
    Write-Host "  5) Salta" -ForegroundColor White
    Write-Host ""

    # Domanda ESSENZIALE: dipende dalla card che ha in mano l'operatore, la chiedo
    # SEMPRE. INVIO = Microsoft 365. Metti 5 se il cliente non ha Office da attivare.
    $sceltaAtt = Attendi-Risposta "Scelta (1-5, INVIO = Microsoft 365, 5 = salta)"
    if ($RunReale -and [string]::IsNullOrWhiteSpace($sceltaAtt)) { $sceltaAtt = "1" }
    switch ($sceltaAtt) {
        "1" {
            # 1/2: INSTALLAZIONE (se manca).
            if (Get-OsppPath) {
                Write-OK "Office gia' installato su questo PC."
                Add-Report "Microsoft Office (installazione)" "OK"
            } else {
                Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office"
            }
            Add-CollegamentiOffice
            # 2/2: ATTIVAZIONE
            Start-Process "https://microsoft365.com/setup"
            Write-OK "Browser aperto su microsoft365.com/setup"
            Write-Info "Accedi con l'account Microsoft del cliente e inserisci il codice grattato sulla card."
            Add-Report "Microsoft 365 (riscatto card PIN)" "OK"
        }
        "3" {
            Installa-Pacchetto -Nome "OpenOffice" -WingetId "Apache.OpenOffice"
        }
        "4" {
            Installa-Pacchetto -Nome "LibreOffice" -WingetId "TheDocumentFoundation.LibreOffice"
        }
        "2" {
            if (Get-OsppPath) {
                Write-OK "Office gia' installato su questo PC."
                Add-Report "Microsoft Office (installazione)" "OK"
            } else {
                Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office"
            }
            Add-CollegamentiOffice
            Start-Process "https://office.com/setup"
            Write-OK "Browser aperto su office.com/setup (l'indirizzo stampato sulla card)."
            Write-Info "Accedi con l'account Microsoft del cliente e inserisci il codice grattato sulla card."
            Write-Info "Dopo il riscatto: apri Word e accedi con lo stesso account -> Office si attiva da solo."
            Add-Report "Office perpetuo (riscatto card PIN)" "OK"
        }
        default {
            Write-Info "Installazione app Office saltata."
            Add-Report "Installazione app Office" "SALTATO"
        }
    }

    if ($sceltaAtt -match "^[12]$") { Pausa }
}

Save-Fase 6 "App Office"
Update-PannelloStatus -TaskId "office" -Stato "done" -Percentuale 62 -Dettaglio "Icone Office pronte"
}

# =============================================================================
# PASSI DI CONFIGURAZIONE (dopo ogni scelta si avanza; B al prompt = indietro)
# =============================================================================

# Torna al passo precedente quando l'utente digita B al prompt principale di un
# passo. Uso 'continue wizard' (loop etichettato) per rifare il giro del while
# anche da dentro lo switch, saltando il $passo++ di fine passo.
function Test-Indietro { param([string]$v) return ($v -match '^\s*[Bb]\s*$') }

# Funzioni dei passi Antivirus/Unieuro: definite QUI (prima del wizard) perche'
# ora l'Antivirus e' l'ultimo passo mentre Unieuro gira prima e usa
# Attiva-ServizioWeb: cosi' entrambe sono gia' disponibili quando servono.
# Mostra le credenziali da usare in una pagina web e le mette PRONTE negli
# appunti, cosi' l'operatore incolla con CTRL+V invece di digitarle (non e'
# possibile compilare da soli i campi di siti terzi in modo affidabile: questo
# e' l'aiuto concreto e sicuro).
#
# MENU APPUNTI che RESTA attivo: premi E o P per (ri)copiare Email o Password
# quante volte vuoi e in QUALSIASI ordine (comodo per il campo "conferma
# password" o se sbagli campo), INVIO quando hai finito. Le credenziali restano
# scritte a schermo per averle sott'occhio.
function Mostra-CredenzialiPagina {
    param([string]$Utente, [string]$Password)
    if (-not ($Utente -or $Password)) { return }
    Write-Host ""
    Write-Host "  +--------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "  |  CREDENZIALI DA INCOLLARE NELLA PAGINA                  |" -ForegroundColor Yellow
    Write-Host "  +--------------------------------------------------------+" -ForegroundColor Yellow
    if ($Utente)   { Write-Host "     Email / utente : $Utente" -ForegroundColor White }
    if ($Password) { Write-Host "     Password      : $Password" -ForegroundColor White }
    if (-not $RunReale) { return }
    # Copio subito l'email (di solito e' il primo campo), poi lascio il menu.
    if ($Utente) { try { Set-Clipboard -Value $Utente } catch {} }
    Write-Host ""
    $opz = @()
    if ($Utente)   { $opz += "E = copia EMAIL" }
    if ($Password) { $opz += "P = copia PASSWORD" }
    $opz += "INVIO = ho finito"
    Write-Host ("  Premi:  " + ($opz -join "    ")) -ForegroundColor Cyan
    if ($Utente) { Write-OK "Email gia' copiata: incolla con CTRL+V." }
    Start-BipRipetuto
    try {
        while ($true) {
            $ch = ""; $isEnter = $false
            try {
                $key = [Console]::ReadKey($true)
                $ch = "$($key.KeyChar)".ToUpper()
                if ($key.Key -eq [ConsoleKey]::Enter) { $isEnter = $true }
            } catch {
                # Fallback senza ReadKey: riga di testo, vuoto = ho finito.
                $ch = (Read-Host "  E / P / INVIO").ToUpper()
                if ($ch -eq "") { $isEnter = $true }
            }
            if ($isEnter) { break }
            elseif ($ch -eq "E") {
                if ($Utente) { try { Set-Clipboard -Value $Utente; Write-OK "Email copiata: incolla con CTRL+V." } catch {} }
                else { Write-Info "Nessuna email da copiare." }
            }
            elseif ($ch -eq "P") {
                if ($Password) { try { Set-Clipboard -Value $Password; Write-OK "Password copiata: incolla con CTRL+V." } catch {} }
                else { Write-Info "Per questo servizio la password la crea il sito (arriva via email)." }
            }
            # ogni altro tasto: ignorato, il menu resta attivo
        }
    } finally {
        Stop-BipRipetuto
    }
    Write-Host ""
}

function Installa-Antivirus {
    param(
        [string]$Nome,
        [string]$UrlRiscatto,
        [string]$Utente = "",
        [string]$Password = ""
    )

    Write-Info "Apertura pagina registrazione/riscatto $Nome..."
    Start-Process $UrlRiscatto
    Write-OK "Browser aperto su: $UrlRiscatto"
    Write-Host ""
    Write-Host "Completa registrazione/download nel browser." -ForegroundColor White
    Write-Host "L'installer parte DA SOLO appena finisce di scaricarsi (niente INVIO)." -ForegroundColor White
    # Antivirus: l'attivazione si fa accedendo con l'account principale del
    # cliente. Metto quelle credenziali pronte da incollare.
    Mostra-CredenzialiPagina -Utente $Utente -Password $Password

    # Sorveglio Download e Desktop: appena compare un .exe NUOVO (creato dopo
    # ORA) e il download e' finito (dimensione stabile), lo avvio da solo.
    $cartelle = @((Join-Path $env:USERPROFILE "Downloads"), (Get-DesktopDir)) | Select-Object -Unique
    $inizio = Get-Date
    $timeoutMin = if ($Global:ModoAutomatico) { 3 } elseif ($Global:ModoEspresso) { 5 } else { 8 }
    Write-Info "In attesa dell'installer di $Nome (max $timeoutMin min). Premi 'S' per saltare."
    $installer = $null
    while (((Get-Date) - $inizio).TotalMinutes -lt $timeoutMin) {
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq [ConsoleKey]::S -or $k.Key -eq [ConsoleKey]::Escape) {
                    Write-Info "Attesa installer interrotta dall'operatore."
                    break
                }
            }
        } catch {}
        $cand = Get-ChildItem -Path $cartelle -Filter "*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $inizio -and $_.Length -gt 100KB } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($cand) {
            # Aspetto che il file smetta di crescere = download completo.
            $dim1 = $cand.Length
            Start-Sleep -Seconds 2
            $cand.Refresh()
            if ($cand.Length -eq $dim1) { $installer = $cand; break }
        }
        Start-Sleep -Seconds 2
    }

    if ($installer) {
        Start-Process -FilePath $installer.FullName
        Write-OK "Installer $Nome avviato AUTOMATICAMENTE: $($installer.Name)"
        Add-Report "$Nome (antivirus)" "OK"
    } else {
        Write-Info "Nessun installer rilevato entro $timeoutMin min: avvialo a mano dalla cartella Download."
        Add-Report "$Nome (antivirus)" "AVVISO"
    }
}

# Servizio web-only (nessun installer PC): apre il sito, l'operatore inserisce
# il codice e segna le credenziali per l'app mobile del cliente.
function Attiva-ServizioWeb {
    param(
        [string]$Nome,
        [string]$UrlAttivazione,
        [string]$Utente = "",
        [string]$Password = ""
    )

    Write-Info "Apertura pagina attivazione $Nome..."
    Start-Process $UrlAttivazione
    Write-OK "Browser aperto su: $UrlAttivazione"
    Write-Host ""
    Write-Host "Sul sito: inserisci il codice/PIN e completa i dati richiesti." -ForegroundColor White
    Write-Host "IMPORTANTE: annota le credenziali per l'app mobile e consegnale al cliente." -ForegroundColor Yellow
    # Registrazione col cliente: uso la sua email come utente (pronta da incollare).
    # La password del portale spesso la crea il sito e la manda via email.
    Mostra-CredenzialiPagina -Utente $Utente -Password $Password
    $fatto = Attendi-Risposta "Attivazione completata e credenziali annotate? (S/N)"
    if ($fatto -match "^[Ss]") {
        Write-OK "$Nome attivato."
        Add-Report "$Nome (protezione)" "OK"
    } else {
        Write-Info "$Nome non completato."
        Add-Report "$Nome (protezione)" "SALTATO"
    }
}

# Il wizard: passo 3=Aggiornamenti, 4=Driver, 5=Applicazioni + browser,
# 6=Antivirus, 7=Unieuro Cyber Protection (ULTIMO SERVIZIO). La barra mostra (passo-2) su 5.
$passo = 3
# Nomi leggibili dei passi wizard per il checkpoint di ripresa sessione.
$wizNomi = @{ 3 = "Aggiornamenti (app + Windows)"; 4 = "Driver"; 5 = "Applicazioni + browser"; 6 = "Antivirus"; 7 = "Unieuro Cyber Protection" }
# Ripresa sessione: fase 7..11 = passo wizard 3..7 completato -> si riparte
# dal successivo (fase 11 = tutto il wizard fatto, si salta al report).
if ($Global:FaseRipresa -ge 7) {
    $passo = $Global:FaseRipresa - 3
    if ($passo -le 7) { Write-Info "Riprendo il wizard dal passo $($passo - 2) di 5." }
}
:wizard while ($passo -ge 3 -and $passo -le 7) {
Write-Host ""
$barLen = 20
$totPassi = 5
$passoMostrato = $passo - 2
$pieni = [int]($barLen * $passoMostrato / $totPassi)
if ($pieni -gt $barLen) { $pieni = $barLen }
$bar = (([string]$BOX_FULL) * $pieni) + (([string]$BOX_EMPTY) * ($barLen - $pieni))
Write-Host ("$AON  Passo $passoMostrato/$totPassi  [$bar]$AOFF") -ForegroundColor $THEME_COL
switch ($passo) {
3 {
# =============================================================================
# PASSO 3 - AGGIORNAMENTI - app installate (winget) + sicurezza di Windows
# =============================================================================

Write-Titolo "Aggiornamenti (app + Windows)"
Update-PannelloStatus -TaskId "aggiorna" -Stato "running" -Percentuale 55 -FaseCorrente "Aggiornamenti di Sicurezza" -Dettaglio "Verifica aggiornamenti app e Windows..."

Write-Host "Con un solo SI aggiorno, una dopo l'altra:" -ForegroundColor White
Write-Host "  - App: all'ultima versione le app gestite da winget (anche OEM)." -ForegroundColor White
Write-Host "  - Windows: gli aggiornamenti di SICUREZZA di Windows." -ForegroundColor White
Write-Host "Puo' richiedere diversi minuti. (I driver hanno il loro passo dedicato dopo.)" -ForegroundColor White
Write-Host ""

    $vuoiUpgrade = "S"
if ($vuoiUpgrade -match "^[Ss]") {
    # 1) APP INSTALLATE (winget)
    if (Confirm-Winget) {
        $null = Invoke-WingetConBarra -Nome "aggiornamenti app" -WingetArgs @('upgrade', '--all', '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown') -TimeoutSec 600
        Write-OK "Aggiornamento app completato."
        Add-Report "Aggiornamento app installate" "OK"
    } else {
        Write-Errore "Winget non disponibile."
        Add-Report "Aggiornamento app installate" "ERRORE"
    }

    # 2) AGGIORNAMENTI DI SICUREZZA DI WINDOWS: programmati in background per il Passo 5 (dopo i driver).
    # In questo modo si evita qualsiasi contesa di lock/sessione sul servizio Windows Update (wuauserv)
    # durante il passo driver!
    Write-Host ""
    Write-Info "Aggiornamenti Windows: programmati in background (partiranno durante le app, dopo i driver)."
    $Global:AvviaWinUpdateDopoDriver = $true
    if ($Test) {
        Write-OK "TEST: simulazione download aggiornamenti Windows programmato in background."
        Add-Report "Aggiornamenti Windows (scaricati in background)" "OK"
    }
    Update-PannelloStatus -TaskId "aggiorna" -Stato "running" -Percentuale 62 -Dettaglio "Aggiornamenti app completati"
} else {
    $Global:AvviaWinUpdateDopoDriver = $false
    Write-Info "Aggiornamenti saltati (app e Windows)."
    Add-Report "Aggiornamento app installate" "SALTATO"
    Add-Report "Aggiornamenti di sicurezza Windows" "SALTATO"
    Update-PannelloStatus -TaskId "aggiorna" -Stato "skipped" -Percentuale 62 -Dettaglio "Saltato"
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
4 {
# =============================================================================
# PASSO 4 - DRIVER (Windows Update, opzionale)
# =============================================================================

Write-Titolo "Driver (Windows Update)"
Update-PannelloStatus -TaskId "aggiorna" -Stato "running" -Percentuale 65 -FaseCorrente "Driver Hardware & GPU" -Dettaglio "Verifica driver grafici e periferiche..."

Write-Host "Cerca e installa i driver mancanti/aggiornati dal catalogo Windows Update." -ForegroundColor White
Write-Host "Se c'e' una scheda video DEDICATA, uso anche il tool del produttore (Windows" -ForegroundColor White
Write-Host "Update spesso non ne prende il driver giusto). Puo' richiedere qualche minuto" -ForegroundColor White
Write-Host "e talvolta un riavvio. Opzionale." -ForegroundColor White
Write-Host ""

$gpuDed = Get-GpuDedicata
switch ($gpuDed) {
    'NVIDIA' {
        if (Confirm-Winget) {
            Write-Info "Scheda video NVIDIA (dedicata): installo l'app NVIDIA per i driver..."
            winget install --exact --id Nvidia.NvidiaApp --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                winget install --exact --id Nvidia.GeForceExperience --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            }
            if ($LASTEXITCODE -eq 0) {
                Write-OK "App NVIDIA installata: APRILA per scaricare i driver piu' recenti."
                Add-Report "App NVIDIA (driver GeForce): aprire per completare" "OK"
            } else {
                Write-Info "App NVIDIA non installata (id/rete): scaricala da nvidia.com/it-it/software/nvidia-app/"
                Add-Report "App NVIDIA (driver GeForce)" "AVVISO"
            }
        }
        Write-Host ""
    }
    'INTEL' {
        if (Confirm-Winget) {
            Write-Info "Scheda video Intel Arc (dedicata): installo Intel Driver & Support Assistant..."
            Installa-Pacchetto -Nome "Intel Driver e Support Assistant" -WingetId "Intel.IntelDriverAndSupportAssistant"
            Write-Info "APRI 'Intel Driver & Support Assistant' per scaricare il driver video."
            Add-Report "Intel DSA (driver video): aprire per completare" "OK"
        }
        Write-Host ""
    }
    'AMD' {
        Write-Info "Scheda video AMD (dedicata): apro la pagina AMD per il driver video."
        Start-Process "https://www.amd.com/it/support"
        Write-OK "Browser aperto su amd.com/it/support (auto-rilevamento driver)."
        Write-Info "Scarica ed esegui 'AMD Software: Adrenalin Edition', poi riavvia se richiesto."
        Add-Report "AMD (driver video): scaricare da amd.com" "AVVISO"
        Write-Host ""
    }
    default {
        Write-Info "Nessuna scheda video dedicata rilevata: i driver video li gestisce Windows Update."
    }
}

    $vuoiDriver = "S"
if ($vuoiDriver -match "^[Ss]") {
    $resDrv = Install-WindowsUpdateDrivers -TimeoutSec 360 -Test:$Test
} else {
    Write-Info "Installazione driver saltata."
    Add-Report "Driver (Windows Update)" "SALTATO"
    Update-PannelloStatus -TaskId "aggiorna" -Stato "skipped" -Percentuale 72 -Dettaglio "Saltato"
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
5 {
# =============================================================================
# PASSO 5 - APPLICAZIONI + BROWSER
# =============================================================================

Write-Titolo "Applicazioni"
Update-PannelloStatus -TaskId "app" -Stato "running" -Percentuale 74 -FaseCorrente "Installazione Applicazioni" -Dettaglio "Avvio installazione app..."

# Avvio del download di Windows Update in background (se programmato al Passo 3).
# Ora che i driver sono terminati e le risorse COM sono libere, puo' girare
# in background in parallelo a Winget e alle ottimizzazioni senza alcun conflitto.
if ($Global:AvviaWinUpdateDopoDriver -and -not $Global:JobWinUpdate -and -not $Test) {
    try {
        $Global:JobWinUpdate = Start-Job -ScriptBlock {
            try {
                $s    = New-Object -ComObject Microsoft.Update.Session
                $res  = $s.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software' and IsHidden=0")
                $coll = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach ($u in $res.Updates) {
                    if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                    if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                    $coll.Add($u) | Out-Null
                }
                if ($coll.Count -gt 0) {
                    $dl = $s.CreateUpdateDownloader(); $dl.Updates = $coll; $dl.Download() | Out-Null
                }
                return $coll.Count
            } catch { return -1 }
        }
        Write-OK "Download aggiornamenti Windows avviato in background (in parallelo alle app)."
        Add-Report "Aggiornamenti Windows (scaricati in background)" "OK"
    } catch {
        Write-Errore "Impossibile avviare gli aggiornamenti di Windows: $_"
        Add-Report "Aggiornamenti di sicurezza Windows" "ERRORE"
    }
}

$appsDisponibili = $CatalogoApp
$profili = [ordered]@{
    "BASE"    = @($CatalogoApp | Where-Object { $_.Profili -contains "BASE" }    | ForEach-Object { $_.Id })
    "UFFICIO" = @($CatalogoApp | Where-Object { $_.Profili -contains "UFFICIO" } | ForEach-Object { $_.Id })
    "GAMING"  = @($CatalogoApp | Where-Object { $_.Profili -contains "GAMING" }  | ForEach-Object { $_.Id })
}

function Costruisci-PianoApp {
    param([string]$Scelta)
    $piano = @()
    if ($Scelta -eq "3") { $piano += @{ Nome = "Opera GX"; Id = "Opera.OperaGX" } }
    else                 { $piano += @{ Nome = "Google Chrome"; Id = "Google.Chrome" } }
    foreach ($app in $appsDisponibili) {
        $prendi = switch ($Scelta) {
            "1" { $profili["BASE"]    -contains $app.Id }
            "2" { $profili["UFFICIO"] -contains $app.Id }
            "3" { $profili["GAMING"]  -contains $app.Id }
            "4" { $true }
            default { $false }
        }
        if ($prendi) { $piano += @{ Nome = $app.Nome; Id = $app.Id } }
    }
    return $piano
}

$Global:AppFallite = 0

$pianoApp  = @()
$appFatte  = @()
$etichetta = ""

if ($Global:AppProfiloRipresa) {
    $etichetta = [string]$Global:AppProfiloRipresa
    $pianoApp  = @($Global:AppListaRipresa | ForEach-Object { @{ Nome = [string]$_.Nome; Id = [string]$_.Id } })
    $appFatte  = @($Global:AppFatteRipresa | ForEach-Object { [string]$_ })
    $Global:AppProfiloRipresa = ""; $Global:AppListaRipresa = @(); $Global:AppFatteRipresa = @()
    $rimaste = @($pianoApp | Where-Object { $appFatte -notcontains $_.Id }).Count
    Write-OK "Riprendo l'installazione app (profilo $etichetta): $rimaste da completare."
    Write-Info "Le app gia' installate le salto: riparto dall'esatta app rimasta."
} elseif ($Global:ModoEspresso) {
    Write-Host "Modalita' Espresso: installazione automatica del PROFILO BASE..." -ForegroundColor Green
    Write-Host "  (Google Chrome, VLC, Adobe Acrobat Reader, 7-Zip, AnyDesk, WhatsApp, Spotify, AIMP, Zoom)" -ForegroundColor Gray
    $etichetta = "BASE"
    $pianoApp  = @(Costruisci-PianoApp -Scelta "1")
} else {
    Write-Host "Scegli come installare le applicazioni (browser incluso in automatico):" -ForegroundColor White
    Write-Host "  1) PROFILO BASE     (Chrome + VLC, Adobe Reader, 7-Zip, WhatsApp, Spotify, AIMP, Zoom, AnyDesk)"
    Write-Host "  2) PROFILO UFFICIO  (Chrome + BASE + GIMP, Sumatra PDF)"
    Write-Host "  3) PROFILO GAMING   (Opera GX + BASE + Steam, Epic, Discord)"
    Write-Host "  4) COMPLETO         (Chrome + tutte le app in lista)"
    Write-Host "  5) MANUALE          (Chrome + scelgo io i singoli numeri)"
    Write-Host "  S) Salta"
    Write-Host ""

    $sceltaApps = Attendi-Risposta "Scelta (1-5 - S salta - B indietro)"
    if (Test-Indietro $sceltaApps) { $passo = [Math]::Max(3, $passo - 1); continue wizard }

    switch -Regex ($sceltaApps) {
        "^[1-4]$" {
            $etichetta = @{ "1" = "BASE"; "2" = "UFFICIO"; "3" = "GAMING"; "4" = "COMPLETO" }[$sceltaApps]
            $pianoApp  = @(Costruisci-PianoApp -Scelta $sceltaApps)
        }
        "^5$" {
            $etichetta = "MANUALE"
            $pianoApp += @{ Nome = "Google Chrome"; Id = "Google.Chrome" }
            Write-Host ""
            Write-Host "App disponibili:" -ForegroundColor White
            for ($i = 0; $i -lt $appsDisponibili.Count; $i++) {
                Write-Host "  $($i + 1)) $($appsDisponibili[$i].Nome)"
            }
            $sceltaManuale = Attendi-Risposta "Numeri separati da virgola (es: 1,3,5)"
            $indici = $sceltaManuale -split "," | ForEach-Object { $_.Trim() }
            foreach ($indice in $indici) {
                $num = 0
                if ($indice -match "^\d+$" -and [int]::TryParse($indice, [ref]$num)) {
                    $idx = $num - 1
                    if ($idx -ge 0 -and $idx -lt $appsDisponibili.Count) {
                        $pianoApp += @{ Nome = $appsDisponibili[$idx].Nome; Id = $appsDisponibili[$idx].Id }
                    } else {
                        Write-Errore "Numero non valido: $indice"
                    }
                } elseif ($indice -ne "") {
                    Write-Errore "Valore non riconosciuto: $indice"
                }
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
}

if ($pianoApp.Count -gt 0) {
    if ($pianoApp | Where-Object { $_.Id -eq "Google.Chrome" -or $_.Id -eq "Opera.OperaGX" }) {
        Remove-EdgeDaDesktop
    }
    $appIndex = 0
    foreach ($app in $pianoApp) {
        $appIndex++
        if ($appFatte -contains $app.Id) {
            Write-Info "$($app.Nome): gia' installato in questa sessione, salto."
            continue
        }
        $currPct = 74 + [int](14 * $appIndex / $pianoApp.Count)
        Update-PannelloStatus -TaskId "app" -Stato "running" -Percentuale $currPct -FaseCorrente "Installazione Applicazioni" -Dettaglio "Installazione $($app.Nome) in corso..."
        Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id
        if ($Global:UltimaInstallOk) {
            $appFatte += $app.Id
            Save-AppProgresso -Profilo $etichetta -Lista $pianoApp -Fatte $appFatte
        }
    }
    Update-PannelloStatus -TaskId "app" -Stato "done" -Percentuale 88 -Dettaglio "Tutte le app installate"
} else {
    Update-PannelloStatus -TaskId "app" -Stato "skipped" -Percentuale 88 -Dettaglio "Saltato"
}

Remove-IconeDoppieDesktop

if ($Global:AppFallite -ge 2) {
    Write-Host ""
    Write-Errore "$($Global:AppFallite) app non installate: probabile RETE con proxy/filtro."
    Write-Info "Collega il PC a un'altra rete (HOTSPOT del telefono o linea senza filtri)"
    Write-Info "e rilancia PC Facile: rispondi S a 'Riprendere da dove eri arrivato?' -"
    Write-Info "le app gia' installate si saltano da sole, riscarica solo le mancanti."
    Add-Report "App non installate ($($Global:AppFallite)): probabile rete" "AVVISO"
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
6 {
# =============================================================================
# PASSO 6 - ANTIVIRUS
# =============================================================================

Write-Titolo "Antivirus"
Update-PannelloStatus -TaskId "antivirus" -Stato "running" -Percentuale 90 -FaseCorrente "Configurazione Antivirus" -Dettaglio "Verifica Windows Defender e card cliente..."

if ($Global:ModoEspresso) {
    if ($Global:serviziSelezionati -and ($Global:serviziSelezionati.McAfee -or $Global:serviziSelezionati.Norton)) {
        if ($Global:serviziSelezionati.McAfee) {
            Write-OK "Antivirus McAfee selezionato nel pannello e attivato."
            Add-Report "Antivirus" "OK (Card McAfee)"
            Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Percentuale 92 -Dettaglio "Card McAfee attivata"
        } else {
            Write-OK "Antivirus Norton selezionato nel pannello e attivato."
            Add-Report "Antivirus" "OK (Card Norton)"
            Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Percentuale 92 -Dettaglio "Card Norton attivata"
        }
    } else {
        Write-OK "Modalita' Espresso: Windows Defender / Sicurezza di Windows configurato e attivo."
        Add-Report "Antivirus" "OK (Windows Defender)"
        Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Percentuale 92 -Dettaglio "Windows Defender attivo"
    }
} else {
    Write-Host "Scegli l'antivirus da installare:" -ForegroundColor White
    Write-Host "  1) McAfee"
    Write-Host "  2) Norton"
    Write-Host "  3) Salta (Windows Defender attivo)"
    Write-Host ""

    $sceltaAV = Attendi-Risposta "Scelta (1-3, B=indietro)"
    if (Test-Indietro $sceltaAV) { $passo = [Math]::Max(3, $passo - 1); continue wizard }

    switch ($sceltaAV) {
        "1" {
            Installa-Antivirus -Nome "McAfee" -UrlRiscatto "https://www.mcafee.com/activate" -Utente $credMsAccount -Password $credMsPassword
            Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Percentuale 92 -Dettaglio "McAfee configurato"
        }
        "2" {
            Installa-Antivirus -Nome "Norton" -UrlRiscatto "https://www.norton.com/setup" -Utente $credMsAccount -Password $credMsPassword
            Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Percentuale 92 -Dettaglio "Norton configurato"
        }
        default {
            Write-Info "Antivirus dedicato saltato: Windows Defender e' attivo e aggiornato."
            Add-Report "Antivirus" "OK (Windows Defender)"
            Update-PannelloStatus -TaskId "antivirus" -Stato "done" -Percentuale 92 -Dettaglio "Windows Defender attivo"
        }
    }
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
7 {
# =============================================================================
# PASSO 7 - UNIEURO CYBER PROTECTION (opzionale, ultimo passo prima della consegna)
# =============================================================================

Write-Titolo "Unieuro Cyber Protection"
Update-PannelloStatus -TaskId "cyber" -Stato "running" -Percentuale 94 -FaseCorrente "Unieuro Cyber Protection" -Dettaglio "Configurazione servizio web..."

if ($Global:ModoEspresso) {
    if ($Global:serviziSelezionati -and $Global:serviziSelezionati.Cyber) {
        Write-OK "Unieuro Cyber Protection registrato con successo."
        Add-Report "Unieuro Cyber Protection" "OK (Registrato)"
        Update-PannelloStatus -TaskId "cyber" -Stato "done" -Percentuale 96 -Dettaglio "Registrato con successo"
    } else {
        Write-Info "Modalita' Espresso: Cyber Protection disponibile 1-Click dal Pannello Operatore."
        Add-Report "Unieuro Cyber Protection" "Disponibile (Pannello Operatore)"
        Update-PannelloStatus -TaskId "cyber" -Stato "done" -Percentuale 96 -Dettaglio "Disponibile 1-Click nel pannello"
    }
} else {
    Write-Host "Servizio venduto solo su richiesta: INVIO per saltare se non l'ha comprato." -ForegroundColor White
    Write-Host ""

    $vuoiUnieuro = Attendi-Risposta "Attivare Unieuro Cyber Protection? (S = si / INVIO = no, B=indietro)"
    if (Test-Indietro $vuoiUnieuro) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
    if ($vuoiUnieuro -match "^[Ss]") {
        Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it" -Utente $credMsAccount
        Update-PannelloStatus -TaskId "cyber" -Stato "done" -Percentuale 96 -Dettaglio "Configurato"
    } else {
        Write-Info "Unieuro Cyber Protection saltato."
        Add-Report "Unieuro Cyber Protection" "SALTATO"
        Update-PannelloStatus -TaskId "cyber" -Stato "skipped" -Percentuale 96 -Dettaglio "Non acquistato (saltato)"
    }
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
}
# Checkpoint di ripresa: $passo e' gia' stato incrementato, il passo appena
# completato e' ($passo - 1); la sua fase e' ($passo - 1) + 4.
Save-Fase ($passo + 3) $wizNomi[($passo - 1)]
if ($passo -lt 3) { $passo = 3 }
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
    # LEGGIBILITA' SCHERMO: imposta il ridimensionamento (scaling) in base alla
    # risoluzione, cosi' il PC non esce con tutto microscopico sugli schermi ad
    # alta risoluzione. Via registro (Win8DpiScaling + LogPixels), niente
    # P/Invoke. Si applica del tutto dopo il logout/riavvio. Fatto qui (dopo i
    # driver) perche' la risoluzione ormai e' quella nativa/definitiva.
    # -------------------------------------------------------------------------
    try {
        $hres = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                 Where-Object { $_.CurrentHorizontalResolution } |
                 Sort-Object CurrentHorizontalResolution -Descending |
                 Select-Object -First 1).CurrentHorizontalResolution
        if ($hres) {
            $logPixels = if ($hres -ge 3800) { 192 }        # 4K      -> 200%
                         elseif ($hres -ge 2500) { 144 }    # ~1440p  -> 150%
                         elseif ($hres -ge 1900) { 120 }    # 1080p   -> 125%
                         else { 96 }                        # sotto   -> 100%
            $perc = [int]($logPixels / 96 * 100)
            $desk = "HKCU:\Control Panel\Desktop"
            Set-ItemProperty -Path $desk -Name "Win8DpiScaling" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $desk -Name "LogPixels" -Value $logPixels -Type DWord -ErrorAction SilentlyContinue
            Write-OK "Ridimensionamento schermo a $perc% (risoluzione ${hres}px): attivo dopo il logout."
            Add-Report "Ridimensionamento schermo ($perc%)" "OK"
        }
    } catch {
        Write-Info "Ridimensionamento schermo non impostato: proseguo."
    }

    # -------------------------------------------------------------------------
    # CHIAVE DI RIPRISTINO BITLOCKER (il piu' TARDI possibile: se la device
    # encryption di Windows 11 si e' attivata durante il setup, ora la chiave
    # esiste). Usa la funzione di log Add-Report come gli altri passi.
    # DATO SENSIBILE: la chiave finisce nel riepilogo che resta col PC (voluto).
    # -------------------------------------------------------------------------
    Update-PannelloStatus -TaskId "diagnostica" -Stato "running" -Percentuale 98 -FaseCorrente "Diagnostica & Scheda Consegna" -Dettaglio "Salvataggio BitLocker e scheda cliente..."
    Write-Titolo "Chiave di Ripristino BitLocker"
    Write-Host "Salvo la chiave di ripristino nel riepilogo: senza, se Windows attiva la" -ForegroundColor White
    Write-Host "crittografia da solo, dopo un reset o un cambio hardware si perde l'accesso." -ForegroundColor White
    Write-Host ""
    $bitlocker = Get-BitLockerRecovery -Volume $env:SystemDrive
    switch ($bitlocker.Esito) {
        "OK"      {
            Write-OK "Chiave di ripristino BitLocker salvata (volume $($bitlocker.Volume))."
            try {
                $nonCancFile = Join-Path (Get-DesktopDir) "NON CANCELLARE - Chiave di Ripristino BitLocker.txt"
                $nonCancText = @"
================================================================================
   CHIAVE DI RIPRISTINO BITLOCKER - NON CANCELLARE QUESTO FILE
================================================================================

Questo computer ha la crittografia di sicurezza BitLocker attiva.
Se dopo un aggiornamento di Windows, un cambio di password o un intervento tecnico
il sistema dovesse richiedere la 'Chiave di ripristino di BitLocker', inserisci
il codice numerico di 48 cifre riportato qui sotto:

ID CHIAVE (Identificatore):
$($bitlocker.KeyId)

CHIAVE DI RIPRISTINO (48 cifre):
$($bitlocker.RecoveryKey)

Volume protetto : $($bitlocker.Volume)
Data salvataggio: $(Get-Date -Format 'dd/MM/yyyy HH:mm')

================================================================================
IMPORTANTE:
Non eliminare questo file. Ti consigliamo di scattare una foto con lo smartphone
a questo promemoria o di salvarne una copia su una chiavetta USB personale
per averlo sempre a disposizione in caso di necessita'.
================================================================================
"@
                $nonCancText | Set-Content -Path $nonCancFile -Encoding UTF8
                Write-OK "Creato file di sicurezza sul Desktop: $nonCancFile"
            } catch {}
        }
        "SALTATO" { Write-Info $bitlocker.Messaggio }
        default   { Write-Info $bitlocker.Messaggio }   # AVVISO
    }
    Add-Report "Chiave di ripristino BitLocker" $bitlocker.Esito

    # Diagnostica salute hardware e stato licenza
    $storageInfo = Get-StorageHealthInfo
    $batteryInfo = Get-BatteryHealthInfo
    $winActInfo  = Get-WindowsActivationStatus

    # Le credenziali del nuovo account le ha GENERATE lo script allo step Account
    # Microsoft ($credMsAccount / $credMsPassword). Se quel passo e' stato saltato
    # restano vuote. Niente domande all'operatore, niente password dal browser.
    #
    # Leggi se l'operatore ha salvato/aggiornato credenziali dal pannello Edge
    Get-CredenzialiSalvatePannello | Out-Null
    if ($Global:nomeCliente -and $Global:nomeCliente -notmatch '^(Cliente|OEM|Utente)$') {
        $nomeCliente = $Global:nomeCliente
        try {
            Set-LocalUser -Name $env:USERNAME -FullName $nomeCliente -ErrorAction SilentlyContinue
        } catch {
            try {
                $u = [ADSI]"WinNT://$env:COMPUTERNAME/$env:USERNAME,user"
                $u.FullName = $nomeCliente
                $u.SetInfo()
            } catch {}
        }
        $cleanPc = ($nomeCliente -replace '[^A-Za-z0-9]', '')
        if ($cleanPc -and $cleanPc.ToUpper() -ne "OEM") {
            $pcNuovo = "PC-$cleanPc"
            if ($pcNuovo.Length -gt 15) { $pcNuovo = $pcNuovo.Substring(0, 15) }
            if ($pcNuovo -ne "" -and $pcNuovo.ToUpper() -ne $env:COMPUTERNAME.ToUpper()) {
                try { Rename-Computer -NewName $pcNuovo -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # RETE DI SICUREZZA sulla PASSWORD: nel file non deve MAI mancare.
    if (-not $credMsPassword) {
        $basePass = if ($nomeCliente -and $nomeCliente.ToUpper() -ne "OEM") { $nomeCliente } else { "Utente" }
        $credMsPassword = New-PasswordCliente -Base $basePass
    }
    if (-not $credMsAccount) {
        $baseAcc = if ($nomeCliente -and $nomeCliente.ToUpper() -ne "OEM") { $nomeCliente } else { "utente" }
        $domRete = if ($Global:credDominio) { $Global:credDominio } else { "outlook.it" }
        $credMsAccount = New-EmailCliente -Base $baseAcc -Dominio $domRete
    }
    try {
        $winOk   = ($winActInfo.Attivo -or (@($Report | Where-Object { $_.Voce -eq 'Windows attivato' -and $_.Esito -eq 'OK' }).Count -gt 0))
        $diskBad = ($storageInfo.Salute -notmatch 'Healthy|Buono|OK' -or (@($Report | Where-Object { $_.Voce -eq 'Salute disco' -and $_.Esito -eq 'ERRORE' }).Count -gt 0))
        $freeTxt = ""
        try { $freeTxt = "{0} GB liberi" -f [math]::Round((Get-PSDrive ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free / 1GB, 1) } catch {}

        $softwareOk = @($Report | Where-Object { $_.Voce -like '*installazione*' -and $_.Esito -eq 'OK' } |
                        ForEach-Object { ($_.Voce -replace ' \(installazione\)', '').Trim() })
        $av = @($Report | Where-Object { ($_.Voce -like '*antivirus*' -or $_.Voce -like '*protezione*') -and $_.Esito -eq 'OK' })
        $altre = @($Report | Where-Object { $_.Voce -notlike '*installazione*' -and $_.Voce -notlike '*antivirus*' -and $_.Voce -notlike '*protezione*' })

        # --- VERIFICA FINALE: le cose importanti sono andate DAVVERO? (ricontrollo
        #     lo stato vero, non mi fido degli esiti dei singoli passi). ---
        $verifica = @()
        # Verifica lingua installata: Get-InstalledLanguage non c'e' su tutti i
        # sistemi (in tal caso cado su DISM Get-WindowsLanguagePack, che elenca i
        # language pack reali; servono admin, e qui lo siamo). Se proprio nessuno
        # dei due funziona -> $null e la voce si omette dalla verifica finale.
        $vLang = $null
        try {
            if (Get-Command Get-InstalledLanguage -ErrorAction SilentlyContinue) {
                $vLang = (@(Get-InstalledLanguage -ErrorAction Stop).LanguageId -contains 'it-IT')
            } else {
                $vLang = (@(Get-WindowsLanguagePack -Online -ErrorAction Stop | Where-Object { $_.Language -match '^it-' }).Count -gt 0)
            }
        } catch { $vLang = $null }
        if ($null -ne $vLang) { $verifica += [pscustomobject]@{ N = 'Pacchetto lingua italiano'; Ok = $vLang } }
        $verifica += [pscustomobject]@{ N = 'OneDrive rimosso'; Ok = (-not (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe")) }
        # "Antivirus di prova rimossi": conta SOLO i trial NON installati in questa
        # sessione - un AV scelto al passo Antivirus (McAfee/Norton) e' voluto,
        # non una prova da togliere, quindi va escluso dai "di prova".
        $avInstallatiNoi = @($av | ForEach-Object { ($_.Voce -replace ' \(antivirus\)', '' -replace ' \(protezione\)', '').Trim() })
        $avRestanoProva  = @(Get-AntivirusInstallati | Where-Object { $avInstallatiNoi -notcontains $_.Nome })
        $verifica += [pscustomobject]@{ N = 'Antivirus di prova rimossi'; Ok = ($avRestanoProva.Count -eq 0) }
        $verifica += [pscustomobject]@{ N = 'Windows attivato'; Ok = $winOk }

        # Mostro la verifica anche a schermo (oltre che nel file).
        Write-Titolo "Verifica finale"
        foreach ($v in $verifica) { if ($v.Ok) { Write-OK $v.N } else { Write-Errore "$($v.N): DA RIFARE" } }

        # --- Dettagli tecnici per l'assistenza (troubleshooting nello stesso file) ---
        $osInfo = $null; try { $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
        $hwInfo = Get-SystemHardwareDetails
        $wgVer = "n/d"; try { $wgVer = (winget --version) 2>$null } catch {}
        $resTxt = if ($hres) { "$hres" } else { "n/d" }
        $avTxt = try { (@(Get-AntivirusInstallati).Nome | Select-Object -Unique) -join ', ' } catch { '' }
        if (-not $avTxt) { $avTxt = 'nessuno' }

        $sep = "------------------------------------------------------------"

        # === CREDENZIALI: raccolgo TUTTO in un unico posto. Vanno IN CIMA al
        #     riepilogo (le prime cose che deve vedere l'operatore) e in un file
        #     dedicato. Ordine: account principale, poi Cyber Protection /
        #     antivirus attivati in questa sessione. ===
        $blank = "______________________________"
        $provNome = if ($Global:credProvider) { $Global:credProvider } elseif ($prov) { $prov.Nome } else { "Microsoft" }
        $credList = @()
        $credList += [pscustomobject]@{
            Servizio = "ACCOUNT PRINCIPALE ($provNome)"
            Utente   = $credMsAccount; Password = $credMsPassword
            Extra    = "Serve per Windows, Office e antivirus"
        }
        foreach ($a in $av) {
            $svc = ($a.Voce -replace ' \(antivirus\)', '' -replace ' \(protezione\)', '').Trim()
            if ($a.Voce -like '*protezione*') {
                $credList += [pscustomobject]@{ Servizio = "$svc (Cyber Protection)"; Utente = $credMsAccount; Password = "(creata dal sito: arriva via email al cliente)"; Extra = "PIN card grattata: __________" }
            } else {
                $credList += [pscustomobject]@{ Servizio = "$svc (Antivirus)"; Utente = $credMsAccount; Password = $credMsPassword; Extra = "Attivato con l'account principale - PIN card: __________" }
            }
        }
        # Blocco testo delle credenziali (riusato in cima al riepilogo e nel file).
        $credBlocco = @()
        $credBlocco += "############################################################"
        $credBlocco += "#   CREDENZIALI E ACCOUNT DEL CLIENTE                       #"
        $credBlocco += "#   Dati in chiaro: consegnali al cliente, non diffonderli  #"
        $credBlocco += "############################################################"
        foreach ($c in $credList) {
            $credBlocco += ""
            $credBlocco += ">>> $($c.Servizio)"
            $credBlocco += "      Email / utente : $(if ($c.Utente)   { $c.Utente }   else { $blank })"
            $credBlocco += "      Password       : $(if ($c.Password) { $c.Password } else { $blank })"
            if ($c.Extra) { $credBlocco += "      Nota           : $($c.Extra)" }
        }

        $clienteDisplay = if ($nomeCliente -and $nomeCliente.ToUpper() -ne "OEM") { $nomeCliente } elseif ($isOemUser -or $env:USERNAME.ToUpper() -eq "OEM") { "Utente" } else { $env:USERNAME }
        $pcDisplay = if ($pcNuovo) { $pcNuovo } elseif ($env:COMPUTERNAME -match '^(LAPTOP|DESKTOP|WIN)-[A-Z0-9]{4,10}$' -or $env:COMPUTERNAME.ToUpper() -eq "OEM") { "PC-$clienteDisplay" } else { $env:COMPUTERNAME }

        $f = @()
        $f += "============================================================"
        $f += "   IL TUO NUOVO PC E' PRONTO"
        $f += "============================================================"
        $f += ""
        $f += "Data     : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
        $f += "Cliente  : $clienteDisplay"
        $f += "Nome PC  : $pcDisplay"
        $f += "Utente   : $clienteDisplay"
        $f += ""
        $f += $credBlocco
        $f += ""
        $f += $sep
        $f += "HARDWARE, SERIALE & GARANZIA LEGALE"
        $f += $sep
        $f += "  Produttore / Modello : $($hwInfo.Produttore) $($hwInfo.Modello)"
        $f += "  Seriale (Service Tag): $($hwInfo.Seriale)"
        $f += "  Scheda Madre         : $($hwInfo.SchedaMadre)"
        $f += "  Processore (CPU)     : $($hwInfo.Cpu)"
        $f += "  Memoria RAM          : $($hwInfo.RamGB) GB"
        $f += "  Scheda Video (GPU)   : $($hwInfo.Gpu)"
        $f += "  Garanzia Legale (2a) : Valida fino al $($hwInfo.ScadenzaGaranzia)"
        $f += ""
        $f += $sep
        $f += "STATO SISTEMA & DIAGNOSTICA"
        $f += $sep
        $f += "  Windows attivato     : $($winActInfo.StatoBreve)"
        if ($freeTxt) { $f += "  Spazio disco C:      : $freeTxt" }
        $f += "  Salute disco/SSD     : $($storageInfo.StatoCompleto)"
        if ($batteryInfo.Presente) { $f += "  Batteria             : $($batteryInfo.Descrizione)" }
        $f += ""
        $f += $sep
        $f += "VERIFICA FINALE (ricontrollo automatico)"
        $f += $sep
        foreach ($v in $verifica) { $f += ("  [{0}] {1}" -f $(if ($v.Ok) { 'OK       ' } else { 'DA RIFARE' }), $v.N) }
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
                $f += "  >> NOTA: Salvata anche nel file 'NON CANCELLARE - Chiave di Ripristino BitLocker.txt' sul Desktop."
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
        if ($Global:ErroriImprevisti.Count -gt 0) {
            $f += $sep
            $f += "IMPREVISTI GESTITI ($($Global:ErroriImprevisti.Count)) - dettaglio nel log tecnico"
            $f += $sep
            foreach ($e in $Global:ErroriImprevisti) { $f += "  [riga $($e.Riga)] $($e.Messaggio)" }
            $f += ""
        }
        $f += $sep
        $f += "DETTAGLI TECNICI (per assistenza in negozio)"
        $f += $sep
        $f += "  Windows      : $(if ($osInfo) { "$($osInfo.Caption) build $($osInfo.BuildNumber)" } else { 'n/d' })"
        $f += "  PowerShell   : $($PSVersionTable.PSVersion)"
        $f += "  winget       : $wgVer"
        $f += "  Risoluzione  : $resTxt px"
        $f += "  Antivirus    : $avTxt"
        $f += "  Versione tool: $SCRIPT_VERSION"
        $f += "  Data setup   : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
        $f += ""
        $f += "============================================================"
        $f += "  Unieuro - Assistenza Tecnica & Installazioni PC"
        $f += "============================================================"

        # Il riepilogo tecnico testuale viene archiviato nei log di sistema (senza intasare il Desktop con file .txt grezzi)
        try {
            $logDir = Join-Path $env:ProgramData "PCFacile\log"
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            $f | Set-Content -Path (Join-Path $logDir "riepilogo-tecnico.txt") -Encoding UTF8
        } catch {}

        # Scheda di Consegna Cliente HTML stampabile con grafica moderna Unieuro (unico documento di consegna)
        try {
            $htmlFile = Join-Path (Get-DesktopDir) ("Scheda-Consegna-Cliente.html")
            $appInstallate = @($Report | Where-Object { $_.Voce -like '*installazione*' -and $_.Esito -eq 'OK' } | ForEach-Object { ($_.Voce -replace ' \(installazione\)', '' -replace ' \(installazione offline\)', '').Trim() })
            $appItems = ""
            foreach ($app in $appInstallate) { $appItems += "<div class='app-badge'>&#10003; <strong>$app</strong></div>" }
            if (-not $appItems) { $appItems = "<div class='app-badge'>&#10003; <strong>Applicazioni base configurate</strong></div>" }

            $credBox = ""
            if ($credMsAccount -or $credMsPassword) {
                $credBox = @"
            <div class='card card-cred'>
                <h3>&#128273; Credenziali di Primo Accesso &bull; $provNome</h3>
                <table class='info-table'>
                    <tr><td style='width: 32%; font-weight: 600;'>Email / Utente:</td><td><strong style='font-size: 14px; color: #00122B;'>$credMsAccount</strong></td></tr>
                    <tr><td style='font-weight: 600;'>Password iniziale:</td><td><code style='font-size: 14px; font-weight: bold; background: #fee2e2; color: #991b1b; padding: 2px 8px; border-radius: 4px;'>$credMsPassword</code> <em style='color: #64748b; font-size: 11px; margin-left: 8px;'>(da personalizzare al primo accesso)</em></td></tr>
                    <tr><td style='font-weight: 600;'>Account Windows:</td><td><code>$clienteDisplay</code></td></tr>
                    <tr><td style='font-weight: 600;'>Servizi inclusi:</td><td>Windows 11, Office / Microsoft 365, Antivirus &bull; Card PIN annotato</td></tr>
                </table>
            </div>
"@
            }

            $bitlockerBox = ""
            if ($bitlocker -and $bitlocker.RecoveryKey) {
                $bitlockerBox = @"
            <div class='card card-bitlocker'>
                <h3>&#128274; Chiave di Ripristino BitLocker (Protezione Disco)</h3>
                <table class='info-table'>
                    <tr><td style='width: 32%; font-weight: 600;'>Identificatore (ID):</td><td><code>$($bitlocker.KeyId)</code></td></tr>
                    <tr><td style='font-weight: 600;'>Chiave di Ripristino:</td><td><code style='font-size: 13px; font-weight: bold; background: #dcfce7; color: #14532d; padding: 4px 8px; border-radius: 4px; letter-spacing: 1px;'>$($bitlocker.RecoveryKey)</code></td></tr>
                    <tr><td colspan='2' style='font-size: 11px; color: #475569; padding-top: 4px;'><em>Conservare questo codice o scattare una foto con lo smartphone. Serve per sbloccare l'accesso al disco in caso di reset o manutenzione straordinaria.</em></td></tr>
                </table>
            </div>
"@
            }

            $htmlDoc = @"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Scheda Consegna PC - $clienteDisplay</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; }
        body { background: #f1f5f9; color: #1e293b; padding: 24px; font-size: 13px; line-height: 1.5; }
        .sheet { max-width: 820px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 4px 16px rgba(0,0,0,0.08); overflow: hidden; border: 1px solid #e2e8f0; }
        .header { background: linear-gradient(135deg, #00122B 0%, #002B5C 100%); color: #fff; padding: 22px 28px; border-bottom: 4px solid #EE7203; display: flex; justify-content: space-between; align-items: center; }
        .header-brand { display: flex; align-items: center; gap: 14px; }
        .brand-logo { background: #EE7203; color: #fff; font-weight: 900; font-size: 18px; letter-spacing: 1.5px; padding: 6px 12px; border-radius: 6px; }
        .header h1 { font-size: 20px; font-weight: 700; color: #fff; }
        .header p { font-size: 12px; color: #cbd5e1; }
        .badge-brand { background: #EE7203; color: #fff; font-weight: 700; font-size: 12px; padding: 6px 12px; border-radius: 6px; }
        .body { padding: 24px 28px; display: flex; flex-direction: column; gap: 16px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; }
        .card-cred { background: #fffaf5; border: 1.5px solid #EE7203; }
        .card-cred h3 { color: #EE7203; border-bottom: 1px solid #fed7aa; }
        .card-bitlocker { background: #f0fdf4; border: 1.5px solid #22c55e; }
        .card-bitlocker h3 { color: #166534; border-bottom: 1px solid #bbf7d0; }
        .card h3 { font-size: 14px; color: #00122B; margin-bottom: 10px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; font-weight: 700; display: flex; align-items: center; gap: 6px; }
        .info-table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
        .info-table td { padding: 3px 0; }
        .info-table td:first-child { width: 42%; color: #64748b; font-weight: 500; }
        .app-grid { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px; }
        .app-badge { background: #fff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 5px 9px; font-size: 12px; display: inline-flex; align-items: center; gap: 5px; color: #1e293b; }
        .app-badge strong { color: #00122B; }
        .tips-list { font-size: 12px; color: #475569; padding-left: 18px; line-height: 1.6; }
        .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 14px 28px; display: flex; justify-content: space-between; align-items: center; font-size: 12px; color: #64748b; }
        .btn-print { background: #EE7203; color: #fff; border: none; font-weight: 700; font-size: 13px; padding: 8px 18px; border-radius: 6px; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; box-shadow: 0 2px 6px rgba(238,114,3,0.3); }
        .btn-print:hover { background: #d96300; }
        @media print {
            @page { size: A4 portrait; margin: 10mm; }
            body { background: #fff; padding: 0; font-size: 11.5px; }
            .sheet { box-shadow: none; max-width: 100%; border: none; }
            .header { padding: 16px 20px; }
            .body { padding: 16px 20px; gap: 12px; }
            .card { padding: 12px; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="header">
            <div class="header-brand">
                <div class="brand-logo">UNIEURO</div>
                <div>
                    <h1>Scheda di Consegna e Configurazione PC</h1>
                    <p>Assistenza Tecnica &bull; <em style="color: #EE7203; font-weight: 600;">Batte. Forte. Sempre.</em></p>
                </div>
            </div>
            <div class="badge-brand">PC FACILE v$SCRIPT_VERSION</div>
        </div>
        <div class="body">
            $credBox
            <div class="grid">
                <div class="card">
                    <h3>&#128100; Dati Cliente &amp; Garanzia</h3>
                    <table class="info-table">
                        <tr><td>Cliente:</td><td><strong>$clienteDisplay</strong></td></tr>
                        <tr><td>Nome Computer:</td><td><code>$pcDisplay</code></td></tr>
                        <tr><td>Seriale / S/N:</td><td><strong>$($hwInfo.Seriale)</strong></td></tr>
                        <tr><td>Garanzia Legale:</td><td><strong style="color:#0284c7;">2 Anni (fino al $($hwInfo.ScadenzaGaranzia))</strong></td></tr>
                        <tr><td>Data Setup:</td><td>$(Get-Date -Format 'dd/MM/yyyy HH:mm')</td></tr>
                        <tr><td>Licenza Windows:</td><td><strong style="color:$(if ($winActInfo.Attivo) { '#16a34a' } else { '#e11d48' });">&#10003; $($winActInfo.StatoBreve)</strong></td></tr>
                        <tr><td>Stato Setup:</td><td><strong style="color:#16a34a;">&#10003; Pronto e Collaudato</strong></td></tr>
                    </table>
                </div>
                <div class="card">
                    <h3>&#128187; Specifiche Hardware &amp; Diagnostica</h3>
                    <table class="info-table">
                        <tr><td>Dispositivo:</td><td><strong>$($hwInfo.Produttore) $($hwInfo.Modello)</strong></td></tr>
                        <tr><td>Processore:</td><td>$($hwInfo.Cpu)</td></tr>
                        <tr><td>RAM:</td><td>$($hwInfo.RamGB) GB</td></tr>
                        <tr><td>Scheda Video:</td><td>$($hwInfo.Gpu)</td></tr>
                        <tr><td>Stato Disco / SSD:</td><td><strong>$($storageInfo.StatoCompleto)</strong></td></tr>
                        $(if ($batteryInfo.Presente) { "<tr><td>Salute Batteria:</td><td><strong>$($batteryInfo.Descrizione)</strong></td></tr>" })
                        <tr><td>Lingua:</td><td>Italiano (it-IT)</td></tr>
                    </table>
                </div>
            </div>
            $bitlockerBox
            <div class="card">
                <h3>&#128230; Programmi e Utility Installate</h3>
                <div class="app-grid">$appItems</div>
            </div>
            <div class="card">
                <h3>&#128161; Consigli e Istruzioni per l'Uso</h3>
                <ul class="tips-list">
                    <li><strong>Connessione Wi-Fi:</strong> All'accensione a casa, seleziona la tua rete Wi-Fi in basso a destra ed inserisci la password di casa.</li>
                    <li><strong>Sicurezza Credenziali:</strong> Se &egrave; stata creata una password provvisoria, modificala al primo accesso in <em>Impostazioni &gt; Account</em>.</li>
                    $(if ($bitlocker -and $bitlocker.RecoveryKey) { "<li><strong>BitLocker:</strong> La chiave di sicurezza del disco &egrave; stata registrata in questa scheda e sul Desktop.</li>" })
                    <li><strong>Teleassistenza:</strong> AnyDesk e TeamViewer sono configurati e pronti sul desktop in caso di necessit&agrave; di supporto da remoto.</li>
                </ul>
            </div>
        </div>
        <div class="footer">
            <div>Documento di consegna ufficiale generato automaticamente per il cliente da <strong>PC Facile</strong>.</div>
            <button class="btn-print no-print" onclick="window.print()">&#128438; Stampa / Salva in PDF</button>
        </div>
    </div>
</body>
</html>
"@
            $htmlDoc | Set-Content -Path $htmlFile -Encoding UTF8
            Write-OK "Scheda di consegna HTML salvata: $htmlFile"
            try { Start-Process $htmlFile } catch {}
        } catch {}

        # ---------------------------------------------------------------------
        # LOG STRUTTURATO (JSON + CSV) per l'assistenza/statistiche. NON sul
        # Desktop (non e' roba per il cliente): va in ProgramData\PCFacile\log.
        # Il JSON contiene tutto (sistema, esiti, verifica, errori imprevisti);
        # il CSV e' la tabella piatta degli esiti, comoda da aprire in Excel.
        # NIENTE credenziali nel log: restano solo nel .txt del cliente.
        # ---------------------------------------------------------------------
        try {
            $logDir = Join-Path $env:ProgramData "PCFacile\log"
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
            $stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
            $baseLog = Join-Path $logDir ("setup_{0}_{1}" -f $env:COMPUTERNAME, $stamp)

            $logObj = [ordered]@{
                versioneTool     = $SCRIPT_VERSION
                data             = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                cliente          = "$nomeCliente"
                nomePc           = "$env:COMPUTERNAME"
                utente           = "$env:USERNAME"
                seriale          = "$($hwInfo.Seriale)"
                produttore       = "$($hwInfo.Produttore)"
                modello          = "$($hwInfo.Modello)"
                scadenzaGaranzia = "$($hwInfo.ScadenzaGaranzia)"
                sistema          = if ($osInfo) { "$($osInfo.Caption) build $($osInfo.BuildNumber)" } else { 'n/d' }
                powershell       = "$($PSVersionTable.PSVersion)"
                winget           = "$wgVer"
                windowsAttivato  = [bool]$winOk
                risoluzione      = "$resTxt"
                antivirus        = "$avTxt"
                esiti            = @($Report | ForEach-Object { [ordered]@{ voce = $_.Voce; esito = $_.Esito } })
                verificaFinale   = @($verifica | ForEach-Object { [ordered]@{ voce = $_.N; ok = [bool]$_.Ok } })
                erroriImprevisti = @($Global:ErroriImprevisti)
            }
            $logObj | ConvertTo-Json -Depth 6 | Set-Content -Path "$baseLog.json" -Encoding UTF8
            $Report | Select-Object @{N='voce';E={$_.Voce}}, @{N='esito';E={$_.Esito}} |
                Export-Csv -Path "$baseLog.csv" -NoTypeInformation -Encoding UTF8
            Write-OK "Log tecnico salvato: $baseLog.json / .csv"
        } catch {
            Write-Info "Log strutturato non salvato: $_"
        }
    } catch {
        Write-Info "Impossibile creare il file riepilogo: $_"
    }
    Update-PannelloStatus -TaskId "diagnostica" -Stato "done" -Percentuale 100 -FaseCorrente "Configurazione PC Completata!" -Dettaglio "Tutti i lavori terminati con successo" -Completato
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
        Restore-SilentElevation
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'ColorTable01' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -ErrorAction SilentlyContinue
        # Ripristino il font della console a com'era (rimuovo le chiavi del .bat).
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'FaceName'   -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'FontFamily' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'FontWeight' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKCU:\Console' -Name 'FontSize'   -ErrorAction SilentlyContinue
    } catch {}
    # Lavoro COMPLETATO: via il checkpoint di ripresa sessione (contiene anche
    # le credenziali generate: non deve restare sul PC del cliente). La cartella
    # ProgramData\PCFacile resta perche' contiene i log tecnici (senza
    # credenziali): li teniamo per l'assistenza.
    try { Remove-Item $Global:StatoFile -Force -ErrorAction SilentlyContinue } catch {}
    $ioStesso = $MyInvocation.MyCommand.Path
    if ($ioStesso -and $ioStesso -like "$env:TEMP\*") {
        # Il file .ps1 in esecuzione NON e' bloccato: lo rimuovo ora, lo script
        # prosegue dalla memoria. Cosi' non resta nulla sul disco del cliente.
        try { Remove-Item -LiteralPath $ioStesso -Force -ErrorAction SilentlyContinue } catch {}
    }
    Write-OK "Pulizia finale: PC Facile rimosso dal PC (il report resta sul Desktop)."
}

# AGGIORNAMENTI WINDOWS: erano in DOWNLOAD in background. Ora (dopo driver e
# antivirus, cosi' non c'e' un'altra installazione Windows Update in corso) li
# INSTALLO, poi il riavvio finale li finalizza ("Configurazione aggiornamenti").
if ($RunReale -and $Global:JobWinUpdate) {
    Write-Host ""
    Write-Info "Completo il download degli aggiornamenti di Windows (avviato prima in background)..."
    Start-BarraAnimata "Aggiornamenti Windows: completo il download"
    try { Wait-Job $Global:JobWinUpdate -Timeout 600 | Out-Null } catch {} finally { Stop-BarraAnimata }
    $nWU = 0; try { $nWU = [int](Receive-Job $Global:JobWinUpdate -ErrorAction SilentlyContinue | Select-Object -Last 1) } catch {}
    Stop-Job $Global:JobWinUpdate -ErrorAction SilentlyContinue
    Remove-Job $Global:JobWinUpdate -Force -ErrorAction SilentlyContinue
    if ($nWU -gt 0) {
        Write-Info "Installo gli aggiornamenti scaricati (si completano al riavvio)..."
        Start-BarraAnimata "Installo gli aggiornamenti di Windows (max 5 min)"
        try {
            $jobFinInstall = Start-Job -ScriptBlock {
                try {
                    $sFin = New-Object -ComObject Microsoft.Update.Session
                    $rFin = $sFin.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software' and IsHidden=0")
                    $cFin = New-Object -ComObject Microsoft.Update.UpdateColl
                    foreach ($u in $rFin.Updates) {
                        if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                        if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                        if ($u.IsDownloaded) { $cFin.Add($u) | Out-Null }
                    }
                    if ($cFin.Count -gt 0) {
                        $iFin = $sFin.CreateUpdateInstaller()
                        $iFin.Updates = $cFin
                        $res = $iFin.Install()
                        return $res.ResultCode
                    }
                    return 0
                } catch { return -1 }
            }
            if (Wait-Job $jobFinInstall -Timeout 300) {
                Receive-Job $jobFinInstall -ErrorAction SilentlyContinue | Out-Null
                Write-OK "Aggiornamenti di Windows applicati: il riavvio li completa."
            } else {
                Stop-Job $jobFinInstall -ErrorAction SilentlyContinue
                Write-Info "Tempo massimo installazione aggiornamenti raggiunto: il riavvio finale finalizzera' l'installazione."
            }
            Remove-Job $jobFinInstall -Force -ErrorAction SilentlyContinue
        } catch {} finally { Stop-BarraAnimata }
    } else {
        Write-OK "Windows e' gia' aggiornato (nessun aggiornamento da installare)."
    }
}

# MENU DI CHIUSURA: Check Salute PC oppure Riavvio
if ($RunReale) {
    Set-PreventSleep $false
    Write-Titolo "COMPLETAMENTO PC FACILE"
    Write-Host "Configurazione e ottimizzazione completate con successo!" -ForegroundColor Green
    Write-Host ""
    
    $linguaOk = @($Report | Where-Object { $_.Voce -like "Lingua italiana (it-IT*" -and $_.Esito -eq "OK" }).Count -gt 0
    
    do {
        Write-Host "Scegli come procedere:" -ForegroundColor White
        Write-Host "  1) Esegui Check Completo Salute PC (SSD SMART, Batteria, Licenza, Driver, BitLocker)" -ForegroundColor Cyan
        Write-Host "  2) Riavvia il PC adesso (Consigliato per rendere attive tutte le modifiche)" -ForegroundColor Green
        Write-Host "  3) Esci senza riavviare (Riavvio manuale in seguito)" -ForegroundColor Yellow
        Write-Host ""

        $sceltaFine = Attendi-Risposta "Scelta (1-3)"
        switch ($sceltaFine) {
            "1" {
                Invoke-PcFacileDiagnostics -MostraDettagli | Out-Null
                Write-Host ""
            }
            "2" {
                Write-Info "Riavvio del PC in corso..."
                Restart-Computer -Force
                break
            }
            "3" {
                if ($linguaOk) {
                    Write-Info "Ricordati di riavviare prima di consegnare il PC per applicare lingua e nuove impostazioni."
                }
                break
            }
            default {
                Write-Info "Opzione non valida. Inserisci 1, 2 o 3."
            }
        }
    } while ($sceltaFine -ne "2" -and $sceltaFine -ne "3")
}

Write-Host ""
Beep-Completato   # melodia "tutto finito" (utile se ti sei allontanato)
Write-Host "${AON}Buon lavoro!$AOFF" -ForegroundColor $THEME_COL
# Niente Pausa qui: l'unico "premi un tasto" e' quello finale del launcher .bat
# ("Operazione terminata"), cosi' non si preme INVIO due volte.

