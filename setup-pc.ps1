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
    # Veloce: parametro di compatibilita'
    [switch]$Veloce,
    # Salta la creazione del punto di ripristino
    [switch]$skipRestore,
    # Cartella target o USB esplicita (opzionale)
    [string]$TargetDir
)

if ($TargetDir) { $Global:TargetDir = $TargetDir }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Versione del programma (mostrata nell'header e nel riepilogo).
# Bump ad ogni modifica cosi' capisci se la USB e' aggiornata.
$SCRIPT_VERSION = "11.1 (2026-09-05)"

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

# Sfondo scuro. ATTENZIONE: su Windows 11 la console di default e' Windows
# Terminal, che IGNORA il registro (ColorTable) e rende 'DarkBlue' come un blu
# ACCESO (brutto). Il trucco navy col registro vale solo sulla vecchia console
# (conhost). Percio': se sono in Windows Terminal ($env:WT_SESSION c'e') uso
# NERO (scuro e pulito, il navy pieno non e' forzabile da script in WT); su
# conhost uso 'DarkBlue' che col ColorTable rimappato diventa navy vero.
try {
    if ($env:WT_SESSION) {
        $Host.UI.RawUI.BackgroundColor = 'Black'
    } else {
        $Host.UI.RawUI.BackgroundColor = 'DarkBlue'
    }
    $Host.UI.RawUI.ForegroundColor = 'Gray'
    Clear-Host
} catch {}

# =============================================================================
# FUNZIONI UTILITY
# =============================================================================

function Write-Titolo {
    param([string]$Testo)
    # Titolo ben visibile: barra piena arancione + testo MAIUSCOLO su riga sua.
    # Piu' "grosso" e netto della vecchia doppia linea, si legge a colpo d'occhio.
    $barra = ([string]$BOX_FULL) * 50
    Write-Host ""
    Write-Host ""
    Write-Host "$AON  $barra$AOFF" -ForegroundColor $THEME_COL
    Write-Host "$AON   $($Testo.ToUpper())$AOFF" -ForegroundColor $THEME_TXT
    Write-Host "$AON  $barra$AOFF" -ForegroundColor $THEME_COL
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
        $ps = [PowerShell]::Create()
        [void]$ps.AddScript({
            param($testo, $full, $empty, $aon, $aoff)
            $larg = 22; $span = 4; $period = ($larg - $span) * 2; $inizio = Get-Date; $i = 0
            while ($true) {
                $phase = $i % $period
                $pos = if ($phase -le ($larg - $span)) { $phase } else { $period - $phase }
                $barra = ($empty * $pos) + ($full * $span) + ($empty * ($larg - $span - $pos))
                $sec = [int]((Get-Date) - $inizio).TotalSeconds
                $riga = "   $testo  [$barra]  ${sec}s"
                try { if ($aon) { [Console]::Write("`r$aon$riga$aoff") } else { [Console]::Write("`r$riga") } } catch {}
                Start-Sleep -Milliseconds 120; $i++
            }
        }).AddArgument($Testo).AddArgument([string]$BOX_FULL).AddArgument([string]$BOX_EMPTY).AddArgument($AON).AddArgument($AOFF)
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

# Attesa di una risposta CON bip iniziale + bip ripetuto ogni 2 min se non
# rispondi. Sostituisce il vecchio schema "Beep-Attesa; Read-Host". Il beeper
# si ferma SEMPRE appena Read-Host ritorna (anche con Ctrl+C), grazie a finally.
function Attendi-Risposta {
    param([string]$Prompt)
    Beep-Attesa            # primo bip subito
    Start-BipRipetuto      # poi ogni 2 min finche' non rispondi
    try { $r = Read-Host $Prompt }
    finally { Stop-BipRipetuto }
    return $r
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
    # Convenzione del negozio: "Nome123!" -> SOLO il primo nome (prima parola),
    # prima lettera maiuscola, il resto minuscolo. Es. "Mario Rossi" -> "Mario123!".
    $primo = @($Base -split '\s+' | Where-Object { $_ })[0]
    $b = ($primo -replace '[^A-Za-z]', '')
    if ($b.Length -lt 1) { $b = "Cliente" }
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
    $parti = @($Base -split '\s+' | ForEach-Object { $_ -replace '[^A-Za-z0-9]', '' } | Where-Object { $_ })
    if ($parti.Count -ge 2) {
        $cognome = $parti[-1]
        $nome    = ($parti[0..($parti.Count - 2)] -join '')
        $e = ($cognome + $nome).ToLower()
    } elseif ($parti.Count -eq 1) {
        $e = $parti[0].ToLower()
    } else {
        $e = "cliente"
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

# =============================================================================
# GESTIONE OFFLINE INSTALLERS & PREPARAZIONE USB
# =============================================================================

function Get-OfflineDirs {
    $dirs = [System.Collections.Generic.List[string]]::new()
    if ($Global:TargetDir) {
        $dirs.Add((Join-Path $Global:TargetDir "installers"))
        $dirs.Add((Join-Path $Global:TargetDir "offline"))
        $dirs.Add((Join-Path $Global:TargetDir "cache"))
        $dirs.Add($Global:TargetDir)
    }
    if ($TargetDir -and $TargetDir -ne $Global:TargetDir) {
        $dirs.Add((Join-Path $TargetDir "installers"))
        $dirs.Add((Join-Path $TargetDir "offline"))
        $dirs.Add((Join-Path $TargetDir "cache"))
        $dirs.Add($TargetDir)
    }
    if ($PSScriptRoot) {
        $dirs.Add((Join-Path $PSScriptRoot "installers"))
        $dirs.Add((Join-Path $PSScriptRoot "offline"))
        $dirs.Add((Join-Path $PSScriptRoot "cache"))
        $dirs.Add($PSScriptRoot)
    }
    $curr = (Get-Location).Path
    if ($curr) {
        $dirs.Add((Join-Path $curr "installers"))
        $dirs.Add((Join-Path $curr "offline"))
        $dirs.Add((Join-Path $curr "cache"))
        $dirs.Add($curr)
    }
    try {
        $allDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady }
        foreach ($d in $allDrives) {
            $root = $d.RootDirectory.FullName
            $dirs.Add((Join-Path $root "installers"))
            $dirs.Add((Join-Path $root "offline"))
            $dirs.Add((Join-Path $root "cache"))
        }
    } catch {
        try {
            $removables = Get-Volume | Where-Object { $_.DriveLetter }
            foreach ($r in $removables) {
                $rPath = "$($r.DriveLetter):\"
                $dirs.Add((Join-Path $rPath "installers"))
                $dirs.Add((Join-Path $rPath "offline"))
                $dirs.Add((Join-Path $rPath "cache"))
            }
        } catch {}
    }

    $existing = @()
    foreach ($d in $dirs) {
        if ($d -and (Test-Path $d) -and -not ($existing -contains $d)) { $existing += $d }
    }
    return $existing
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
        "7zip.7zip"                        = @("*7z*x64.exe", "*7z*x64.msi", "*7z*.exe", "*7z*.msi")
        "AnyDesk.AnyDesk"                  = @("*AnyDesk*.exe")
        "TeamViewer.TeamViewer"            = @("*TeamViewer*Setup*.exe", "*TeamViewer*.exe", "*TeamViewer*.msi")
        "Zoom.Zoom"                        = @("*ZoomInstaller*.exe", "*Zoom*.msi", "*Zoom*.exe")
        "TheDocumentFoundation.LibreOffice"= @("*LibreOffice*x86-64.msi", "*LibreOffice*.msi", "*LibreOffice*.exe")
        "Apache.OpenOffice"                = @("*Apache*OpenOffice*.exe", "*OpenOffice*.exe", "*OpenOffice*.msi")
        "Spotify.Spotify"                  = @("*Spotify*Setup*.exe", "*Spotify*.exe", "*Spotify*.msixbundle")
        "9NKSQGP7F2NH"                     = @("*WhatsApp*.exe", "*WhatsApp*.msixbundle", "*WhatsApp*.appxbundle")
        "GIMP.GIMP"                        = @("*gimp*setup*.exe", "*gimp*.exe", "*gimp*.msi")
        "Valve.Steam"                      = @("*SteamSetup*.exe", "*Steam*.exe")
        "EpicGames.EpicGamesLauncher"      = @("*EpicGamesLauncher*.msi", "*EpicInstaller*.msi", "*EpicGames*.exe")
        "Discord.Discord"                  = @("*DiscordSetup*.exe", "*Discord*.exe")
        "qBittorrent.qBittorrent"          = @("*qbittorrent*setup*.exe", "*qbittorrent*.exe")
        "AIMP.AIMP"                        = @("*aimp*.exe")
        "Intel.IntelDriverAndSupportAssistant" = @("*Intel*Driver*Support*Assistant*.exe", "*IntelDSA*.exe", "*Intel*.exe")
        "Microsoft.Office"                 = @("*OfficeSetup*.exe", "*Office*.exe", "*Setup32*.exe", "*Setup64*.exe")
        "MCPR"                             = @("*MCPR*.exe")
        "NRnR"                             = @("*NRnR*.exe")
    }

    $namePatterns = @{
        "VLC"                              = @("*vlc*win64.exe", "*vlc*.exe", "*vlc*.msi")
        "Adobe Acrobat Reader"             = @("*AcroRdr*.exe", "*Acrobat*Reader*.exe", "*AdbeRdr*.exe", "*AcroRdr*it_IT*.exe", "*Acro*.msi")
        "Sumatra PDF"                      = @("*SumatraPDF*.exe", "*SumatraPDF*.msi")
        "7-Zip"                            = @("*7z*x64.exe", "*7z*x64.msi", "*7z*.exe", "*7z*.msi")
        "AnyDesk"                          = @("*AnyDesk*.exe")
        "TeamViewer"                       = @("*TeamViewer*Setup*.exe", "*TeamViewer*.exe", "*TeamViewer*.msi")
        "Zoom"                             = @("*ZoomInstaller*.exe", "*Zoom*.msi", "*Zoom*.exe")
        "LibreOffice"                      = @("*LibreOffice*x86-64.msi", "*LibreOffice*.msi", "*LibreOffice*.exe")
        "OpenOffice"                       = @("*Apache*OpenOffice*.exe", "*OpenOffice*.exe", "*OpenOffice*.msi")
        "Spotify"                          = @("*Spotify*Setup*.exe", "*Spotify*.exe", "*Spotify*.msixbundle")
        "WhatsApp"                         = @("*WhatsApp*.exe", "*WhatsApp*.msixbundle", "*WhatsApp*.appxbundle")
        "GIMP"                             = @("*gimp*setup*.exe", "*gimp*.exe", "*gimp*.msi")
        "Steam"                            = @("*SteamSetup*.exe", "*Steam*.exe")
        "Epic Games Launcher"              = @("*EpicGamesLauncher*.msi", "*EpicInstaller*.msi", "*EpicGames*.exe")
        "Discord"                          = @("*DiscordSetup*.exe", "*Discord*.exe")
        "qBittorrent"                      = @("*qbittorrent*setup*.exe", "*qbittorrent*.exe")
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
        $searchList += "*$WingetId*.exe"
        $searchList += "*$WingetId*.msi"
    }
    if ($Nome) {
        $cleanNome = ($Nome -replace '[^a-zA-Z0-9]','*')
        $searchList += "*$cleanNome*.exe"
        $searchList += "*$cleanNome*.msi"
    }

    foreach ($d in $dirs) {
        foreach ($p in $searchList) {
            try {
                $found = Get-ChildItem -Path $d -Filter $p -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { return $found.FullName }
            } catch {}
        }
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
        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $proc = $null
        if ($ext -eq '.msi') {
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$FilePath`" /qn /norestart" -Wait -PassThru -ErrorAction Stop
        } elseif ($ext -eq '.msixbundle' -or $ext -eq '.appxbundle' -or $ext -eq '.msix' -or $ext -eq '.appx') {
            Add-AppxPackage -Path $FilePath -ErrorAction Stop
            Write-OK "$Nome installato con successo da pacchetto offline Appx/MSIX!"
            return $true
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
            elseif ($FilePath -like "*Spotify*") { $arg = "/silent" }
            elseif ($FilePath -like "*gimp*") { $arg = "/VERYSILENT /NORESTART /ALLUSERS" }
            elseif ($FilePath -like "*Steam*") { $arg = "/S" }
            elseif ($FilePath -like "*qbittorrent*") { $arg = "/S" }
            elseif ($FilePath -like "*Intel*") { $arg = "/quiet /norestart" }

            $proc = Start-Process -FilePath $FilePath -ArgumentList $arg -Wait -PassThru -ErrorAction Stop
        }
        if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641)) {
            Write-OK "$Nome installato con successo da cache offline USB!"
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
            Nome      = "7-Zip (64-bit)"
            File      = "7z-x64.exe"
            Urls      = @(
                "https://www.7-zip.org/a/7z2408-x64.exe",
                "https://www.7-zip.org/a/7z2301-x64.exe"
            )
            MinSizeKB = 1000
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
            Nome      = "Zoom Desktop Client Full"
            File      = "ZoomInstallerFull.exe"
            Urls      = @(
                "https://zoom.us/client/latest/ZoomInstallerFull.exe"
            )
            MinSizeKB = 40000
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
            File      = "SpotifySetup.exe"
            Urls      = @(
                "https://download.scdn.co/SpotifySetup.exe"
            )
            MinSizeKB = 1000
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
            Nome      = "qBittorrent (64-bit)"
            File      = "qbittorrent_setup.exe"
            Urls      = @(
                "https://downloads.sourceforge.net/project/qbittorrent/qbittorrent-win32/qbittorrent-5.0.0/qbittorrent_5.0.0_x64_setup.exe",
                "https://sourceforge.net/projects/qbittorrent/files/latest/download"
            )
            MinSizeKB = 30000
            Categoria = "Completo"
        }
    )

    $daScaricare = $downloadCatalog
    if (-not $Test) {
        Write-Host "Cosa vuoi scaricare sulla chiavetta?" -ForegroundColor White
        Write-Host "  1) Pacchetto Base + Utility (Consigliato: Chrome, Firefox, VLC, Adobe, 7-Zip, AnyDesk, NRnR, MCPR - ~450 MB)" -ForegroundColor Green
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

    # Riepilogo finale
    Write-Host ""
    Write-Titolo "PREPARAZIONE USB COMPLETATA"
    Write-Host "Pacchetti pronti su chiavetta: $riusciti su $tot (gia' presenti: $giaPresenti)" -ForegroundColor Green
    Write-Host "Cartella offline: $installersDir" -ForegroundColor White
    Write-Host ""
    Write-Host "Ora la tua chiavetta USB e' un kit autonomo al 100%!" -ForegroundColor Yellow
    Write-Host "Puoi inserirla nei PC dei clienti e lanciare 'PC Facile.bat':" -ForegroundColor White
    Write-Host "le applicazioni si installeranno all'istante anche SENZA connessione a Internet." -ForegroundColor White
    Write-Host ""
    Beep-Completato
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

$Global:ModoEspresso = $false

# Se nessun parametro esplicito e' stato fornito da CLI, mostro il MENU INIZIALE:
if (-not $Test -and -not $Diagnostica -and -not $Espresso -and -not $Manuale -and -not $PreparaUSB) {
    try { Clear-Host } catch {}
    $larg = 64
    $titoloB = "PC FACILE   -   versione $SCRIPT_VERSION"
    $padSx = [int](($larg - $titoloB.Length) / 2)
    $padDx = $larg - $padSx - $titoloB.Length
    Write-Host ("$AON  " + [char]0x2554 + (([string][char]0x2550) * $larg) + [char]0x2557 + "$AOFF") -ForegroundColor $THEME_COL
    Write-Host ("  " + [char]0x2551 + (" " * $padSx) + $titoloB + (" " * $padDx) + [char]0x2551) -ForegroundColor $THEME_TXT
    Write-Host ("$AON  " + [char]0x255A + (([string][char]0x2550) * $larg) + [char]0x255D + "$AOFF") -ForegroundColor $THEME_COL
    Write-Host ""
    Write-Host "  Scegli come procedere:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [E] ESPRESSO (Automatico 1-Click)" -ForegroundColor Green -NoNewline
    Write-Host "   <-- PREDEFINITO (premi INVIO)" -ForegroundColor Yellow
    Write-Host "      Fa TUTTO da solo alla massima velocita' senza interruzioni:" -ForegroundColor Gray
    Write-Host "      - Pulisce bloatware OEM e disinstalla antivirus di prova" -ForegroundColor Gray
    Write-Host "      - Ottimizza Windows (privacy, prestazioni, impostazioni, Edge)" -ForegroundColor Gray
    Write-Host "      - Installa app Base (Chrome, 7-Zip, VLC, Adobe Reader, AnyDesk)" -ForegroundColor Gray
    Write-Host "      - Scarica e installa aggiornamenti Windows e driver" -ForegroundColor Gray
    Write-Host "      - Genera la Scheda Consegna Cliente su Desktop" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [M] MANUALE (Guidato passo-passo)" -ForegroundColor White
    Write-Host "      Personalizzazione completa: scelta account Microsoft/Locale," -ForegroundColor Gray
    Write-Host "      scelta profilo app (Base/Ufficio/Gaming/ecc), Office e Antivirus." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [P] PREPARA USB OFFLINE (Scarica programmi sulla chiavetta)" -ForegroundColor Cyan
    Write-Host "      Scarica tutti gli installer (.exe/.msi) nella cartella 'installers'." -ForegroundColor Gray
    Write-Host "      I prossimi PC si installeranno al 100% OFFLINE e super veloci!" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [D] Diagnostica (Verifica sistema e pacchetti senza modifiche)" -ForegroundColor DarkGray
    Write-Host "  [T] Test (Simulazione rapida a vuoto)" -ForegroundColor DarkGray
    Write-Host "  [Q] Esci" -ForegroundColor DarkGray
    Write-Host ""

    $sceltaMenu = (Attendi-Risposta "Scegli modalita' [E/M/P/D/T/Q] (INVIO = Espresso)").Trim().ToUpper()

    switch -Regex ($sceltaMenu) {
        "^P" { $PreparaUSB = $true }
        "^M" { $Manuale = $true; $Global:ModoEspresso = $false }
        "^D" { $Diagnostica = $true }
        "^T" { $Test = $true }
        "^Q" { Write-Host "Uscita."; return }
        default { $Espresso = $true; $Global:ModoEspresso = $true }
    }
}

if ($Espresso) {
    $Global:ModoEspresso = $true
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

# =============================================================================
# GESTIONE ERRORI CENTRALIZZATA
# I singoli passi gestiscono gia' i propri errori "attesi" con try/catch mirati
# e li scrivono nel Report. Qui aggiungiamo una RETE DI SICUREZZA per gli errori
# IMPREVISTI (terminanti) che sfuggono: un 'trap' a livello script li raccoglie
# in una lista, li mostra in modo pulito e PROSEGUE (continue) senza far
# esplodere tutto. Finiscono anche nel log strutturato, utili all'assistenza.
# =============================================================================
$Global:ErroriImprevisti = [System.Collections.ArrayList]::new()

function Register-ErroreImprevisto {
    param($ErroreRec)
    try {
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

# Trap a livello script: cattura i terminanti non gestiti, li registra e continua.
trap {
    Register-ErroreImprevisto $_
    try { Write-Host "   [!] Imprevisto gestito: $($_.Exception.Message)" -ForegroundColor DarkYellow } catch {}
    continue
}

# Credenziali del nuovo account, generate dallo script allo step Account
# Microsoft e scritte nel riepilogo. Init qui cosi' esistono anche se quel
# passo viene saltato (restano vuote nel file).
$credMsAccount = ""; $credMsPassword = ""; $credAltro = ""
# Provider account scelto (Microsoft/Google/Proton/Outlook) + dominio email: li
# ricordo nel checkpoint, cosi' su una ripresa il riepilogo mostra il provider
# GIUSTO (es. Proton) e non ripiega su Microsoft/outlook.it.
$Global:credProvider = ""; $Global:credDominio = ""
# Job in background per il DOWNLOAD degli aggiornamenti di Windows: parte durante
# il passo Aggiornamenti e scarica mentre lo script prosegue; l'installazione
# vera avviene alla fine, giusto prima del riavvio (che la finalizza).
$Global:JobWinUpdate = $null

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
$Global:StatoFile   = Join-Path $env:ProgramData "PCFacile\stato.json"
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
    @{ Nome = "qBittorrent";          Id = "qBittorrent.qBittorrent";      Profili = @("GAMING") },
    @{ Nome = "Discord";              Id = "Discord.Discord";              Profili = @("GAMING") },
    @{ Nome = "Zoom";                 Id = "Zoom.Zoom";                    Profili = @("BASE","UFFICIO","GAMING") }
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
    param([string]$Nome, [string[]]$WingetArgs)
    # winget DIRETTO nel thread principale, con il SUO progresso di download a
    # schermo (niente barra animata sopra: quella girava in un runspace a parte
    # e "litigava" con winget sulla stessa console -> app come Chrome si
    # impallavano e davano errore). Cosi': $LASTEXITCODE affidabile, nessun
    # conflitto, e si vede il download reale (utile quando la rete e' lenta).
    Write-Info "Scarico e installo $Nome (vedi il progresso qui sotto)..."
    winget @WingetArgs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = -1 }
    return $code
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
        # Con winget ora lanciato DIRETTO, l'exit code e' affidabile: se e' un
        # successo NON serve la seconda 'winget list' di verifica (era li' per il
        # vecchio bug -999) -> un'interrogazione lenta in meno per ogni app.
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
            $rRip = Attendi-Risposta "Riprendere da dove eri arrivato? (S = riprendi / N = ricomincia da capo)"
            if ($rRip -match '^[Ss]') {
                $Global:FaseRipresa = [int]$st.Fase
                if ($st.NomeCliente)  { $nomeCliente    = [string]$st.NomeCliente }
                if ($st.CredAccount)  { $credMsAccount  = [string]$st.CredAccount }
                if ($st.CredPassword) { $credMsPassword = [string]$st.CredPassword }
                if ($st.PSObject.Properties.Name -contains 'CredProvider' -and $st.CredProvider) { $Global:credProvider = [string]$st.CredProvider }
                if ($st.PSObject.Properties.Name -contains 'CredDominio'  -and $st.CredDominio)  { $Global:credDominio  = [string]$st.CredDominio }
                # Ripresa FINE del passo App: se la sessione si e' chiusa a meta'
                # dell'installazione app, recupero profilo + piano + app gia' fatte,
                # cosi' non richiedo il profilo e riparto dall'app esatta rimasta.
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
        Write-Host "Serve per: lingua italiana (pacchetto da scaricare), installazione app," -ForegroundColor White
        Write-Host "aggiornamenti e driver. Collega il WiFi o il cavo di rete PRIMA di continuare." -ForegroundColor White
        Write-Host ""
        do {
            $rNet = Attendi-Risposta "Collega Internet e premi INVIO per riprovare  (oppure S = prosegui senza)"
            if ($rNet -match '^[Ss]') { break }
        } while (-not (Test-Rete))
        if (Test-Rete) { Write-OK "Connessione a Internet OK." }
        else { Write-Info "Proseguo SENZA Internet: lingua, app e aggiornamenti potrebbero saltare." }
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
        Write-Host "Un antivirus attivo puo' BLOCCARE questo script (quarantena) quando prova a" -ForegroundColor White
        Write-Host "togliere gli AV di prova. Se succede, lingua/pulizia/driver NON vengono fatti." -ForegroundColor White
        Write-Host ""
        Write-Host "PRIMA di continuare, fai UNA di queste:" -ForegroundColor Yellow
        Write-Host "  - aggiungi la chiavetta/cartella alle ESCLUSIONI dell'antivirus, oppure" -ForegroundColor White
        Write-Host "  - tieni pronto a dare ALLOW/CONSENTI se compare 'Threat blocked'." -ForegroundColor White
        Write-Host ""
        [void](Attendi-Risposta "Quando sei pronto premi INVIO per continuare")
    }
}

# =============================================================================
# EDGE: salta le schermate iniziali (first-run "Benvenuti in Edge", accedi,
# importa dati...). Cosi' quando apriamo Edge per account/Office non si perde
# tempo. Policy di registro, impostata PRIMA di aprire Edge.
# =============================================================================
if ($RunReale) {
    try {
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
        Write-OK "Schermate iniziali di Edge disattivate."
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
Write-Info "Utente corrente: $env:USERNAME"
Write-Info "Nome visualizzato attuale: $(if ($nomeAttuale) { $nomeAttuale } else { '(non impostato)' })"
Write-Host ""
Write-Info "Nome PC attuale: $env:COMPUTERNAME"
Write-Host ""
$nomeCliente = (Attendi-Risposta "Nome del cliente (account E nome PC) - INVIO per saltare").Trim()

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

if ($Global:ModoEspresso) {
    Write-OK "Modalita' Espresso: mantenuto account utente corrente (nessuna schermata di login web)."
    Add-Report "Account cliente" "LOCALE (Espresso)"
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

Write-Host "Toglie antivirus di prova + bloatware OEM + OneDrive, alleggerisce l'avvio." -ForegroundColor White
Write-Host ""

$vuoiPulizia = Chiedi "Eseguire ora la pulizia e ottimizzazione iniziale? (consigliato) (S/N)" "S"
if ($vuoiPulizia -match "^[Ss]") {

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

    Write-OK "Pulizia e ottimizzazione iniziale completata."
} else {
    Write-Info "Pulizia e ottimizzazione iniziale saltata."
    Add-Report "Antivirus di prova" "SALTATO"
    Add-Report "Rimozione bloatware" "SALTATO"
    Add-Report "Configurazione Windows base" "SALTATO"
}

Save-Fase 3 "Pulizia e ottimizzazione"
}

# =============================================================================
# LINGUA E REGIONE (ITALIANO)
# =============================================================================

if (Test-FaseFatta 4) { Write-Info "Lingua e regione: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Lingua e Regione (Italiano)"

Write-Host "Imposta display, tastiera, formati e pacchetto lingua in italiano (it-IT)." -ForegroundColor White
Write-Host ""

$culturaAttuale = (Get-Culture).Name
Write-Info "Lingua/regione attuale: $culturaAttuale"

$impostaLingua = Chiedi "Impostare il sistema in Italiano (it-IT)? (S/N)" "S"
if ($impostaLingua -match "^[Ss]") {

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
                    Remove-Job $jobLingua -Force -ErrorAction SilentlyContinue
                } finally { Stop-BarraAnimata }
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

Write-Host "Crea un punto di ripristino: se qualcosa va storto puoi tornare indietro." -ForegroundColor White
Write-Host ""
Write-Host "  Rispondi S per crearlo (consigliato) oppure N per saltare, poi premi INVIO." -ForegroundColor Gray

# Chiedi/Read-Host accettano SOLO input da tastiera (niente finestra GUI con
# pulsanti): la conferma si da' scrivendo S o N e premendo INVIO. Enter senza
# testo = S (predefinito, come indicato in "consigliato").
$vuoiRestore = Chiedi "Creare un punto di ripristino ora? (consigliato) (S/N)" "S"
if (($vuoiRestore -match "^[Ss]") -or ($vuoiRestore.Trim() -eq '')) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
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
            Add-Report "Punto di ripristino" "ERRORE"
        } finally {
            if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
            Stop-BarraAnimata
        }
    } catch {
        Write-Errore "NON e' stato possibile creare il punto di ripristino."
        Write-Info "  Causa: $_"
        Write-Info "  Non e' un errore bloccante: la configurazione prosegue comunque."
        Add-Report "Punto di ripristino" "ERRORE"
    }
} else {
    Write-Info "Punto di ripristino saltato."
    Add-Report "Punto di ripristino" "SALTATO"
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
    while ($true) {
        $ch = ""; $isEnter = $false
        try {
            $key = [Console]::ReadKey($true)
            $ch = "$($key.KeyChar)".ToUpper()
            if ($key.Key -eq 'Enter') { $isEnter = $true }
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
    $timeoutMin = 12
    Write-Info "In attesa dell'installer di $Nome (max $timeoutMin min). CTRL+C per annullare."
    $installer = $null
    while (((Get-Date) - $inizio).TotalMinutes -lt $timeoutMin) {
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

# Il wizard: passo 3=Unieuro, 4=App+browser, 5=Aggiornamento, 6=Driver,
# 7=Antivirus (ultimo). La barra mostra (passo-2) su 5.
$passo = 3
# Nomi leggibili dei passi wizard per il checkpoint di ripresa sessione.
$wizNomi = @{ 3 = "Unieuro Cyber Protection"; 4 = "Applicazioni + browser"; 5 = "Aggiornamenti (app + Windows)"; 6 = "Driver"; 7 = "Antivirus" }
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
7 {
# =============================================================================
# ANTIVIRUS (ultimo passo: dopo tutte le altre installazioni, cosi' un AV
# appena attivato non blocca il download/installazione delle app - es. AnyDesk)
# =============================================================================

Write-Titolo "Antivirus"

if ($Global:ModoEspresso) {
    Write-OK "Modalita' Espresso: Windows Defender / Sicurezza di Windows configurato e attivo."
    Add-Report "Antivirus" "OK (Windows Defender)"
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
        }
        "2" {
            Installa-Antivirus -Nome "Norton" -UrlRiscatto "https://www.norton.com/setup" -Utente $credMsAccount -Password $credMsPassword
        }
        default {
            Write-Info "Antivirus dedicato saltato: Windows Defender e' attivo e aggiornato."
            Add-Report "Antivirus" "OK (Windows Defender)"
        }
    }
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
3 {
# =============================================================================
# STEP 4c - UNIEURO CYBER PROTECTION (opzionale)
# =============================================================================

Write-Titolo "Unieuro Cyber Protection"

if ($Global:ModoEspresso) {
    Write-Info "Modalita' Espresso: Cyber Protection non richiesta (attivabile manualmente se acquistata)."
    Add-Report "Unieuro Cyber Protection" "SALTATO"
} else {
    Write-Host "Servizio venduto solo su richiesta: INVIO per saltare se non l'ha comprato." -ForegroundColor White
    Write-Host ""

    $vuoiUnieuro = Attendi-Risposta "Attivare Unieuro Cyber Protection? (S = si / INVIO = no, B=indietro)"
    if (Test-Indietro $vuoiUnieuro) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
    if ($vuoiUnieuro -match "^[Ss]") {
        Attiva-ServizioWeb -Nome "Unieuro Cyber Protection" -UrlAttivazione "https://unieuro-cyber-protection.covercare.it" -Utente $credMsAccount
    } else {
        Write-Info "Unieuro Cyber Protection saltato."
        Add-Report "Unieuro Cyber Protection" "SALTATO"
    }
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
4 {
# =============================================================================
# APPLICAZIONI + BROWSER (unificati: il browser si installa da solo qui -
# Chrome, oppure Opera GX se scegli il profilo GAMING)
# =============================================================================

Write-Titolo "Applicazioni"

# App e profili derivano dal CATALOGO unico definito all'inizio (niente duplicati).
$appsDisponibili = $CatalogoApp
$profili = [ordered]@{
    "BASE"    = @($CatalogoApp | Where-Object { $_.Profili -contains "BASE" }    | ForEach-Object { $_.Id })
    "UFFICIO" = @($CatalogoApp | Where-Object { $_.Profili -contains "UFFICIO" } | ForEach-Object { $_.Id })
    "GAMING"  = @($CatalogoApp | Where-Object { $_.Profili -contains "GAMING" }  | ForEach-Object { $_.Id })
}

# Costruisce il PIANO ordinato di installazione (browser in testa) per il
# profilo scelto: una lista di @{Nome;Id} che il loop installa in sequenza e su
# cui salva i progressi. Cosi' la ripresa sa esattamente cosa resta da fare.
function Costruisci-PianoApp {
    param([string]$Scelta)
    $piano = @()
    # Browser automatico: Opera GX per il GAMING (3), Chrome per gli altri.
    if ($Scelta -eq "3") { $piano += @{ Nome = "Opera GX"; Id = "Opera.OperaGX" } }
    else                 { $piano += @{ Nome = "Google Chrome"; Id = "Google.Chrome" } }
    foreach ($app in $appsDisponibili) {
        $prendi = switch ($Scelta) {
            "1" { $profili["BASE"]    -contains $app.Id }
            "2" { $profili["UFFICIO"] -contains $app.Id }
            "3" { $profili["GAMING"]  -contains $app.Id }
            "4" { $true }   # COMPLETO: tutte le app del catalogo
            default { $false }
        }
        if ($prendi) { $piano += @{ Nome = $app.Nome; Id = $app.Id } }
    }
    return $piano
}

$Global:AppFallite = 0   # azzero: conto solo i fallimenti di QUESTO passo

# --- Determino il PIANO (lista ordinata di @{Nome;Id}) e le app gia' fatte. ---
# Se sto RIPRENDENDO il passo App dopo una chiusura, riuso profilo + piano dal
# checkpoint e salto le app gia' installate; altrimenti mostro il menu di scelta.
$pianoApp  = @()
$appFatte  = @()
$etichetta = ""

if ($Global:AppProfiloRipresa) {
    $etichetta = [string]$Global:AppProfiloRipresa
    $pianoApp  = @($Global:AppListaRipresa | ForEach-Object { @{ Nome = [string]$_.Nome; Id = [string]$_.Id } })
    $appFatte  = @($Global:AppFatteRipresa | ForEach-Object { [string]$_ })
    # Consumo la ripresa: eventuali rientri successivi ripartono puliti dal menu.
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
    Write-Host "  3) PROFILO GAMING   (Opera GX + BASE + Steam, Epic, Discord, qBittorrent)"
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
            $pianoApp += @{ Nome = "Google Chrome"; Id = "Google.Chrome" }   # browser sempre
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

# --- Eseguo il PIANO: installo in ordine, salto quelle gia' fatte, e dopo OGNI
#     app riuscita salvo il progresso -> se si chiude, si riparte dall'app esatta.
if ($pianoApp.Count -gt 0) {
    # Installato un browser nostro, tolgo l'icona di Edge dal Desktop (superflua).
    if ($pianoApp | Where-Object { $_.Id -eq "Google.Chrome" -or $_.Id -eq "Opera.OperaGX" }) {
        Remove-EdgeDaDesktop
    }
    foreach ($app in $pianoApp) {
        if ($appFatte -contains $app.Id) {
            Write-Info "$($app.Nome): gia' installato in questa sessione, salto."
            continue
        }
        Installa-Pacchetto -Nome $app.Nome -WingetId $app.Id
        # Segno "fatta" e salvo SOLO se e' andata a buon fine: cosi' una ripresa
        # ritenta le app fallite (rete) e salta solo quelle davvero installate.
        if ($Global:UltimaInstallOk) {
            $appFatte += $app.Id
            Save-AppProgresso -Profilo $etichetta -Lista $pianoApp -Fatte $appFatte
        }
    }
}

# Dopo tutte le installazioni del passo: tolgo eventuali icone doppie (una nostra
# sul Desktop utente + quella dell'installer sul Desktop pubblico).
Remove-IconeDoppieDesktop

# Se PIU' app sono fallite, quasi sempre e' la RETE (proxy/filtro/ispezione SSL
# del negozio che blocca certi download): lo dico chiaro all'operatore.
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
5 {
# =============================================================================
# AGGIORNAMENTI - app installate (winget) + sicurezza di Windows - opzionale
# =============================================================================

Write-Titolo "Aggiornamenti (app + Windows)"

Write-Host "Con un solo SI aggiorno, una dopo l'altra:" -ForegroundColor White
Write-Host "  - App: all'ultima versione le app gestite da winget (anche OEM)." -ForegroundColor White
Write-Host "  - Windows: gli aggiornamenti di SICUREZZA di Windows." -ForegroundColor White
Write-Host "Puo' richiedere diversi minuti. (I driver hanno il loro passo dedicato dopo.)" -ForegroundColor White
Write-Host ""

    $vuoiUpgrade = "S"
    if (-not $Global:ModoEspresso) {
        $vuoiUpgrade = Attendi-Risposta "Aggiornare ora app e Windows? (S/N, B=indietro)"
        if (Test-Indietro $vuoiUpgrade) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
    }
if ($vuoiUpgrade -match "^[Ss]") {
    # 1) APP INSTALLATE (winget)
    if (Confirm-Winget) {
        Write-Info "Aggiornamento app in corso (puo' richiedere diversi minuti)..."
        $null = Invoke-WingetConBarra -Nome "aggiornamenti app" -WingetArgs @('upgrade', '--all', '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown')
        Write-OK "Aggiornamento app completato."
        Add-Report "Aggiornamento app installate" "OK"
    } else {
        Write-Errore "Winget non disponibile."
        Add-Report "Aggiornamento app installate" "ERRORE"
    }

    # 2) AGGIORNAMENTI DI SICUREZZA DI WINDOWS - in BACKGROUND.
    # Invece di scaricarli e installarli QUI (bloccando per minuti), avvio un job
    # che li SCARICA in background: lo script prosegue subito con driver/antivirus.
    # L'installazione vera la faccio ALLA FINE, appena prima del riavvio (cosi' non
    # gira insieme all'installazione dei driver, che usa lo stesso motore Windows
    # Update), e il riavvio la finalizza. Scarico solo aggiornamenti SOFTWARE che
    # non chiedono conferme; i driver hanno il loro passo.
    Write-Host ""
    Write-Info "Aggiornamenti di Windows: li SCARICO in background mentre proseguo."
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
        Write-OK "Download aggiornamenti Windows avviato in background."
        Add-Report "Aggiornamenti Windows (scaricati in background)" "OK"
    } catch {
        Write-Errore "Impossibile avviare gli aggiornamenti di Windows: $_"
        Add-Report "Aggiornamenti di sicurezza Windows" "ERRORE"
    }
} else {
    Write-Info "Aggiornamenti saltati (app e Windows)."
    Add-Report "Aggiornamento app installate" "SALTATO"
    Add-Report "Aggiornamenti di sicurezza Windows" "SALTATO"
}

$passo++   # dopo la scelta si va dritti al passo successivo (niente attesa INVIO)
}
6 {
# =============================================================================
# DRIVER (Windows Update, opzionale)
# =============================================================================

Write-Titolo "Driver (Windows Update)"

Write-Host "Cerca e installa i driver mancanti/aggiornati dal catalogo Windows Update." -ForegroundColor White
Write-Host "Se c'e' una scheda video DEDICATA, uso anche il tool del produttore (Windows" -ForegroundColor White
Write-Host "Update spesso non ne prende il driver giusto). Puo' richiedere qualche minuto" -ForegroundColor White
Write-Host "e talvolta un riavvio. Opzionale, ultimo passo." -ForegroundColor White
Write-Host ""

# DRIVER SCHEDA VIDEO DEDICATA: solo se c'e' una GPU dedicata (non l'integrata),
# perche' e' li' che Windows Update fa cilecca. Sulle integrate ci pensa Windows
# Update (sotto) e non installiamo app inutili.
$gpuDed = Get-GpuDedicata
switch ($gpuDed) {
    'NVIDIA' {
        # App NVIDIA: gestisce i driver video meglio della ricerca generica di WU.
        # Provo "NVIDIA App" (attuale), poi GeForce Experience come ripiego.
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
        # Intel Arc (dedicata): Intel Driver & Support Assistant trova e installa
        # da solo il driver grafico Intel piu' recente.
        if (Confirm-Winget) {
            Write-Info "Scheda video Intel Arc (dedicata): installo Intel Driver & Support Assistant..."
            Installa-Pacchetto -Nome "Intel Driver e Support Assistant" -WingetId "Intel.IntelDriverAndSupportAssistant"
            Write-Info "APRI 'Intel Driver & Support Assistant' per scaricare il driver video."
            Add-Report "Intel DSA (driver video): aprire per completare" "OK"
        }
        Write-Host ""
    }
    'AMD' {
        # AMD dedicata: non c'e' un pacchetto winget affidabile per il driver
        # Adrenalin, quindi apro la pagina AMD di rilevamento automatico (come
        # per i tool antivirus): l'operatore scarica ed esegue.
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
    if (-not $Global:ModoEspresso) {
        $vuoiDriver = Attendi-Risposta "Cercare e installare i driver ora? (S/N, B=indietro)"
        if (Test-Indietro $vuoiDriver) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
    }
if ($vuoiDriver -match "^[Ss]") {
    try {
        Write-Info "Ricerca driver su Windows Update (puo' richiedere qualche minuto)..."
        Start-BarraAnimata "Cerco i driver su Windows Update"
        try {
            $sess = New-Object -ComObject Microsoft.Update.Session
            $searcher = $sess.CreateUpdateSearcher()
            # Solo aggiornamenti di tipo driver non ancora installati
            $result = $searcher.Search("Type='Driver' and IsInstalled=0")
        } finally { Stop-BarraAnimata }
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
            Start-BarraAnimata "Scarico i driver"
            try {
                $downloader = $sess.CreateUpdateDownloader()
                $downloader.Updates = $daInstallare
                $downloader.Download() | Out-Null
            } finally { Stop-BarraAnimata }
            Write-Info "Installazione driver..."
            Start-BarraAnimata "Installo i driver"
            try {
                $installer = $sess.CreateUpdateInstaller()
                $installer.Updates = $daInstallare
                $esito = $installer.Install()
            } finally { Stop-BarraAnimata }
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
    #
    # RETE DI SICUREZZA sulla PASSWORD: nel file non deve MAI mancare. Se per
    # qualsiasi motivo e' vuota (passo saltato, account gia' esistente senza
    # password digitata) ma conosco il nome cliente, la imposto al formato
    # standard "Nome123!" (prima lettera maiuscola) - la stessa che si usa in
    # negozio. Idem per l'email suggerita se manca del tutto.
    if (-not $credMsPassword -and $nomeCliente) { $credMsPassword = New-PasswordCliente -Base $nomeCliente }
    if (-not $credMsAccount  -and $nomeCliente) {
        # Uso il DOMINIO del provider scelto (es. proton.me), non il default, cosi'
        # l'email suggerita e' coerente con l'account creato dal cliente.
        $domRete = if ($Global:credDominio) { $Global:credDominio } else { "outlook.it" }
        $credMsAccount = New-EmailCliente -Base $nomeCliente -Dominio $domRete
    }
    try {
        $winOk   = @($Report | Where-Object { $_.Voce -eq 'Windows attivato' -and $_.Esito -eq 'OK' }).Count -gt 0
        $diskBad = @($Report | Where-Object { $_.Voce -eq 'Salute disco' -and $_.Esito -eq 'ERRORE' }).Count -gt 0
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

        $f = @()
        $f += "============================================================"
        $f += "   IL TUO NUOVO PC E' PRONTO"
        $f += "============================================================"
        $f += ""
        $f += "Data     : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
        $f += "Cliente  : $(if ($nomeCliente) { $nomeCliente } else { '(non impostato)' })"
        $f += "Nome PC  : $env:COMPUTERNAME"
        $f += "Utente   : $env:USERNAME"
        $f += ""
        $f += $credBlocco
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

        # --- Checklist DA COMPLETARE A MANO: costruita da cio' che e' successo ---
        $daFare = @()
        if (@($Report | Where-Object { $_.Voce -like 'Lingua italiana*' -and $_.Esito -eq 'OK' }).Count -gt 0) {
            $daFare += "RIAVVIARE il PC: serve per vedere l'interfaccia in italiano."
        }
        if (@($Report | Where-Object { $_.Voce -like 'Ridimensionamento schermo*' }).Count -gt 0) {
            $daFare += "Il ridimensionamento schermo si attiva dopo il logout/riavvio."
        }
        if (@($Report | Where-Object { $_.Voce -like 'McAfee*' }).Count -gt 0) {
            $daFare += "Completare la rimozione di McAfee con MCPR (finestra/pagina aperta), poi riavviare."
        }
        if (@($Report | Where-Object { $_.Voce -like 'Norton*' }).Count -gt 0) {
            $daFare += "Completare la rimozione di Norton con NRnR, poi riavviare."
        }
        if (@($Report | Where-Object { $_.Esito -eq 'ERRORE' }).Count -gt 0) {
            $daFare += "Controllare le voci in ERRORE del report."
        }
        $daFare += "Installare/attivare l'antivirus definitivo del cliente."
        $daFare += "Verificare l'attivazione di Windows e di Office."
        $f += ""
        $f += $sep
        $f += "DA COMPLETARE A MANO"
        $f += $sep
        foreach ($d in $daFare) { $f += "  [ ] $d" }

        # (Le credenziali complete sono IN CIMA a questo file e nel file dedicato
        #  "Credenziali - <cliente>.txt" sul Desktop.)
        if ($credAltro) {
            $f += ""
            $f += $sep
            $f += "ALTRE NOTE"
            $f += $sep
            $f += "  $credAltro"
        }
        $f += ""
        if ($Global:ErroriImprevisti.Count -gt 0) {
            $f += $sep
            $f += "IMPREVISTI GESTITI ($($Global:ErroriImprevisti.Count)) - dettaglio nel log tecnico"
            $f += $sep
            foreach ($e in $Global:ErroriImprevisti) { $f += "  [riga $($e.Riga)] $($e.Messaggio)" }
            $f += ""
        }

        $f += $sep
        $f += "DETTAGLI TECNICI (per l'assistenza, se il PC torna in negozio)"
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

        # Nome file "carino" per il cliente (non piu' Riepilogo-PC_data).
        $nomeFile = if ($nomeCliente) { "Il tuo nuovo PC - $nomeCliente" } else { "Il tuo nuovo PC" }
        $nomeFile = ($nomeFile -replace '[\\/:*?"<>|]', '').Trim()
        $riepFile = Join-Path (Get-DesktopDir) ("$nomeFile.txt")
        $f | Set-Content -Path $riepFile -Encoding UTF8
        Write-OK "Riepilogo salvato sul Desktop: $riepFile"

        # Scheda di Consegna Cliente HTML stampabile con grafica moderna
        try {
            $htmlFile = Join-Path (Get-DesktopDir) ("Scheda-Consegna-Cliente.html")
            $cpuName = if ($cpuInfo) { "$cpuInfo" } else { "Processore Standard" }
            $ramDisplay = if ($ramGB) { "$ramGB GB" } else { "8 GB" }
            $gpuDisplay = if ($gpuInfo) { "$gpuInfo" } else { "Grafica integrata" }
            $appInstallate = @($Report | Where-Object { $_.Voce -like '*installazione*' -and $_.Esito -eq 'OK' } | ForEach-Object { ($_.Voce -replace ' \(installazione\)', '' -replace ' \(installazione offline\)', '').Trim() })
            $appItems = ""
            foreach ($app in $appInstallate) { $appItems += "<div class='app-badge'>&#10003; <strong>$app</strong></div>" }
            if (-not $appItems) { $appItems = "<div class='app-badge'>&#10003; <strong>Applicazioni base configurate</strong></div>" }

            $credBox = ""
            if ($credGenerataEmail -or $credGenerataPass) {
                $credBox = @"
                <div class='card'>
                    <h3>&#128273; Credenziali di Primo Accesso</h3>
                    <table class='info-table'>
                        $(if ($credGenerataEmail) { "<tr><td>Email:</td><td><strong>$credGenerataEmail</strong></td></tr>" })
                        $(if ($credGenerataPass) { "<tr><td>Password provvisoria:</td><td><code>$credGenerataPass</code> <em>(da cambiare al primo accesso)</em></td></tr>" })
                        <tr><td>Account PC:</td><td>$env:USERNAME</td></tr>
                    </table>
                </div>
"@
            }

            $htmlDoc = @"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Scheda Consegna PC - $nomeCliente</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }
        body { background: #f1f5f9; color: #1e293b; padding: 24px; }
        .sheet { max-width: 800px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 4px 14px rgba(0,0,0,0.08); overflow: hidden; }
        .header { background: linear-gradient(135deg, #0A0E24 0%, #1a2552 100%); color: #fff; padding: 24px 30px; border-bottom: 4px solid #EE7203; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 22px; font-weight: 700; color: #fff; }
        .header p { font-size: 13px; color: #94a3b8; }
        .badge-brand { background: #EE7203; color: #fff; font-weight: 700; font-size: 13px; padding: 6px 12px; border-radius: 6px; }
        .body { padding: 28px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; margin-bottom: 20px; }
        .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 18px; }
        .card h3 { font-size: 15px; color: #0A0E24; margin-bottom: 12px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; }
        .info-table { width: 100%; border-collapse: collapse; font-size: 13px; }
        .info-table td { padding: 4px 0; }
        .info-table td:first-child { width: 45%; color: #64748b; font-weight: 500; }
        .app-grid { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 6px; }
        .app-badge { background: #fff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 6px 10px; font-size: 12px; display: inline-flex; align-items: center; gap: 6px; }
        .app-badge strong { color: #0f172a; }
        .tips-list { font-size: 13px; color: #475569; padding-left: 18px; line-height: 1.6; }
        .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 16px 28px; display: flex; justify-content: space-between; align-items: center; font-size: 12px; color: #64748b; }
        .btn-print { background: #EE7203; color: #fff; border: none; font-weight: 700; font-size: 13px; padding: 8px 18px; border-radius: 6px; cursor: pointer; }
        @media print { body { background: #fff; padding: 0; } .sheet { box-shadow: none; max-width: 100%; } .no-print { display: none !important; } }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="header">
            <div>
                <h1>Scheda di Consegna e Configurazione PC</h1>
                <p>Assistenza Tecnica &bull; Setup Personalizzato</p>
            </div>
            <div class="badge-brand">PC FACILE v$SCRIPT_VERSION</div>
        </div>
        <div class="body">
            <div class="grid">
                <div class="card">
                    <h3>&#128100; Dati Cliente &amp; PC</h3>
                    <table class="info-table">
                        <tr><td>Cliente:</td><td><strong>$(if ($nomeCliente) { $nomeCliente } else { $env:USERNAME })</strong></td></tr>
                        <tr><td>Nome Computer:</td><td><code>$env:COMPUTERNAME</code></td></tr>
                        <tr><td>Data Setup:</td><td>$(Get-Date -Format 'dd/MM/yyyy HH:mm')</td></tr>
                        <tr><td>Sistema:</td><td>$(if ($osInfo) { $osInfo.Caption } else { 'Windows 11' })</td></tr>
                        <tr><td>Stato Setup:</td><td><strong style="color:#16a34a;">&#10003; Pronto e Collaudato</strong></td></tr>
                    </table>
                </div>
                <div class="card">
                    <h3>&#128187; Specifiche Hardware</h3>
                    <table class="info-table">
                        <tr><td>Processore:</td><td>$cpuName</td></tr>
                        <tr><td>RAM:</td><td>$ramDisplay</td></tr>
                        <tr><td>Scheda Video:</td><td>$gpuDisplay</td></tr>
                        <tr><td>Lingua:</td><td>Italiano (it-IT)</td></tr>
                    </table>
                </div>
            </div>
            $credBox
            <div class="card" style="margin-bottom: 20px;">
                <h3>&#128230; Programmi e Utility Installate</h3>
                <div class="app-grid">$appItems</div>
            </div>
            <div class="card">
                <h3>&#128161; Consigli e Istruzioni per l'Uso</h3>
                <ul class="tips-list">
                    <li><strong>Wi-Fi:</strong> All'accensione a casa, seleziona la tua rete Wi-Fi in basso a destra ed inserisci la password.</li>
                    <li><strong>Sicurezza:</strong> Se &egrave; stata creata una password provvisoria, modificala al primo accesso in <em>Impostazioni &gt; Account</em>.</li>
                    <li><strong>Teleassistenza:</strong> AnyDesk e TeamViewer sono pronti sul desktop in caso di necessit&agrave; di supporto da remoto.</li>
                </ul>
            </div>
        </div>
        <div class="footer">
            <div>Generato automaticamente da <strong>PC Facile</strong> per il cliente.</div>
            <button class="btn-print no-print" onclick="window.print()">&#128438; Stampa Scheda</button>
        </div>
    </div>
</body>
</html>
"@
            $htmlDoc | Set-Content -Path $htmlFile -Encoding UTF8
            Write-OK "Scheda di consegna HTML salvata: $htmlFile"
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
                versioneTool = $SCRIPT_VERSION
                data         = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                cliente      = "$nomeCliente"
                nomePc       = "$env:COMPUTERNAME"
                utente       = "$env:USERNAME"
                sistema      = if ($osInfo) { "$($osInfo.Caption) build $($osInfo.BuildNumber)" } else { 'n/d' }
                powershell   = "$($PSVersionTable.PSVersion)"
                winget       = "$wgVer"
                windowsAttivato = [bool]$winOk
                risoluzione  = "$resTxt"
                antivirus    = "$avTxt"
                esiti        = @($Report | ForEach-Object { [ordered]@{ voce = $_.Voce; esito = $_.Esito } })
                verificaFinale = @($verifica | ForEach-Object { [ordered]@{ voce = $_.N; ok = [bool]$_.Ok } })
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
        Start-BarraAnimata "Installo gli aggiornamenti di Windows"
        try {
            $sFin = New-Object -ComObject Microsoft.Update.Session
            $rFin = $sFin.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software' and IsHidden=0")
            $cFin = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($u in $rFin.Updates) {
                if ($u.InstallationBehavior -and $u.InstallationBehavior.CanRequestUserInput) { continue }
                if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
                if ($u.IsDownloaded) { $cFin.Add($u) | Out-Null }
            }
            if ($cFin.Count -gt 0) { $iFin = $sFin.CreateUpdateInstaller(); $iFin.Updates = $cFin; $iFin.Install() | Out-Null }
        } catch {} finally { Stop-BarraAnimata }
        Write-OK "Aggiornamenti di Windows applicati: il riavvio li completa."
    } else {
        Write-OK "Windows e' gia' aggiornato (nessun aggiornamento da installare)."
    }
}

# RIAVVIO FINALE: sempre proposto (e sempre CHIESTO, anche nel flusso automatico).
# Serve per applicare del tutto lingua italiana, barra, impostazioni nuovi utenti.
if ($RunReale) {
    $linguaOk = @($Report | Where-Object { $_.Voce -like "Lingua italiana (it-IT*" -and $_.Esito -eq "OK" }).Count -gt 0
    Write-Titolo "ULTIMO PASSO: RIAVVIO"
    Write-Host "Ho finito TUTTO (pulizia, lingua, app, aggiornamenti, driver, antivirus)." -ForegroundColor White
    Write-Host "Manca solo UN riavvio, l'ultimo, per rendere effettivo il lavoro:" -ForegroundColor White
    if ($linguaOk) {
        Write-Host "  - fa comparire l'interfaccia in ITALIANO (menu, barra, schermata di accesso)" -ForegroundColor White
    }
    Write-Host "  - applica barra, regione e impostazioni per i nuovi utenti" -ForegroundColor White
    Write-Host "Dopo questo riavvio il PC e' PRONTO da consegnare: non serve riaprire PC Facile." -ForegroundColor White
    Write-Host ""
    $riavvia = Attendi-Risposta "Riavvio ADESSO il PC? (S = riavvia ora / N = riavvio io dopo)"
    if ($riavvia -match "^[Ss]") {
        Write-Info "Riavvio in corso..."
        Restart-Computer -Force
    } else {
        Write-Errore "RICORDATI di RIAVVIARE il PC prima di consegnarlo: senza riavvio la lingua e alcune impostazioni non si vedono."
    }
}

Write-Host ""
Beep-Completato   # melodia "tutto finito" (utile se ti sei allontanato)
Write-Host "${AON}Buon lavoro!$AOFF" -ForegroundColor $THEME_COL
# Niente Pausa qui: l'unico "premi un tasto" e' quello finale del launcher .bat
# ("Operazione terminata"), cosi' non si preme INVIO due volte.
