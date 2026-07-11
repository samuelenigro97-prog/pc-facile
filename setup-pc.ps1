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
$SCRIPT_VERSION = "6.7 (2026-07-11)"

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
# RIPRESA SESSIONE: se lo script viene chiuso a meta' (crash, riavvio, blocco
# antivirus), al lancio successivo riparte da dove era arrivato. Dopo ogni
# passo completato lo stato (numero passo + nome cliente + credenziali
# generate) finisce in un file JSON in ProgramData, ELIMINATO a fine lavoro.
# Fasi: 1=Lingua 2=Nome 3=Ripristino 4=Account 5=Office 6=Pulizia,
# 7..12 = passi wizard 3..8 (Antivirus..Driver). Solo nel run reale.
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
        [pscustomobject]@{
            Fase = $Fase; FaseNome = $Nome
            Data = (Get-Date -Format 'dd/MM/yyyy HH:mm')
            NomeCliente = $nomeCliente
            CredAccount = $credMsAccount; CredPassword = $credMsPassword
        } | ConvertTo-Json | Set-Content -Path $Global:StatoFile -Encoding UTF8
    } catch {}
}

# Vero se il passo era gia' stato completato nella sessione ripresa.
function Test-FaseFatta { param([int]$Fase) return ($Global:FaseRipresa -ge $Fase) }

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
    @{ Nome = "WhatsApp";             Id = "WhatsApp.WhatsApp";            Profili = @("BASE","UFFICIO","GAMING") },
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
    $wg = (Get-Command winget -ErrorAction SilentlyContinue).Source
    if (-not $wg) { $wg = 'winget' }
    $out = Join-Path $env:TEMP ("pcf_wg_out_{0}.txt" -f $PID)
    $err = Join-Path $env:TEMP ("pcf_wg_err_{0}.txt" -f $PID)
    try {
        $p = Start-Process -FilePath $wg -ArgumentList $WingetArgs -PassThru -NoNewWindow `
             -RedirectStandardOutput $out -RedirectStandardError $err -ErrorAction Stop
        Show-BarraAttesa -Testo "Scarico e installo $Nome" -Processo $p
        $code = $p.ExitCode
    } catch {
        # Ripiego: nessuna barra, ma l'installazione parte comunque.
        & $wg @WingetArgs *> $null
        $code = $LASTEXITCODE
    }
    try { Remove-Item $out, $err -Force -ErrorAction SilentlyContinue } catch {}
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

# Crea sul Desktop l'icona dell'app appena installata. 1) prova a copiare il
# collegamento vero dal menu Start (icona corretta); 2) se e' un'app dello Store
# (MSIX, niente .lnk) ripiega su Get-StartApps + shell:AppsFolder. Salta se
# un'icona simile e' gia' sul Desktop (niente doppioni).
function Add-IconaDesktop {
    param([string]$Nome)
    if (-not $RunReale) { return }
    try {
        $desktop = Get-DesktopDir
        $gia = Get-ChildItem -Path $desktop -Filter *.lnk -ErrorAction SilentlyContinue |
            Where-Object { Test-NomeSimile $_.BaseName $Nome } | Select-Object -First 1
        if ($gia) { return }

        # 1) Menu Start: collegamento Win32 con l'icona vera dell'app.
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
            }
            $sc.Save()
        }
    } catch {}
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
        Add-IconaDesktop -Nome $Nome
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
        Write-Info "Installo $Nome...$(if ($tentativo -gt 1) { " (tentativo $tentativo)" })"
        # Nascondo l'output tecnico di winget (hash, licenze, progressi): confonde.
        # Al suo posto una barra animata di attesa, cosi' si vede che sta lavorando.
        $codeInstall = Invoke-WingetConBarra -Nome $Nome -WingetArgs (@('install', '--exact', '--id', $WingetId) + $sorgente + @('--silent', '--accept-package-agreements', '--accept-source-agreements'))
        if ($successo -contains $codeInstall) {
            if ($codeInstall -eq 0) {
                Write-OK "$Nome installato."
            } else {
                Write-OK "$Nome installato (richiede riavvio)."
            }
            Add-Report "$Nome (installazione)" "OK"
            Add-IconaDesktop -Nome $Nome
            return
        }

        Write-Errore "Installazione $Nome fallita (codice: $codeInstall)."

        if (($erroriSorgente -contains $codeInstall) -and -not $riparatoQui) {
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
# LINGUA E REGIONE (ITALIANO) - primo passo
# =============================================================================

if (Test-FaseFatta 1) { Write-Info "Lingua e regione: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Lingua e Regione (Italiano)"

Write-Host "I PC installati da chiavetta partono spesso in INGLESE." -ForegroundColor White
Write-Host "Questo passaggio imposta display, formati, tastiera e language pack in it-IT." -ForegroundColor White
Write-Host ""

$culturaAttuale = (Get-Culture).Name
Write-Info "Lingua/regione attuale: $culturaAttuale"

$impostaLingua = Chiedi "Impostare il sistema in Italiano (it-IT)? (S/N)" "S"
if ($impostaLingua -match "^[Ss]") {

    # Skip intelligente: se il PC e' GIA' in italiano (interfaccia + pacchetto),
    # non rifaccio nulla e vado avanti.
    $giaItaliano = $false
    try { $giaItaliano = ((Get-UICulture).Name -like 'it*') -and ((Get-InstalledLanguage -ErrorAction SilentlyContinue).LanguageId -contains 'it-IT') } catch {}
    if ($giaItaliano) {
        Write-OK "Il PC risulta gia' in italiano: salto questo passo (niente da rifare)."
        Add-Report "Lingua italiana (gia' impostata)" "OK"
    } else {

    # --- 1) LANGUAGE PACK it-IT PRIMA di tutto (Windows 11 22H2+). E' QUESTO che
    #     rende l'INTERFACCIA in italiano; senza, cambiano solo tastiera/formati e
    #     l'UI resta inglese. -CopyToSettings applica il pack a utente + login +
    #     nuovi utenti in un colpo (il modo affidabile). Serve Internet. ---
    $packOk = $false
    if (Get-Command Install-Language -ErrorAction SilentlyContinue) {
        try {
            Write-Info "Installazione/applicazione language pack it-IT (qualche minuto, serve Internet)..."
            try {
                # Modo moderno e affidabile
                Install-Language it-IT -CopyToSettings -ErrorAction Stop | Out-Null
            } catch {
                # -CopyToSettings non c'e' su tutte le build: fallback senza flag
                Install-Language it-IT -ErrorAction Stop | Out-Null
            }
            $packOk = ((Get-InstalledLanguage -ErrorAction SilentlyContinue).LanguageId -contains "it-IT")
        } catch {
            Write-Errore "Language pack it-IT NON installato (Internet assente o bloccato)."
        }
    } else {
        Write-Info "Install-Language non c'e' (Windows 10): il pacchetto lingua di visualizzazione va aggiunto a mano."
        $packDaAggiungere = $true
    }

    # --- 2) Lingua UI di sistema + override utente (DOPO il pack, cosi' aggancia) ---
    if (Get-Command Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue) {
        try { Set-SystemPreferredUILanguage it-IT } catch {}
    }
    try { Set-WinUILanguageOverride -Language it-IT } catch {}

    # --- 3) Propaga a login + nuovi utenti (ridondante se -CopyToSettings ha funzionato) ---
    if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true } catch {}
    }

    # --- 4) Tastiera italiana, formati, regione, locale di sistema, fuso (sempre) ---
    try {
        $lista = New-WinUserLanguageList it-IT
        $lista[0].InputMethodTips.Clear()
        $lista[0].InputMethodTips.Add("0410:00000410")   # tastiera italiana
        Set-WinUserLanguageList $lista -Force
        Set-Culture it-IT
        Set-WinHomeLocation -GeoId 118    # Italia
    } catch { Write-Info "Alcune impostazioni tastiera/formati non applicate: $_" }
    try { Set-WinSystemLocale it-IT } catch {}
    try { Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop; Write-OK "Fuso orario Italia (CET)." } catch {}

    # --- Esito CHIARO: se il pack non c'e', l'utente deve sapere PERCHE' resta inglese ---
    if ($packOk) {
        Write-OK "Italiano impostato: display, tastiera e formati. Attivo del tutto dopo il RIAVVIO."
        Add-Report "Lingua italiana (it-IT)" "OK"
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
    }
} else {
    Write-Info "Impostazione lingua saltata."
    Add-Report "Lingua italiana (it-IT)" "SALTATO"
}

Save-Fase 1 "Lingua e regione"
}

# (nessuna pausa: si avanza da solo, come nel wizard)

# =============================================================================
# NOME CLIENTE E PC (prima voce dopo la lingua: la prima cosa da impostare)
# Un solo nome: vale sia per l'account Windows sia per il nome del PC.
# =============================================================================

if (Test-FaseFatta 2) { Write-Info "Nome cliente e PC: gia' fatto nella sessione precedente, salto." }
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

Save-Fase 2 "Nome cliente e PC"
}

# (nessuna pausa: si avanza da solo)

# =============================================================================
# PUNTO DI RIPRISTINO (rete di sicurezza prima delle modifiche)
# =============================================================================

if (Test-FaseFatta 3) { Write-Info "Punto di ripristino: gia' fatto nella sessione precedente, salto." }
else {

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

Save-Fase 3 "Punto di ripristino"
}

# (nessuna pausa: si avanza da solo)

# =============================================================================
# ACCOUNT MICROSOFT (accedi/crea presto: velocizza Office e antivirus dopo)
# =============================================================================

if (Test-FaseFatta 4) { Write-Info "Account Microsoft: gia' fatto nella sessione precedente, salto." }
else {

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
        $haAccount = Attendi-Risposta "Il cliente ha GIA' una sua email/password che usa? (S = le inserisco io / N = ne genero una nuova)"
        if ($haAccount -match "^[Ss]") {
            $credMsAccount  = (Attendi-Risposta "  Email del cliente").Trim()
            $credMsPassword = (Attendi-Risposta "  Password del cliente").Trim()
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

Save-Fase 4 "Account Microsoft"
}

# =============================================================================
# INSTALLAZIONE APP OFFICE (subito dopo l'account Microsoft): prima si INSTALLA
# la suite scelta (se manca), poi la schermata dopo la attiva (codice/key).
# =============================================================================

if (Test-FaseFatta 5) { Write-Info "App Office: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Installazione App Office"

Write-Host "Scegli la suite Office da installare (se manca) e attivare:" -ForegroundColor White
Write-Host "  1) Microsoft 365 (abbonamento, card PIN) - installa, poi riscatto su microsoft365.com/setup" -ForegroundColor White
Write-Host "  2) Office perpetuo (Home 2024/2021, card PIN) - installa, poi riscatto su office.com/setup" -ForegroundColor White
Write-Host "  3) OpenOffice (suite gratuita)" -ForegroundColor White
Write-Host "  4) LibreOffice (suite gratuita)" -ForegroundColor White
Write-Host "  5) Salta" -ForegroundColor White
Write-Host ""

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

$sceltaAtt = Chiedi "Scelta (1-5)" "1"
switch ($sceltaAtt) {
    "1" {
        # 1/2: INSTALLAZIONE (se manca). Su molti PC nuovi M365 e' preinstallato:
        # in quel caso non si tocca nulla e si passa subito all'attivazione.
        if (Get-OsppPath) {
            Write-OK "Office gia' installato su questo PC."
        } elseif (Confirm-Winget) {
            Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office"
        } else {
            Write-Errore "Winget non disponibile: se Office manca, scaricalo da office.com dopo il riscatto."
        }
        Add-CollegamentiOffice
        # 2/2: ATTIVAZIONE - la schermata dopo: pagina web per il codice di licenza
        # (l'indirizzo stampato sulla card Microsoft 365 Personal).
        Start-Process "https://microsoft365.com/setup"
        Write-OK "Browser aperto su microsoft365.com/setup"
        Write-Info "Accedi con l'account Microsoft del cliente e inserisci il codice grattato sulla card."
        Add-Report "Microsoft 365 (riscatto card PIN)" "OK"
    }
    "3" {
        if (Confirm-Winget) { Installa-Pacchetto -Nome "OpenOffice" -WingetId "Apache.OpenOffice" }
        else { Write-Errore "Winget non disponibile." ; Add-Report "OpenOffice (installazione)" "ERRORE" }
    }
    "4" {
        if (Confirm-Winget) { Installa-Pacchetto -Nome "LibreOffice" -WingetId "TheDocumentFoundation.LibreOffice" }
        else { Write-Errore "Winget non disponibile." ; Add-Report "LibreOffice (installazione)" "ERRORE" }
    }
    "2" {
        # 1/2: INSTALLAZIONE (se manca). La suite e' la stessa di Microsoft 365:
        # cambia solo la licenza. Se e' gia' presente non si tocca nulla.
        if (Get-OsppPath) {
            Write-OK "Office gia' installato su questo PC."
        } elseif (Confirm-Winget) {
            Installa-Pacchetto -Nome "Microsoft 365" -WingetId "Microsoft.Office"
        } else {
            Write-Errore "Winget non disponibile: se Office manca, scaricalo da office.com dopo il riscatto."
        }
        Add-CollegamentiOffice
        # 2/2: ATTIVAZIONE. Le card vendute in negozio hanno SEMPRE il PIN da
        # grattare: si riscatta sul web con l'account Microsoft del cliente.
        # Quel codice NON va inserito in ospp.vbs (le chiavi retail moderne
        # sono solo da riscatto), quindi niente domande: si apre la pagina.
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

Save-Fase 5 "App Office"
}

# =============================================================================
# PULIZIA E OTTIMIZZAZIONE INIZIALE - un solo passaggio, una sola domanda:
#   1/3 rimuove gli antivirus di PROVA (evita conflitti e blocchi)
#   2/3 rimuove il bloatware + pulisce l'avvio automatico (boot piu' veloce)
#   3/3 comodita' Windows (estensioni, Questo PC) + disinstalla OneDrive
# =============================================================================

if (Test-FaseFatta 6) { Write-Info "Pulizia e ottimizzazione: gia' fatto nella sessione precedente, salto." }
else {

Write-Titolo "Pulizia e Ottimizzazione Iniziale"

Write-Host "In un colpo solo, consigliato sui PC nuovi:" -ForegroundColor White
Write-Host "  - toglie gli antivirus di PROVA (McAfee/Norton/Avast: scadono e vanno" -ForegroundColor White
Write-Host "    in conflitto con quello che installi, a volte bloccano lo script)" -ForegroundColor White
Write-Host "  - rimuove il bloatware del produttore (HP/Lenovo/Dell/Asus/Acer) e le" -ForegroundColor White
Write-Host "    app consumer inutili, e alleggerisce l'avvio automatico" -ForegroundColor White
Write-Host "  - applica piccole comodita' (estensioni file, Esplora su 'Questo PC'," -ForegroundColor White
Write-Host "    OneDrive rimosso)" -ForegroundColor White
Write-Host "NON tocca: Xbox, Spotify, Store, Foto, driver, ne' i programmi del setup." -ForegroundColor White
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
            # winget toglie Avast/AVG e i pochi McAfee che gestisce; non bloccante,
            # non fatale. McAfee/Norton spesso resistono: sotto ci pensano i tool
            # ufficiali (MCPR / NRnR).
            if (Confirm-Winget) {
                winget uninstall --name $av.Nome --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
            }
        }

        # VERIFICO davvero cosa e' rimasto (non mi fido dell'esito di winget).
        Start-Sleep -Seconds 2
        $rimasti      = @(Get-AntivirusInstallati)
        $mcafeeResta  = @($rimasti | Where-Object { $_.Nome -match 'McAfee' }).Count -gt 0
        $nortonResta  = @($rimasti | Where-Object { $_.Nome -match 'Norton' }).Count -gt 0
        if ($rimasti.Count -eq 0) {
            Write-OK "Antivirus di prova rimossi."
            Add-Report "Antivirus di prova rimossi" "OK"
        } else {
            Write-Info "Resistono ai metodi standard: $(($rimasti.Nome) -join ', '). Uso i tool ufficiali."
            Add-Report "Antivirus di prova (residui: tool ufficiale)" "AVVISO"
        }

        # McAfee: winget non lo toglie del tutto, serve MCPR (tool ufficiale).
        # NON lo scarico/eseguo dallo script: scaricare+lanciare un .exe fa
        # scattare l'euristica comportamentale dell'antivirus (IDP.Generic) e lo
        # script finisce in quarantena. Apro invece la PAGINA del tool: l'operatore
        # lo scarica e lo lancia a mano (Avanti -> Avanti), poi RIAVVIO.
        if ($mcafeeResta) {
            if ($nortonResta) {
                # Con Norton presente NON scarico l'exe: Norton lo blocca come
                # IDP.Generic. Apro la pagina, MCPR lo esegue l'operatore.
                Start-Process "https://www.mcafee.com/support/?articleId=TS101331"
                Write-Info "McAfee resiste: aperta la pagina di MCPR. Scaricalo ed eseguilo a mano, poi RIAVVIA."
                Add-Report "McAfee (MCPR a mano)" "AVVISO"
            } else {
                # Solo McAfee: MCPR e' il tool UFFICIALE McAfee, non blocca se stesso.
                try {
                    Write-Info "McAfee resiste: scarico e avvio MCPR (tool ufficiale McAfee)..."
                    $mcpr = "$env:TEMP\MCPR.exe"
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
        # Norton: come McAfee, serve il tool ufficiale (Norton Remove and Reinstall).
        if ($nortonResta) {
            Start-Process "https://norton.com/nrnr"
            Write-Info "Norton ancora presente: aperto il tool ufficiale NRnR. Eseguilo, poi RIAVVIA."
            Add-Report "Norton (NRnR aperto: completare a mano)" "AVVISO"
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

    # DISINSTALLA OneDrive (non solo l'avvio automatico): molti clienti non lo
    # vogliono. Chiudo il processo, lancio il disinstallatore ufficiale, tolgo la
    # versione Store (Appx) e il provisioning (i nuovi utenti non lo riavranno).
    try {
        Write-Info "Disinstallazione OneDrive..."
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
    }

    Write-OK "Pulizia e ottimizzazione iniziale completata."
} else {
    Write-Info "Pulizia e ottimizzazione iniziale saltata."
    Add-Report "Antivirus di prova" "SALTATO"
    Add-Report "Rimozione bloatware" "SALTATO"
    Add-Report "Configurazione Windows base" "SALTATO"
}

Save-Fase 6 "Pulizia e ottimizzazione"
}

# =============================================================================
# PASSI DI CONFIGURAZIONE (dopo ogni scelta si avanza; B al prompt = indietro)
# =============================================================================

# Torna al passo precedente quando l'utente digita B al prompt principale di un
# passo. Uso 'continue wizard' (loop etichettato) per rifare il giro del while
# anche da dentro lo switch, saltando il $passo++ di fine passo.
function Test-Indietro { param([string]$v) return ($v -match '^\s*[Bb]\s*$') }

# Il wizard parte dal passo 3: il passo 1 "Nome" e la suite Office (ora nel menu
# Installazione App Office) sono fuori dal wizard. Non rinumero i case: mostro
# (passo-2) su 6 nella barra.
$passo = 3
# Nomi leggibili dei passi wizard per il checkpoint di ripresa sessione.
$wizNomi = @{ 3 = "Antivirus"; 4 = "Unieuro Cyber Protection"; 5 = "Browser"; 6 = "Applicazioni base"; 7 = "Aggiornamento app"; 8 = "Driver" }
# Ripresa sessione: fase 7..12 = passo wizard 3..8 completato -> si riparte
# dal successivo (fase 12 = tutto il wizard fatto, si salta al report).
if ($Global:FaseRipresa -ge 7) {
    $passo = $Global:FaseRipresa - 3
    if ($passo -le 8) { Write-Info "Riprendo il wizard dal passo $($passo - 2) di 6." }
}
:wizard while ($passo -ge 3 -and $passo -le 8) {
Write-Host ""
$barLen = 20
$totPassi = 6
$passoMostrato = $passo - 2
$pieni = [int]($barLen * $passoMostrato / $totPassi)
if ($pieni -gt $barLen) { $pieni = $barLen }
$bar = (([string]$BOX_FULL) * $pieni) + (([string]$BOX_EMPTY) * ($barLen - $pieni))
Write-Host ("$AON  Passo $passoMostrato/$totPassi  [$bar]$AOFF") -ForegroundColor $THEME_COL
switch ($passo) {
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

$sceltaAV = Attendi-Risposta "Scelta (1-3, B=indietro)"
if (Test-Indietro $sceltaAV) { $passo = [Math]::Max(3, $passo - 1); continue wizard }

function Installa-Antivirus {
    param(
        [string]$Nome,
        [string]$UrlRiscatto
    )

    Write-Info "Apertura pagina registrazione/riscatto $Nome..."
    Start-Process $UrlRiscatto
    Write-OK "Browser aperto su: $UrlRiscatto"
    Write-Host ""
    Write-Host "Completa registrazione/download nel browser." -ForegroundColor White
    Write-Host "L'installer parte DA SOLO appena finisce di scaricarsi (niente INVIO)." -ForegroundColor White
    Write-Host ""

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
        [string]$UrlAttivazione
    )

    Write-Info "Apertura pagina attivazione $Nome..."
    Start-Process $UrlAttivazione
    Write-OK "Browser aperto su: $UrlAttivazione"
    Write-Host ""
    Write-Host "Sul sito: inserisci il codice/PIN e completa i dati richiesti." -ForegroundColor White
    Write-Host "IMPORTANTE: annota le credenziali per l'app mobile e consegnale al cliente." -ForegroundColor Yellow
    $fatto = Attendi-Risposta "Attivazione completata e credenziali annotate? (S/N)"
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
if (Test-Indietro $vuoiUnieuro) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
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
Write-Host "  S) Salta"
Write-Host ""

$sceltaBrowser = Chiedi "Scelta (es: 1,2 - S salta - B indietro)" "S"
if (Test-Indietro $sceltaBrowser) { $passo = [Math]::Max(3, $passo - 1); continue wizard }

if ($sceltaBrowser -match "^[Ss]$") {
    Write-Info "Browser saltati."
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
Write-Host "  3) PROFILO GAMING   (BASE + Steam, Epic, Discord, qBittorrent)"
Write-Host "  4) COMPLETO         (tutte le app in lista)"
Write-Host "  5) MANUALE          (scelgo io i singoli numeri)"
Write-Host "  S) Salta"
Write-Host ""

$sceltaApps = Attendi-Risposta "Scelta (1-5 - S salta - B indietro)"
if (Test-Indietro $sceltaApps) { $passo = [Math]::Max(3, $passo - 1); continue wizard }

switch ($sceltaApps) {
    "1" { Installa-Set -Ids $profili["BASE"] }
    "2" { Installa-Set -Ids $profili["UFFICIO"] }
    "3" { Installa-Set -Ids $profili["GAMING"] }   # l'app NVIDIA la mette il passo Driver
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
        $sceltaManuale = Attendi-Risposta "Numeri separati da virgola (es: 1,3,5)"
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
if (Test-Indietro $vuoiUpgrade) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
if ($vuoiUpgrade -match "^[Ss]") {
    if (Confirm-Winget) {
        Write-Info "Aggiornamento in corso (puo' richiedere diversi minuti)..."
        $null = Invoke-WingetConBarra -Nome "aggiornamenti app" -WingetArgs @('upgrade', '--all', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown')
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

# GPU NVIDIA: installo l'app NVIDIA (gestisce i driver video meglio della ricerca
# generica di Windows Update). Provo prima "NVIDIA App" (attuale), poi GeForce
# Experience come fallback. Va a prescindere dalla scelta su Windows Update.
if ((Test-GpuNvidia) -and (Confirm-Winget)) {
    Write-Info "GPU NVIDIA rilevata: installo l'app NVIDIA per i driver..."
    winget install --exact --id Nvidia.NvidiaApp --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        winget install --exact --id Nvidia.GeForceExperience --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    }
    if ($LASTEXITCODE -eq 0) {
        Write-OK "App NVIDIA installata: aprila per scaricare i driver piu' recenti."
        Add-Report "App NVIDIA (driver GeForce)" "OK"
    } else {
        Write-Info "App NVIDIA non installata (id/rete): scaricala da nvidia.com/it-it/software/nvidia-app/"
        Add-Report "App NVIDIA (driver GeForce)" "AVVISO"
    }
    Write-Host ""
}

$vuoiDriver = Chiedi "Cercare e installare i driver ora? (S/N, B=indietro)" "S"
if (Test-Indietro $vuoiDriver) { $passo = [Math]::Max(3, $passo - 1); continue wizard }
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
        try { $vLang = ((Get-InstalledLanguage -ErrorAction SilentlyContinue).LanguageId -contains 'it-IT') } catch { $vLang = $null }
        if ($null -ne $vLang) { $verifica += [pscustomobject]@{ N = 'Pacchetto lingua italiano'; Ok = $vLang } }
        $verifica += [pscustomobject]@{ N = 'OneDrive rimosso'; Ok = (-not (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe")) }
        $verifica += [pscustomobject]@{ N = 'Antivirus di prova rimossi'; Ok = (@(Get-AntivirusInstallati).Count -eq 0) }
        $verifica += [pscustomobject]@{ N = 'Windows attivato'; Ok = $winOk }

        # Mostro la verifica anche a schermo (oltre che nel file).
        Write-Titolo "Verifica finale"
        foreach ($v in $verifica) { if ($v.Ok) { Write-OK $v.N } else { Write-Errore "$($v.N): DA RIFARE" } }

        # --- Dettagli tecnici per l'assistenza (troubleshooting nello stesso file) ---
        $osInfo = $null; try { $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
        $wgVer = "n/d"; try { $wgVer = (winget --version) 2>$null } catch {}
        $resTxt = "n/d"; try { $resTxt = ($hres) } catch {}
        $avTxt = try { (@(Get-AntivirusInstallati).Nome | Select-Object -Unique) -join ', ' } catch { '' }
        if (-not $avTxt) { $avTxt = 'nessuno' }

        $sep = "------------------------------------------------------------"
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
    # Lavoro COMPLETATO: via il checkpoint di ripresa sessione (contiene anche
    # le credenziali generate: non deve restare sul PC del cliente).
    try {
        Remove-Item $Global:StatoFile -Force -ErrorAction SilentlyContinue
        Remove-Item (Split-Path $Global:StatoFile) -Force -ErrorAction SilentlyContinue
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
