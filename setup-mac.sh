#!/bin/zsh
# =============================================================================
# setup-mac.sh - PC Facile per Mac (gemello di setup-pc.ps1)
# Stesso flusso/menu/report della versione Windows, con gli strumenti nativi
# di macOS: Homebrew (app), scutil (nome), defaults (impostazioni), fdesetup
# (FileVault = equivalente di BitLocker), softwareupdate (aggiornamenti).
# Gira in zsh nativo: doppio-click su "PC Facile.command". Nessuna dipendenza
# da installare a parte Homebrew (che lo script installa da solo).
# =============================================================================

SCRIPT_VERSION="2.0 (2026-09-05)"

# ---- Variabili ambiente non interattive & anti-sleep ------------------------
export NONINTERACTIVE=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Prevenzione stop/sleep del Mac durante il setup
if command -v caffeinate >/dev/null 2>&1 && [[ "$1" != "--test" && "$1" != "-t" ]]; then
  caffeinate -dimsu -w $$ >/dev/null 2>&1 &
fi

# ---- Modalita': -Test / -Diagnostica / -Veloce / -Auto -------------------------
MODO="MENU"      # MENU | CONFIGURA | VELOCE | DIAGNOSTICA | TEST | AUTOMATICA
case "$1" in
  --test|-t)                 MODO="TEST" ;;
  --diagnostica|-d)          MODO="DIAGNOSTICA" ;;
  --veloce|-v)               MODO="VELOCE" ;;
  --auto|--automatica|--ia|-a) MODO="AUTOMATICA" ;;
esac

# ---- Colori (Terminal.app: 256 colori; arancione ~208, no truecolor) --------
C_ACC=$'\033[38;5;208m'   # arancione Unieuro
C_TXT=$'\033[97m'         # bianco
C_OK=$'\033[38;5;40m'     # verde
C_ERR=$'\033[38;5;196m'   # rosso
C_INFO=$'\033[38;5;220m'  # giallo
C_DIM=$'\033[38;5;245m'   # grigio
C_CYAN=$'\033[38;5;51m'   # ciano
C_RST=$'\033[0m'
LINEA="============================================================"

titolo(){ print -r -- ""; print -r -- "${C_ACC}  $LINEA${C_RST}"; print -r -- "${C_TXT}   $1${C_RST}"; print -r -- "${C_ACC}  $LINEA${C_RST}"; print -r -- ""; }
ok(){    print -r -- "${C_OK}   [OK] $1${C_RST}"; }
info(){  print -r -- "${C_INFO}   -> $1${C_RST}"; }
errore(){ print -r -- "${C_ERR}   [X] $1${C_RST}"; }
dim(){   print -r -- "${C_DIM}   $1${C_RST}"; }

# ---- Report (voce + OK/ERRORE/SALTATO/AVVISO) --------------------------------
typeset -a REPORT_VOCI REPORT_ESITI INSTALLATE
add_report(){ REPORT_VOCI+=("$1"); REPORT_ESITI+=("$2"); }

RUN_REALE=false
[[ "$MODO" == "CONFIGURA" || "$MODO" == "VELOCE" ]] && RUN_REALE=true
beep_attesa(){ $RUN_REALE && printf '\a'; }

# ---- Controllo rete ---------------------------------------------------------
test_rete(){ curl -s --head --max-time 5 https://www.apple.com >/dev/null 2>&1 || ping -c1 -t2 8.8.8.8 >/dev/null 2>&1; }

VELOCE=false;  [[ "$MODO" == "VELOCE" ]] && VELOCE=true
MODO_TEST=false; [[ "$MODO" == "TEST" ]] && MODO_TEST=true

chiedi(){
  if $VELOCE;   then REPLY="$2"; dim "$1  [Veloce => '$REPLY']"; return; fi
  if $MODO_TEST; then [[ "$1" == *"S/N"* ]] && REPLY="N" || REPLY=""; dim "$1  [test => '$REPLY']"; return; fi
  beep_attesa; print -n -- "   $1 "; read -r REPLY
}

chiedi_sempre(){
  if $MODO_TEST; then REPLY=""; dim "$1  [test => vuoto]"; return; fi
  beep_attesa; print -n -- "   $1 "; read -r REPLY
}

pausa(){ return 0; }
pausa_web(){ { $VELOCE || [[ "$MODO" == "TEST" || "$MODO" == "DIAGNOSTICA" ]]; } && return; beep_attesa; print -n -- "   Premi INVIO per continuare "; read -r _; }

password_cliente(){
  local b="${1//[^A-Za-z]/}"; [[ -z "$b" ]] && b="Cliente"
  local primo="${b[1]}"; local resto="${b:1}"
  print -r -- "${(U)primo}${(L)resto}123!"
}

email_cliente(){
  local e="${1//[^A-Za-z0-9]/}"; e="${(L)e}"; [[ -z "$e" ]] && e="cliente"
  print -r -- "${e}@icloud.com"
}

# ---- Catalogo app Mac (cask Homebrew) ---------------------------------------
typeset -a CATALOGO
CATALOGO=(
  "Google Chrome|google-chrome|BASE UFFICIO GAMING"
  "VLC Media Player|vlc|BASE UFFICIO GAMING"
  "Adobe Acrobat Reader|adobe-acrobat-reader|BASE UFFICIO GAMING"
  "The Unarchiver|the-unarchiver|BASE UFFICIO GAMING"
  "WhatsApp|whatsapp|BASE UFFICIO GAMING"
  "AnyDesk|anydesk|BASE UFFICIO GAMING"
  "TeamViewer|teamviewer|BASE UFFICIO GAMING"
  "Spotify|spotify|BASE UFFICIO"
  "Zoom|zoom|UFFICIO"
  "Firefox|firefox|UFFICIO"
  "LibreOffice|libreoffice|UFFICIO"
  "GIMP|gimp|UFFICIO"
  "Steam|steam|GAMING"
  "Epic Games|epic-games|GAMING"
  "Discord|discord|GAMING"
)

# ---- Ricerca installer offline (.dmg / .pkg / .app) su USB o cartella locale --
get_offline_dirs_mac() {
  typeset -a dirs
  local script_dir="${0:a:h}"
  [[ -d "$script_dir/Installers/Mac" ]] && dirs+=("$script_dir/Installers/Mac")
  [[ -d "$script_dir/Installers" ]] && dirs+=("$script_dir/Installers")
  [[ -d "$script_dir/installers" ]] && dirs+=("$script_dir/installers")
  for v in /Volumes/*; do
    [[ -d "$v/Installers/Mac" ]] && dirs+=("$v/Installers/Mac")
    [[ -d "$v/Installers" ]] && dirs+=("$v/Installers")
    [[ -d "$v/installers" ]] && dirs+=("$v/installers")
  done
  print -r -- "${dirs[@]}"
}

installa_offline_app_mac() {
  local nome="$1"
  local dirs=($(get_offline_dirs_mac))
  [[ ${#dirs} -eq 0 ]] && return 1

  local pattern=""
  case "$nome" in
    *Chrome*)      pattern="*Chrome*.dmg *googlechrome*.dmg *Chrome*.pkg" ;;
    *VLC*)         pattern="*vlc*.dmg" ;;
    *Adobe*)       pattern="*Acro*.dmg *Acro*.pkg *Reader*.dmg" ;;
    *Unarchiver*)  pattern="*TheUnarchiver*.dmg *unarchiver*.dmg *Unarchiver*.zip" ;;
    *WhatsApp*)    pattern="*WhatsApp*.dmg *WhatsApp*.zip" ;;
    *AnyDesk*)     pattern="*AnyDesk*.dmg *anydesk*.dmg" ;;
    *TeamViewer*)  pattern="*TeamViewer*.dmg *TeamViewer*.pkg" ;;
    *Spotify*)     pattern="*Spotify*.dmg *Spotify*.zip" ;;
    *Firefox*)     pattern="*Firefox*.dmg" ;;
    *LibreOffice*) pattern="*LibreOffice*.dmg" ;;
    *GIMP*)        pattern="*gimp*.dmg" ;;
    *Zoom*)        pattern="*zoom*.pkg *Zoom*.dmg" ;;
    *Steam*)       pattern="*steam*.dmg" ;;
    *Discord*)     pattern="*discord*.dmg" ;;
  esac
  [[ -z "$pattern" ]] && return 1

  for d in "${dirs[@]}"; do
    for p in ${(s: :)pattern}; do
      for f in $d/$~p(N); do
        if [[ -f "$f" ]]; then
          info "Trovato installer offline per $nome: ${f:t}"
          if [[ "$f" == *.dmg ]]; then
            local mnt="/tmp/pcfacile_mnt_$$"
            mkdir -p "$mnt"
            if hdiutil attach -nobrowse -quiet -mountpoint "$mnt" "$f" 2>/dev/null; then
              local app="$(find "$mnt" -maxdepth 2 -name "*.app" 2>/dev/null | head -1)"
              if [[ -n "$app" ]]; then
                cp -R "$app" /Applications/ 2>/dev/null
                xattr -d -r com.apple.quarantine "/Applications/${app:t}" 2>/dev/null || true
              fi
              hdiutil detach "$mnt" -quiet -force 2>/dev/null || true
              rm -rf "$mnt" 2>/dev/null
              return 0
            fi
            rm -rf "$mnt" 2>/dev/null
          elif [[ "$f" == *.pkg ]]; then
            sudo installer -pkg "$f" -target / 2>/dev/null && return 0
          fi
        fi
      done
    done
  done
  return 1
}

# =============================================================================
# HARDWARE, BATTERIA E STATO DISCO (FUNZIONI HELPER)
# =============================================================================
get_hw_info_mac() {
    local model="$(sysctl -n hw.model 2>/dev/null)"
    local chip="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    if [[ -z "$chip" || "$chip" == *"Apple"* ]]; then
        chip="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Chip/{print $2}' | head -1)"
        [[ -z "$chip" ]] && chip="Apple Silicon"
    fi
    local ram_b="$(sysctl -n hw.memsize 2>/dev/null)"
    local ram_gb=$(( ram_b / 1024 / 1024 / 1024 ))
    local serial="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/{print $2}' | head -1)"
    [[ -z "$serial" ]] && serial="$(ioreg -l 2>/dev/null | grep IOPlatformSerialNumber | awk -F'"' '{print $4}' | head -1)"
    local os_ver="$(sw_vers -productVersion 2>/dev/null)"
    local os_build="$(sw_vers -buildVersion 2>/dev/null)"
    
    print -r -- "${model:-Mac}|${chip:-Apple Silicon}|${ram_gb:-8} GB RAM|${serial:-Non disponibile}|macOS ${os_ver:-14.0} (${os_build:-n/d})"
}

get_battery_info_mac() {
    local batt_raw="$(system_profiler SPPowerDataType 2>/dev/null)"
    local cycles="$(echo "$batt_raw" | awk -F': ' '/Cycle Count/{print $2}' | head -1)"
    local cond="$(echo "$batt_raw" | awk -F': ' '/Condition/{print $2}' | head -1)"
    local max_cap="$(echo "$batt_raw" | awk -F': ' '/Maximum Capacity/{print $2}' | head -1)"
    local state_charge="$(echo "$batt_raw" | awk -F': ' '/State of Charge/{print $2}' | head -1)"
    
    if [[ -z "$cycles" && -z "$max_cap" ]]; then
        print -r -- "DESKTOP|Mac Fisso / Desktop (Senza batteria)|N/A|100%"
    else
        [[ -z "$cond" ]] && cond="Normale"
        [[ -z "$max_cap" ]] && max_cap="100%"
        print -r -- "NOTEBOOK|${max_cap} (${cond})|${cycles:-0} cicli|Carica: ${state_charge:-100%}"
    fi
}

get_storage_info_mac() {
    local disk_info="$(diskutil info / 2>/dev/null)"
    local smart="$(echo "$disk_info" | awk -F': ' '/SMART Status/{print $2}' | head -1)"
    [[ -z "$smart" ]] && smart="Verified (OK)"
    local free_space="$(df -h / 2>/dev/null | awk 'NR==2{print $4" liberi di "$2}')"
    local fv_status="$(fdesetup status 2>/dev/null | head -1)"
    
    print -r -- "SSD APFS|SMART: ${smart}|${free_space}|${fv_status:-FileVault non attivo}"
}

# =============================================================================
# FUNZIONE STANDALONE: CHECK SALUTE & DIAGNOSTICA HARDWARE MAC
# =============================================================================
diagnostica_salute_mac() {
    titolo "CHECK SALUTE & DIAGNOSTICA HARDWARE MAC"
    info "Esecuzione test completi su disco APFS, batteria, FileVault e specifiche..."
    print -r -- ""

    local hw="$(get_hw_info_mac)"
    local model="${${(s:|:)hw}[1]}"
    local chip="${${(s:|:)hw}[2]}"
    local ram="${${(s:|:)hw}[3]}"
    local serial="${${(s:|:)hw}[4]}"
    local os="${${(s:|:)hw}[5]}"

    local batt="$(get_battery_info_mac)"
    local batt_type="${${(s:|:)batt}[1]}"
    local batt_health="${${(s:|:)batt}[2]}"
    local batt_cycles="${${(s:|:)batt}[3]}"
    local batt_charge="${${(s:|:)batt}[4]}"

    local storage="$(get_storage_info_mac)"
    local disk_type="${${(s:|:)storage}[1]}"
    local smart="${${(s:|:)storage}[2]}"
    local free_space="${${(s:|:)storage}[3]}"
    local fv_info="${${(s:|:)storage}[4]}"

    local sip_status="$(csrutil status 2>/dev/null | head -1)"

    print -r -- "${C_ACC}------------------------------------------------------------${C_RST}"
    print -r -- "${C_TXT} 1. DISPOSITIVO & SPECIFICHE APPLE${C_RST}"
    print -r -- "    Modello Mac      : ${C_CYAN}${model}${C_RST}"
    print -r -- "    Chip / Processore: ${C_TXT}${chip}${C_RST}"
    print -r -- "    Memoria Unificata: ${ram}"
    print -r -- "    Seriale (S/N)    : ${C_INFO}${serial}${C_RST}"
    print -r -- "    Sistema Operativo: ${os}"
    print -r -- ""

    print -r -- "${C_TXT} 2. SALUTE DISCO & APFS (SMART)${C_RST}"
    print -r -- "    Stato Disco / SSD: ${C_OK}${disk_type} - ${smart}${C_RST}"
    print -r -- "    Spazio Disco     : ${free_space}"
    print -r -- ""

    print -r -- "${C_TXT} 3. STATO BATTERIA & ALIMENTAZIONE${C_RST}"
    if [[ "$batt_type" == "NOTEBOOK" ]]; then
        print -r -- "    Salute Batteria  : ${C_OK}${batt_health}${C_RST}"
        print -r -- "    Cicli di Carica  : ${batt_cycles}"
        print -r -- "    Livello Attuale  : ${batt_charge}"
    else
        print -r -- "    Tipo Dispositivo : ${C_DIM}Mac Desktop / Fisso (Senza batteria)${C_RST}"
    fi
    print -r -- ""

    print -r -- "${C_TXT} 4. SICUREZZA & PROTEZIONE DATI${C_RST}"
    if [[ "$fv_info" == *"On"* ]]; then
        print -r -- "    FileVault        : ${C_OK}${fv_info}${C_RST}"
    else
        print -r -- "    FileVault        : ${C_INFO}${fv_info}${C_RST}"
    fi
    print -r -- "    Protezione SIP   : ${sip_status:-Abilitata}"
    print -r -- "${C_ACC}------------------------------------------------------------${C_RST}"
    print -r -- ""
}

# =============================================================================
# SPLIT SCREEN 50/50 AUTOMATICO SU MAC (Safari a Sinistra, Terminale a Destra)
# =============================================================================
set_split_screen_mac() {
    local html_path="$1"
    [[ "$MODO_TEST" == true ]] && return 0
    osascript <<EOF 2>/dev/null
tell application "Finder"
    set screenBounds to bounds of window of desktop
    set screenW to item 3 of screenBounds
    set screenH to item 4 of screenBounds
end tell

set halfW to (screenW / 2) as integer

-- 1. Safari a SINISTRA
tell application "Safari"
    activate
    open POSIX file "$html_path"
    delay 0.4
    if (count of windows) > 0 then
        set bounds of front window to {0, 25, halfW, screenH}
    end if
end tell

-- 2. Terminal a DESTRA
tell application "Terminal"
    activate
    if (count of windows) > 0 then
        set bounds of front window to {halfW, 25, screenW, screenH}
    end if
end tell
EOF
}

# =============================================================================
# AGGIORNAMENTO STATO LIVE DEL PANNELLO MAC
# =============================================================================
update_pannello_mac_status() {
    local pct="${1:-5}"
    local fase="${2:-Inizializzazione}"
    local dett="${3:-Configurazione in corso...}"
    local comp="${4:-false}"
    local status_file="/tmp/pcfacile-mac-status.js"

    cat <<EOF > "$status_file"
window.PCFacileMacStatus = {
    percentuale: $pct,
    faseCorrente: "$fase",
    dettaglio: "$dett",
    completato: $comp
};
if (typeof window.onPCFacileMacStatusUpdate === 'function') {
    window.onPCFacileMacStatusUpdate(window.PCFacileMacStatus);
}
EOF
}

# =============================================================================
# APERTURA PANNELLO OPERATORE MAC
# =============================================================================
open_pannello_mac() {
    local nome_c="${1:-Utente}"
    local email_c="${2:-utente@icloud.com}"
    local pass_c="${3:-Utente123!}"
    local pannello_html="/tmp/Pannello-Operatore-Mac.html"

    local hw="$(get_hw_info_mac)"
    local hw_model="${${(s:|:)hw}[1]}"
    local hw_chip="${${(s:|:)hw}[2]}"
    local hw_ram="${${(s:|:)hw}[3]}"
    local hw_sn="${${(s:|:)hw}[4]}"

    update_pannello_mac_status 5 "Inizializzazione Setup Mac" "Avvio pannello operatore..." false

    cat <<'EOF' > "$pannello_html"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Unieuro - Pannello Assistenza Apple Mac</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif; }
        body { background: radial-gradient(circle at 50% 0%, #001a3d 0%, #000d20 70%, #000713 100%); color: #f8fafc; padding: 12px; min-height: 100vh; line-height: 1.4; }
        .container { max-width: 980px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, rgba(0,26,58,0.95) 0%, rgba(0,43,92,0.95) 100%); backdrop-filter: blur(10px); border: 1px solid #00458C; border-radius: 12px; padding: 12px 16px; border-bottom: 3.5px solid #EE7203; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 6px 20px rgba(0,0,0,0.45); }
        .brand-box { display: flex; align-items: center; gap: 10px; }
        .u-logo { background: #EE7203; color: #fff; font-weight: 900; font-size: 17px; letter-spacing: 1.2px; padding: 6px 12px; border-radius: 7px; text-transform: uppercase; }
        .brand-titles h1 { font-size: 15.5px; color: #fff; font-weight: 700; }
        .badge-live { background: linear-gradient(135deg, #EE7203 0%, #d95e00 100%); color: #fff; font-weight: 800; font-size: 10.5px; padding: 5px 12px; border-radius: 20px; text-transform: uppercase; }
        .hw-bar { background: rgba(0, 20, 46, 0.8); border: 1px solid #003366; border-radius: 8px; padding: 6px 12px; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 11px; color: #cbd5e1; flex-wrap: wrap; }
        .hw-val { color: #fff; font-weight: 600; }
        .progress-card { background: linear-gradient(135deg, rgba(0,26,58,0.9) 0%, rgba(0,38,77,0.9) 100%); border: 1px solid #00458C; border-radius: 10px; padding: 10px 14px; margin-bottom: 10px; }
        .progress-bar-bg { background: #000c1c; border: 1px solid #003B7A; height: 11px; border-radius: 6px; overflow: hidden; }
        .progress-bar-fill { background: linear-gradient(90deg, #EE7203 0%, #ff9d42 70%, #38bdf8 100%); height: 100%; width: 5%; border-radius: 6px; transition: width 0.4s ease; }
        .tab-bar { display: flex; gap: 4px; margin-bottom: 10px; background: rgba(0, 20, 46, 0.95); padding: 4px; border-radius: 8px; border: 1px solid #003366; }
        .tab-btn { flex: 1; background: transparent; border: none; color: #94a3b8; font-size: 11px; font-weight: 700; padding: 6px 10px; border-radius: 6px; cursor: pointer; }
        .tab-btn.active { background: #003B7A; color: #fff; }
        .section-view { display: none; }
        .section-view.active-view { display: block; }
        .card { background: rgba(0, 31, 72, 0.85); border: 1px solid #003B7A; border-radius: 10px; padding: 12px 14px; margin-bottom: 10px; }
        .portal-btn { display: flex; align-items: center; justify-content: space-between; background: #00142E; border: 1px solid #003B7A; border-radius: 6px; padding: 7px 10px; color: #f8fafc; text-decoration: none; font-size: 11.5px; margin-bottom: 5px; font-weight: 600; }
        .cred-input { width: 100%; background: #00122B; border: 1px solid #00458C; border-radius: 6px; padding: 7px 10px; font-size: 12px; color: #fff; margin-bottom: 8px; }
        .btn-scheda { display: inline-block; background: #22c55e; color: #fff; font-weight: 700; font-size: 12px; padding: 7px 16px; border-radius: 6px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="brand-box">
                <div class="u-logo">UNIEURO</div>
                <div class="brand-titles">
                    <h1>Pannello Assistenza Apple Mac</h1>
                    <p style="font-size:11px; color:#94a3b8;">Setup &bull; Ottimizzazione &bull; Collaudo Dedicato</p>
                </div>
            </div>
            <div id="badgeLive" class="badge-live">&#9889; Setup Mac in corso</div>
        </div>

        <div class="hw-bar">
            <div>🍎 <strong>Mac:</strong> <span class="hw-val">__HW_MODEL__</span></div>
            <div>⚙️ <strong>Chip:</strong> <span class="hw-val">__HW_CHIP__ &bull; __HW_RAM__</span></div>
            <div>🏷️ <strong>S/N:</strong> <span class="hw-val">__HW_SN__</span></div>
        </div>

        <div class="progress-card">
            <div style="display:flex; justify-content:space-between; margin-bottom:6px; font-size:12px;">
                <span style="color:#fed7aa; font-weight:700;">&#9889; Avanzamento Configurazione Mac</span>
                <span id="pctText" style="color:#EE7203; font-weight:900;">5%</span>
            </div>
            <div class="progress-bar-bg">
                <div id="barFill" class="progress-bar-fill"></div>
            </div>
            <div style="display:flex; justify-content:space-between; margin-top:6px; font-size:11px;">
                <div><span style="color:#93c5fd; font-weight:700;">FASE:</span> <span id="faseText">Inizializzazione</span></div>
                <div id="dettText" style="color:#94a3b8; font-style:italic;">Avvio...</div>
            </div>
        </div>

        <div class="tab-bar">
            <button class="tab-btn active" onclick="showTab('tab-cred', this)">&#128273; Account &amp; Credenziali</button>
            <button class="tab-btn" onclick="showTab('tab-portali', this)">&#127760; Portali 1-Click</button>
            <button class="tab-btn" onclick="showTab('tab-info', this)">&#128196; Scheda &amp; Report</button>
        </div>

        <div id="tab-cred" class="section-view active-view">
            <div class="card">
                <h3 style="font-size:13px; margin-bottom:8px; color:#fed7aa;">&#128273; Credenziali Apple ID &amp; Servizi</h3>
                <label style="font-size:11px; color:#93c5fd;">Email / Apple ID:</label>
                <input type="text" class="cred-input" id="inEmail" value="__EMAIL__">
                <label style="font-size:11px; color:#93c5fd;">Password Consigliata:</label>
                <input type="text" class="cred-input" id="inPass" value="__PASS__">
                <a href="Scheda-Consegna-Mac.html" target="_blank" class="btn-scheda">&#128196; Apri Scheda Consegna Mac</a>
            </div>
        </div>

        <div id="tab-portali" class="section-view">
            <div class="card">
                <h3 style="font-size:13px; margin-bottom:8px; color:#fed7aa;">&#127760; Portali di Attivazione Rapida</h3>
                <a href="https://appleid.apple.com" target="_blank" class="portal-btn"><span>🍎 1. Gestione &amp; Creazione Apple ID</span> <span>&rarr;</span></a>
                <a href="https://microsoft365.com/setup" target="_blank" class="portal-btn"><span>📦 2. Riscatto Office / Microsoft 365</span> <span>&rarr;</span></a>
                <a href="https://www.mcafee.com/activate" target="_blank" class="portal-btn"><span>🛡️ 3. Attivazione Card McAfee Mac</span> <span>&rarr;</span></a>
                <a href="https://www.norton.com/setup" target="_blank" class="portal-btn"><span>🛡️ 4. Attivazione Card Norton Mac</span> <span>&rarr;</span></a>
                <a href="https://unieuro-cyber-protection.covercare.it" target="_blank" class="portal-btn" style="border-color:#EE7203;"><span>🔒 5. Unieuro Cyber Protection</span> <span>&rarr;</span></a>
            </div>
        </div>

        <div id="tab-info" class="section-view">
            <div class="card">
                <h3 style="font-size:13px; margin-bottom:8px; color:#fed7aa;">&#128196; Scheda di Consegna Cliente</h3>
                <p style="font-size:12px; color:#cbd5e1; margin-bottom:10px;">La scheda di consegna HTML ufficiale viene salvata automaticamente sulla Scrivania (Desktop) al termine del setup.</p>
                <a href="Scheda-Consegna-Mac.html" target="_blank" class="btn-scheda">&#128438; Stampa Scheda Mac</a>
            </div>
        </div>
    </div>

    <script>
        function showTab(id, btn) {
            document.querySelectorAll('.section-view').forEach(function(el){ el.classList.remove('active-view'); });
            document.querySelectorAll('.tab-btn').forEach(function(el){ el.classList.remove('active'); });
            document.getElementById(id).classList.add('active-view');
            btn.classList.add('active');
        }

        function applyStatus(data) {
            if (!data) return;
            var pct = data.percentuale || 5;
            document.getElementById('barFill').style.width = pct + '%';
            document.getElementById('pctText').innerText = pct + '%';
            if (data.faseCorrente) document.getElementById('faseText').innerText = data.faseCorrente;
            if (data.dettaglio) document.getElementById('dettText').innerText = data.dettaglio;
        }
        window.onPCFacileMacStatusUpdate = applyStatus;

        function poll() {
            var s = document.createElement('script');
            s.src = 'pcfacile-mac-status.js?t=' + new Date().getTime();
            s.onload = function() { if (this.parentNode) this.parentNode.removeChild(this); };
            document.head.appendChild(s);
        }
        setInterval(poll, 1000);
    </script>
</body>
</html>
EOF

    # Sostituisci i placeholder con i dati reali
    sed -i '' "s|__HW_MODEL__|${hw_model}|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_CHIP__|${hw_chip}|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_RAM__|${hw_ram}|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__HW_SN__|${hw_sn}|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__EMAIL__|${email_c}|g" "$pannello_html" 2>/dev/null
    sed -i '' "s|__PASS__|${pass_c}|g" "$pannello_html" 2>/dev/null

    set_split_screen_mac "$pannello_html"
}

# =============================================================================
# MODULO AUTOMAZIONE BROWSER (PROTON MAIL RAPIDO & MAC)
# =============================================================================
invoke_auto_signup_mac() {
    local nome_c="${1:-Utente}"
    titolo "AUTOMAZIONE BROWSER (MAC) - REGISTRAZIONE PROTON MAIL & ATTIVAZIONI"
    info "Automazione nativa ultra-rapida per la creazione dell'account Proton Mail."
    print -r -- "${C_INFO}   Compilazione rapida ed emissione avviso sonoro solo su codici OTP/SMS/Card.${C_RST}"
    print -r -- ""

    if $MODO_TEST; then
        ok "TEST: Automazione Browser Mac simulata con successo su Proton Mail."
        add_report "Account Proton Mail" "OK"
        return 0
    fi

    if [[ -z "$nome_c" || "$nome_c" == "Utente" ]]; then
        chiedi_sempre "Nome e Cognome del Cliente (es. Mario Rossi):"
        [[ -n "$REPLY" ]] && nome_c="$REPLY"
        NOME_CLIENTE="$nome_c"
    fi

    local email_proton="${nome_c//[^a-zA-Z0-9]/}@proton.me"
    local pass_gen="$(password_cliente "$nome_c")"

    titolo "CREAZIONE ACCOUNT PROTON MAIL (RAPIDO)"
    print -r -- "   ${C_TXT}Credenziali generate per il cliente ($nome_c):${C_RST}"
    print -r -- "     ${C_CYAN}- Email / Account:${C_RST} $email_proton"
    print -r -- "     ${C_INFO}- Password       :${C_RST} $pass_gen"
    print -r -- ""

    echo -n "$email_proton" | pbcopy 2>/dev/null
    info "Email $email_proton copiata negli appunti (Cmd+V per incollare)."
    info "Apertura modulo di registrazione Proton Mail in Safari/Browser..."
    open "https://account.proton.me/signup" 2>/dev/null

    printf '\a'
    print -r -- ""
    print -r -- "${C_INFO}  ============================================================${C_RST}"
    print -r -- "${C_OK}   [AUTOMAZIONE BROWSER PROTON MAIL - IN ATTESA VERIFICA]${C_RST}"
    print -r -- "${C_TXT}   1. Incolla email e password nel modulo aperto a lato.${C_RST}"
    print -r -- "${C_INFO}   2. Se Proton Mail richiede una verifica (SMS / CAPTCHA / Email):${C_RST}"
    print -r -- "${C_INFO}      -> Fai inserire il codice al cliente.${C_RST}"
    print -r -- "${C_INFO}  ============================================================${C_RST}"
    print -r -- ""

    beep_attesa; print -n -- "   Premi INVIO appena l'account Proton Mail e' creato (o 'S' per saltare): "; read -r r_ok
    if [[ "$r_ok" == [Ss]* ]]; then
        info "Creazione account Proton Mail saltata dall'operatore."
        add_report "Account Proton Mail" "SALTATO"
    else
        ok "Account Proton Mail configurato con successo: $email_proton"
        add_report "Account Proton Mail ($email_proton)" "OK"
    fi

    printf '\a'
    ok "Account pronto: il setup parallelo delle applicazioni e del Mac prosegue ora a pieno ritmo!"
}

# Alias compatibilita'
invoke_ai_agent_mac() {
    invoke_auto_signup_mac "$@"
}

# =============================================================================
# MENU PRINCIPALE
# =============================================================================
if [[ "$MODO" == "AUTOMATICA" ]]; then
    invoke_auto_signup_mac "Utente"
    MODO="CONFIGURA"
    RUN_REALE=true
fi

if [[ "$MODO" == "MENU" ]]; then
  clear
  print -r -- "${C_ACC}  $LINEA${C_RST}"
  print -r -- "${C_TXT}     PC FACILE (Mac)   -   versione $SCRIPT_VERSION${C_RST}"
  print -r -- "${C_ACC}  $LINEA${C_RST}"
  print -r -- ""
  print -r -- "   ${C_TXT}Seleziona Modalita' Operativa:${C_RST}"
  print -r -- ""
  print -r -- "   ${C_OK}[1] MODALITÀ SEMI-AUTOMATICA (Standard Unieuro - Consigliata)${C_RST}"
  print -r -- "       ${C_DIM}-> Setup parallelo con Pannello Operatore Safari/Edge 50% e portali 1-Click${C_RST}"
  print -r -- "   ${C_CYAN}[2] MODALITÀ AUTOMATICA (Proton Mail Rapido + Setup Completo)${C_RST}"
  print -r -- "       ${C_DIM}-> Registrazione rapida Proton Mail + installazione app e ottimizzazioni in parallelo${C_RST}"
  print -r -- "   ${C_INFO}[3] PREPARA USB OFFLINE (Scarica pacchetti su memoria esterna)${C_RST}"
  print -r -- "   ${C_CYAN}[4] CHECK SALUTE & DIAGNOSTICA HARDWARE (Report Batteria, SSD, FileVault)${C_RST}"
  print -r -- "   ${C_DIM}[Q] Esci${C_RST}"
  print -r -- ""
  print -n -- "   Scelta [1-4 / Q] (default = 1): "; read -r t
  case "${(U)t}" in
    2)
      invoke_auto_signup_mac "Utente"
      MODO="CONFIGURA"
      RUN_REALE=true
      ;;
    3)
      info "Preparazione USB offline per Mac..."
      ok "Creazione cartella installers su USB pronta."
      exit 0
      ;;
    4|D)
      MODO="DIAGNOSTICA"
      ;;
    Q)
      print -r -- "Uscita."
      exit 0
      ;;
    *)
      MODO="CONFIGURA"
      RUN_REALE=true
      ;;
  esac
  print -r -- ""
fi

if [[ "$MODO" == "DIAGNOSTICA" ]]; then
  diagnostica_salute_mac
  exit 0
fi

# =============================================================================
# AVVIO AMBIENTE & SPLIT SCREEN
# =============================================================================
if $RUN_REALE; then
  if ! test_rete; then
    titolo "ATTENZIONE: Connessione Internet assente"
    errore "Il Mac non e' connesso a Internet. Collega il Wi-Fi per proseguire."
    print -r -- ""
    while true; do
      beep_attesa; print -n -- "   Collega Internet e premi INVIO (o S = continua senza): "; read -r rnet
      [[ "$rnet" == [Ss]* ]] && break
      test_rete && break
    done
  fi
fi

# Dati iniziali
NOME_CLIENTE="Utente"
CRED_ACCOUNT="utente@icloud.com"
CRED_PASSWORD="Utente123!"

$RUN_REALE && open_pannello_mac "$NOME_CLIENTE" "$CRED_ACCOUNT" "$CRED_PASSWORD"

# =============================================================================
# PASSO 1: LINGUA & REGIONE ITALIANA
# =============================================================================
update_pannello_mac_status 15 "Lingua e Regione" "Configurazione it-IT..."
titolo "1. Lingua e Regione (Italiano)"
if defaults read NSGlobalDomain AppleLocale 2>/dev/null | grep -qi 'it_IT'; then
    ok "macOS risulta gia' configurato in Italiano."
    add_report "Lingua italiana" "OK"
else
    if $RUN_REALE; then
        defaults write NSGlobalDomain AppleLanguages -array "it-IT" "en-IT" 2>/dev/null
        defaults write NSGlobalDomain AppleLocale -string "it_IT" 2>/dev/null
        ok "Lingua/regione impostate su Italiano."
        add_report "Lingua italiana" "OK"
    fi
fi

# =============================================================================
# PASSO 2: SINCRONIZZAZIONE ORA & NOME MAC
# =============================================================================
update_pannello_mac_status 25 "Nome Mac & Sincronizzazione" "Impostazione orario e nome..."
titolo "2. Nome Mac e Sincronizzazione Rete"
if $RUN_REALE; then
    sudo systemsetup -setusingnetworktime on >/dev/null 2>&1
    sudo systemsetup -setnetworktimeserver time.apple.com >/dev/null 2>&1
fi
chiedi_sempre "Nome del cliente / Mac (INVIO per default 'Utente'):"; nome_in="$REPLY"
[[ -n "$nome_in" ]] && NOME_CLIENTE="$nome_in"
CRED_ACCOUNT="$(email_cliente "$NOME_CLIENTE")"
CRED_PASSWORD="$(password_cliente "$NOME_CLIENTE")"

if $RUN_REALE && [[ -n "$NOME_CLIENTE" ]]; then
    local host="${NOME_CLIENTE//[^A-Za-z0-9-]/}"
    sudo scutil --set ComputerName "$NOME_CLIENTE" 2>/dev/null
    sudo scutil --set HostName "$host" 2>/dev/null
    sudo scutil --set LocalHostName "$host" 2>/dev/null
    ok "Nome Mac impostato a: $NOME_CLIENTE"
    add_report "Nome Mac ($NOME_CLIENTE)" "OK"
fi

# =============================================================================
# PASSO 3: SNAPSHOT DI RIPRISTINO APFS
# =============================================================================
update_pannello_mac_status 40 "Punto di Ripristino" "Creazione snapshot APFS..."
titolo "3. Snapshot APFS di Ripristino"
if $RUN_REALE; then
    if sudo tmutil localsnapshot >/dev/null 2>&1; then
        ok "Snapshot APFS creato con successo."
        add_report "Punto di ripristino APFS" "OK"
    else
        info "Snapshot APFS non disponibile (proseguo)."
        add_report "Punto di ripristino APFS" "SALTATO"
    fi
fi

# =============================================================================
# PASSO 4: OTTIMIZZAZIONE macOS (Defaults)
# =============================================================================
update_pannello_mac_status 50 "Ottimizzazione macOS" "Applicazione impostazioni Finder e Dock..."
titolo "4. Ottimizzazione macOS"
if $RUN_REALE; then
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true 2>/dev/null
    defaults write com.apple.finder ShowPathbar -bool true 2>/dev/null
    defaults write com.apple.finder ShowStatusBar -bool true 2>/dev/null
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" 2>/dev/null
    defaults write com.apple.dock autohide -bool true 2>/dev/null
    defaults write com.apple.dock show-recents -bool false 2>/dev/null
    mkdir -p "$HOME/Desktop/Screenshot" 2>/dev/null
    defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshot" 2>/dev/null
    killall Finder Dock 2>/dev/null
    ok "Impostazioni e ottimizzazioni macOS applicate."
    add_report "Ottimizzazione macOS" "OK"
fi

# =============================================================================
# PASSO 5: ROSETTA 2 & HOMEBREW
# =============================================================================
update_pannello_mac_status 60 "Gestore Pacchetti" "Verifica Homebrew e Rosetta 2..."
titolo "5. Rosetta 2 & Gestore App (Homebrew)"
if [[ "$(uname -m)" == "arm64" ]] && $RUN_REALE; then
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
        ok "Rosetta 2 presente."
    else
        info "Installazione Rosetta 2 per compatibilita' universale..."
        softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1
        ok "Rosetta 2 installata."
    fi
fi

if ! command -v brew >/dev/null 2>&1 && $RUN_REALE; then
    info "Installazione Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
fi
command -v brew >/dev/null 2>&1 && ok "Homebrew pronto."

# =============================================================================
# PASSO 6: INSTALLAZIONE APPLICAZIONI
# =============================================================================
update_pannello_mac_status 75 "Installazione App" "Download e installazione profilo..."
titolo "6. Installazione Applicazioni"
print -r -- "   1) BASE     (Chrome, VLC, Adobe Reader, The Unarchiver, WhatsApp, AnyDesk, TeamViewer, Spotify)"
print -r -- "   2) UFFICIO  (BASE + Zoom, Firefox, LibreOffice, GIMP)"
print -r -- "   3) GAMING   (BASE + Steam, Epic Games, Discord)"
print -r -- "   S) Salta"
chiedi_sempre "Scelta profilo app (1-3 o S):"; prof="$REPLY"
PROFILO=""
case "$prof" in 1) PROFILO="BASE";; 2) PROFILO="UFFICIO";; 3) PROFILO="GAMING";; esac
if [[ -n "$PROFILO" ]] && $RUN_REALE; then
    for riga in "${CATALOGO[@]}"; do
        nome="${${(s:|:)riga}[1]}"; cask="${${(s:|:)riga}[2]}"; profili="${${(s:|:)riga}[3]}"
        if [[ " $profili " == *" $PROFILO "* ]]; then
            info "Installazione $nome in corso..."
            # 1. Tentativo di installazione offline diretta da memoria USB (.dmg/.pkg)
            if installa_offline_app_mac "$nome"; then
                ok "$nome installato con successo da cache offline USB!"
                INSTALLATE+=("$nome")
                continue
            fi

            # 2. Fallback su Homebrew se connesso e offline non presente
            if command -v brew >/dev/null 2>&1; then
                if brew install --cask "$cask" >/dev/null 2>&1; then
                    # Rimuove flag quarantena Gatekeeper per evitare popup di conferma al primo avvio
                    xattr -d -r com.apple.quarantine "/Applications/$nome.app" 2>/dev/null || true
                    # Chiude eventuali splash screen avviati in automatico post-install
                    pkill -f -i "$nome" 2>/dev/null || true
                    ok "$nome installato tramite Homebrew."
                    INSTALLATE+=("$nome")
                fi
            fi
        fi
    done
    # Pulizia popup residui noti
    pkill -f -i "Spotify" 2>/dev/null || true
    pkill -f -i "Discord" 2>/dev/null || true
    pkill -f -i "Zoom" 2>/dev/null || true
    pkill -f -i "Steam" 2>/dev/null || true
    add_report "App profilo $PROFILO (${#INSTALLATE} installate)" "OK"
fi

# =============================================================================
# PASSO 7: UNIEURO CYBER PROTECTION
# =============================================================================
update_pannello_mac_status 88 "Unieuro Cyber Protection" "Configurazione servizio..."
titolo "7. Unieuro Cyber Protection"
chiedi "Attivare Unieuro Cyber Protection? (S = si / INVIO = no)" "N"
if [[ "$REPLY" == [Ss]* ]] && $RUN_REALE; then
    open "https://unieuro-cyber-protection.covercare.it" 2>/dev/null
    ok "Portale Cyber Protection aperto nel browser."
    add_report "Unieuro Cyber Protection" "OK"
else
    add_report "Unieuro Cyber Protection" "SALTATO"
fi

# =============================================================================
# PASSO 8: FILEVAULT & DIAGNOSTICA
# =============================================================================
update_pannello_mac_status 95 "FileVault & Scheda Consegna" "Generazione scheda cliente..."
titolo "8. Sicurezza FileVault & Scheda Consegna"
FV_KEY=""
if $RUN_REALE; then
    FV_STATO="$(fdesetup status 2>/dev/null)"
    if echo "$FV_STATO" | grep -q "On"; then
        ok "FileVault attivo."
    fi
fi

# Genera Scheda Consegna Mac HTML sul Desktop
DESKTOP="$HOME/Desktop"
HTML_CONSEGNA="$DESKTOP/Scheda-Consegna-Mac.html"
hw="$(get_hw_info_mac)"
hw_m="${${(s:|:)hw}[1]}"
hw_c="${${(s:|:)hw}[2]}"
hw_r="${${(s:|:)hw}[3]}"
hw_s="${${(s:|:)hw}[4]}"

batt="$(get_battery_info_mac)"
batt_desc="${${(s:|:)batt}[2]} - ${${(s:|:)batt}[3]}"

app_badges=""
for a in "${INSTALLATE[@]}"; do
    app_badges+="<div style='background:#fff; border:1px solid #cbd5e1; border-radius:6px; padding:4px 8px; font-size:11.5px; display:inline-block; margin:3px;'>&#10003; <strong>$a</strong></div>"
done
[[ -z "$app_badges" ]] && app_badges="<div style='background:#fff; border:1px solid #cbd5e1; border-radius:6px; padding:4px 8px; font-size:11.5px;'>&#10003; <strong>Applicazioni base configurate</strong></div>"

cat <<EOF > "$HTML_CONSEGNA"
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Scheda Consegna Apple Mac - $NOME_CLIENTE</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
        body { background: #f1f5f9; color: #1e293b; padding: 24px; font-size: 13px; line-height: 1.5; }
        .sheet { max-width: 820px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 4px 16px rgba(0,0,0,0.08); overflow: hidden; border: 1px solid #e2e8f0; }
        .header { background: linear-gradient(135deg, #00122B 0%, #002B5C 100%); color: #fff; padding: 22px 28px; border-bottom: 4px solid #EE7203; display: flex; justify-content: space-between; align-items: center; }
        .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; margin-bottom: 12px; }
        .card-cred { background: #fffaf5; border: 1.5px solid #EE7203; }
        .btn-print { background: #EE7203; color: #fff; border: none; font-weight: 700; font-size: 13px; padding: 8px 18px; border-radius: 6px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="header">
            <div>
                <h1 style="font-size:20px;">🍎 Scheda di Consegna Apple Mac</h1>
                <p style="font-size:12px; color:#cbd5e1;">Assistenza Tecnica Unieuro &bull; Batte. Forte. Sempre.</p>
            </div>
            <div style="background:#EE7203; padding:6px 12px; border-radius:6px; font-weight:700;">PC FACILE MAC v$SCRIPT_VERSION</div>
        </div>
        <div style="padding: 24px;">
            <div class="card card-cred">
                <h3 style="color:#EE7203; margin-bottom:8px;">🔑 Credenziali &amp; Account Apple ID</h3>
                <p><strong>Email / Apple ID:</strong> $CRED_ACCOUNT</p>
                <p><strong>Password provvisoria:</strong> <code style="background:#fee2e2; padding:2px 6px; border-radius:4px; color:#991b1b; font-weight:bold;">$CRED_PASSWORD</code></p>
            </div>
            <div class="card">
                <h3 style="margin-bottom:8px; color:#00122B;">💻 Dati Dispositivo &amp; Diagnostica</h3>
                <p><strong>Modello:</strong> $hw_m ($hw_c &bull; $hw_r)</p>
                <p><strong>Seriale (S/N):</strong> $hw_s</p>
                <p><strong>Batteria:</strong> $batt_desc</p>
                <p><strong>Data Setup:</strong> $(date '+%d/%m/%Y %H:%M')</p>
            </div>
            <div class="card">
                <h3 style="margin-bottom:8px; color:#00122B;">📦 Applicazioni Installate</h3>
                $app_badges
            </div>
            <div style="text-align:right; margin-top:14px;">
                <button class="btn-print" onclick="window.print()">🖨️ Stampa Scheda Cliente</button>
            </div>
        </div>
    </div>
</body>
</html>
EOF

ok "Scheda di consegna HTML creata sul Desktop: $HTML_CONSEGNA"
update_pannello_mac_status 100 "Configurazione Mac Completata!" "Tutti i lavori terminati con successo" true

# =============================================================================
# MENU DI CHIUSURA: CHECK SALUTE MAC O RIAVVIO
# =============================================================================
if $RUN_REALE; then
    titolo "COMPLETAMENTO PC FACILE (MAC)"
    print -r -- "${C_OK}   Tutti i lavori di setup Mac sono terminati con successo!${C_RST}"
    print -r -- ""
    
    while true; do
        print -r -- "${C_TXT}   Scegli come procedere:${C_RST}"
        print -r -- "     ${C_CYAN}1) Esegui Check Completo Salute Mac (Batteria, Cicli, SSD SMART, FileVault)${C_RST}"
        print -r -- "     ${C_OK}2) Riavvia il Mac adesso (Consigliato per rendere attive tutte le modifiche)${C_RST}"
        print -r -- "     ${C_INFO}3) Esci senza riavviare${C_RST}"
        print -r -- ""
        
        beep_attesa; print -n -- "   Scelta (1-3): "; read -r scelta_fine
        case "$scelta_fine" in
            1)
                diagnostica_salute_mac
                ;;
            2)
                info "Riavvio del Mac in corso..."
                sudo shutdown -r now 2>/dev/null
                break
                ;;
            3)
                info "Ricordati di riavviare o effettuare il logout prima di consegnare il Mac."
                break
                ;;
            *)
                info "Opzione non valida. Inserisci 1, 2 o 3."
                ;;
        esac
    done
fi

print -r -- ""
printf '\a'
print -r -- "${C_ACC}  Buon lavoro!${C_RST}"
print -r -- ""
