#!/bin/zsh
# =============================================================================
# setup-mac.sh - PC Facile per Mac (gemello di setup-pc.ps1)
# Stesso flusso/menu/report della versione Windows, con gli strumenti nativi
# di macOS: Homebrew (app), scutil (nome), defaults (impostazioni), fdesetup
# (FileVault = equivalente di BitLocker), softwareupdate (aggiornamenti).
# Gira in zsh nativo: doppio-click su "PC Facile.command". Nessuna dipendenza
# da installare a parte Homebrew (che lo script installa da solo).
# =============================================================================

SCRIPT_VERSION="0.3 (2026-07-06)"

# ---- Modalita' (come su Windows): -Test / -Diagnostica / -Veloce -------------
MODO="MENU"      # MENU | CONFIGURA | VELOCE | DIAGNOSTICA | TEST
case "$1" in
  --test|-t)        MODO="TEST" ;;
  --diagnostica|-d) MODO="DIAGNOSTICA" ;;
  --veloce|-v)      MODO="VELOCE" ;;
esac

# ---- Colori (Terminal.app: 256 colori; arancione ~208, no truecolor) --------
C_ACC=$'\033[38;5;208m'   # arancione Unieuro (approx 256-color)
C_TXT=$'\033[97m'         # bianco
C_OK=$'\033[38;5;40m'     # verde
C_ERR=$'\033[38;5;196m'   # rosso
C_INFO=$'\033[38;5;220m'  # giallo
C_DIM=$'\033[38;5;245m'   # grigio
C_RST=$'\033[0m'
LINEA="============================================================"

titolo(){ print -r -- ""; print -r -- "${C_ACC}  $LINEA${C_RST}"; print -r -- "${C_TXT}   $1${C_RST}"; print -r -- "${C_ACC}  $LINEA${C_RST}"; print -r -- ""; }
ok(){    print -r -- "${C_OK}   [OK] $1${C_RST}"; }
info(){  print -r -- "${C_INFO}   -> $1${C_RST}"; }
errore(){ print -r -- "${C_ERR}   [X] $1${C_RST}"; }
dim(){   print -r -- "${C_DIM}   $1${C_RST}"; }

# ---- Report (equivalente di Add-Report: voce + OK/ERRORE/SALTATO/AVVISO) -----
typeset -a REPORT_VOCI REPORT_ESITI INSTALLATE
add_report(){ REPORT_VOCI+=("$1"); REPORT_ESITI+=("$2"); }

# ---- Avviso sonoro a fine passo (equivalente [console]::Beep) ----------------
RUN_REALE=false
[[ "$MODO" == "CONFIGURA" || "$MODO" == "VELOCE" ]] && RUN_REALE=true
beep_fine(){ $RUN_REALE && printf '\a'; }

# ---- Chiedi / chiedi_sempre --------------------------------------------------
VELOCE=false;  [[ "$MODO" == "VELOCE" ]] && VELOCE=true
MODO_TEST=false; [[ "$MODO" == "TEST" ]] && MODO_TEST=true
# chiedi: domanda automatizzabile. In Veloce risponde con $2; in Test risponde
# in modo NON distruttivo (N ai S/N, vuoto ai menu). Come l'helper Chiedi Windows.
chiedi(){   # $1=prompt  $2=auto(Veloce)
  if $VELOCE;   then REPLY="$2"; dim "$1  [Veloce => '$REPLY']"; return; fi
  if $MODO_TEST; then [[ "$1" == *"S/N"* ]] && REPLY="N" || REPLY=""; dim "$1  [test => '$REPLY']"; return; fi
  print -n -- "   $1 "; read -r REPLY
}
# chiedi_sempre: domanda che va SEMPRE posta (nome, app, account) anche in
# Veloce; solo in Test non blocca e ritorna vuoto.
chiedi_sempre(){  # $1=prompt
  if $MODO_TEST; then REPLY=""; dim "$1  [test => vuoto]"; return; fi
  print -n -- "   $1 "; read -r REPLY
}

# ---- Pausa (no-op in Veloce/Test/Diagnostica, come su Windows) ---------------
pausa(){ { $VELOCE || [[ "$MODO" == "TEST" || "$MODO" == "DIAGNOSTICA" ]]; } && return; print -n -- "   Premi INVIO per continuare "; read -r _; }

# ---- Generatori credenziali (come New-PasswordCliente/New-EmailCliente) -----
password_cliente(){  # $1=nome  ->  Rossi123!
  local b="${1//[^A-Za-z]/}"; [[ -z "$b" ]] && b="Cliente"
  local primo="${b[1]}"; local resto="${b:1}"
  print -r -- "${(U)primo}${(L)resto}123!"
}
email_cliente(){     # $1=nome  ->  rossi417@icloud.com
  local e="${1//[^A-Za-z0-9]/}"; e="${(L)e}"; [[ -z "$e" ]] && e="cliente"
  print -r -- "${e}$((RANDOM % 900 + 100))@icloud.com"
}

# ---- Catalogo app = cask Homebrew, con profili (come $CatalogoApp) -----------
# formato: "Nome|cask|profili"
typeset -a CATALOGO
CATALOGO=(
  "VLC|vlc|BASE UFFICIO GAMING"
  "Adobe Acrobat Reader|adobe-acrobat-reader|BASE UFFICIO GAMING"
  "The Unarchiver|the-unarchiver|BASE UFFICIO GAMING"
  "WhatsApp|whatsapp|BASE UFFICIO GAMING"
  "AnyDesk|anydesk|BASE UFFICIO GAMING"
  "TeamViewer|teamviewer|BASE UFFICIO GAMING"
  "Google Chrome|google-chrome|BASE UFFICIO GAMING"
  "Firefox|firefox|UFFICIO"
  "Zoom|zoom|UFFICIO"
  "Spotify|spotify|UFFICIO"
  "GIMP|gimp|UFFICIO"
  "LibreOffice|libreoffice|UFFICIO"
  "Steam|steam|GAMING"
  "Epic Games|epic-games|GAMING"
  "Discord|discord|GAMING"
)

# =============================================================================
# MENU (se non e' arrivata una modalita' da parametro)
# =============================================================================
if [[ "$MODO" == "MENU" ]]; then
  clear
  print -r -- "${C_ACC}  $LINEA${C_RST}"
  print -r -- "${C_TXT}     PC FACILE (Mac)   -   versione $SCRIPT_VERSION${C_RST}"
  print -r -- "${C_ACC}  $LINEA${C_RST}"
  print -r -- ""
  print -r -- "   ${C_ACC}[C]${C_RST} Configura il Mac   (installa e imposta, chiede tutto)"
  print -r -- "   ${C_ACC}[V]${C_RST} Veloce             (automatico: chiede solo nome e app)"
  print -r -- "   ${C_ACC}[D]${C_RST} Diagnostica        (controlla, NON installa)"
  print -r -- "   ${C_ACC}[T]${C_RST} Test a vuoto       (percorre tutto, NON installa)"
  print -r -- ""
  print -n -- "   Scelta (C/V/D/T): "; read -r t
  case "${(U)t}" in
    V) MODO="VELOCE";      VELOCE=true;  RUN_REALE=true ;;
    D) MODO="DIAGNOSTICA" ;;
    T) MODO="TEST" ;;
    *) MODO="CONFIGURA";   RUN_REALE=true ;;
  esac
  print -r -- ""
fi
[[ "$MODO" == "VELOCE" ]] && info "MODALITA' VELOCE: automatica, chiede solo nome e app"
[[ "$MODO" == "TEST"   ]] && info "MODALITA' TEST: nessuna modifica reale"

# =============================================================================
# DIAGNOSTICA: controlla ambiente + valida i cask, non installa nulla
# =============================================================================
if [[ "$MODO" == "DIAGNOSTICA" ]]; then
  titolo "DIAGNOSTICA (v$SCRIPT_VERSION) - nessuna modifica"
  if command -v brew >/dev/null 2>&1; then ok "Homebrew presente: $(brew --version | head -1)"; else errore "Homebrew NON installato"; fi
  info "Stato FileVault:"; fdesetup status 2>/dev/null | sed 's/^/     /'
  info "Validazione cask (brew info):"
  if command -v brew >/dev/null 2>&1; then
    for riga in "${CATALOGO[@]}"; do
      cask="${${(s:|:)riga}[2]}"
      if brew info --cask "$cask" >/dev/null 2>&1; then ok "$cask"; else errore "$cask (id non trovato)"; fi
    done
  else
    dim "Salto la validazione: manca Homebrew."
  fi
  print -r -- ""; ok "Diagnostica finita."; exit 0
fi

# =============================================================================
# STEP 0 - LINGUA / REGIONE ITALIANA
# =============================================================================
titolo "Lingua e Regione (Italiano)"
chiedi "Impostare macOS in Italiano (it-IT)? (S/N)" "S"
if [[ "$REPLY" == [Ss]* ]]; then
  if $RUN_REALE; then
    defaults write NSGlobalDomain AppleLanguages -array "it-IT" "en-IT" 2>/dev/null
    defaults write NSGlobalDomain AppleLocale -string "it_IT" 2>/dev/null
    ok "Lingua/regione impostate su Italiano (attive dopo il logout)."
    add_report "Lingua italiana" "OK"
  else
    dim "(test) imposterei AppleLanguages/AppleLocale su it-IT"
    add_report "Lingua italiana" "SALTATO"
  fi
else
  add_report "Lingua italiana" "SALTATO"
fi
pausa

# =============================================================================
# NOME CLIENTE E MAC (prima voce dopo la lingua, come su Windows)
# =============================================================================
titolo "Nome Cliente e Mac"
info "Nome Mac attuale: $(scutil --get ComputerName 2>/dev/null)"
chiedi_sempre "Nome del cliente (nome Mac) - INVIO per saltare:"; NOME_CLIENTE="$REPLY"
NOME_CLIENTE="${NOME_CLIENTE## }"; NOME_CLIENTE="${NOME_CLIENTE%% }"
if [[ -n "$NOME_CLIENTE" ]]; then
  host="${NOME_CLIENTE//[^A-Za-z0-9-]/}"
  if $RUN_REALE; then
    sudo scutil --set ComputerName "$NOME_CLIENTE" 2>/dev/null
    sudo scutil --set HostName "$host" 2>/dev/null
    sudo scutil --set LocalHostName "$host" 2>/dev/null
    ok "Mac rinominato in '$NOME_CLIENTE'."
    add_report "Nome cliente ($NOME_CLIENTE)" "OK"
  else
    dim "(test) rinominerei il Mac in '$NOME_CLIENTE'"
    add_report "Nome cliente" "SALTATO"
  fi
else
  info "Nome non modificato."
  add_report "Nome cliente" "SALTATO"
fi
pausa

# =============================================================================
# PUNTO DI RIPRISTINO - snapshot APFS (equivalente del Restore Point Windows)
# =============================================================================
titolo "Punto di Ripristino (snapshot)"
chiedi "Creare uno snapshot di ripristino ora? (consigliato) (S/N)" "S"
if [[ "$REPLY" == [Ss]* ]]; then
  if $RUN_REALE; then
    if sudo tmutil localsnapshot >/dev/null 2>&1; then ok "Snapshot APFS creato."; add_report "Punto di ripristino (snapshot)" "OK"
    else errore "Snapshot non riuscito (Time Machine/APFS?)."; add_report "Punto di ripristino (snapshot)" "ERRORE"; fi
  else
    dim "(test) creerei uno snapshot APFS con tmutil localsnapshot"; add_report "Punto di ripristino (snapshot)" "SALTATO"
  fi
else
  add_report "Punto di ripristino (snapshot)" "SALTATO"
fi
pausa

# =============================================================================
# ACCOUNT / CREDENZIALI (Apple ID via GUI; qui prepariamo le credenziali)
# =============================================================================
titolo "Account e Credenziali"
CRED_ACCOUNT=""; CRED_PASSWORD=""
chiedi "Aprire la pagina Apple ID per accedere/creare l'account? (S/N)" "S"
if [[ "$REPLY" == [Ss]* ]]; then
  $RUN_REALE && open "https://appleid.apple.com" 2>/dev/null
  ok "Pagina Apple ID aperta."
  if $RUN_REALE; then
    chiedi_sempre "Il cliente ha GIA' una sua email/password? (S=inserisco / N=genero):"; ha="$REPLY"
    if [[ "$ha" == [Ss]* ]]; then
      print -n -- "   Email del cliente: "; read -r CRED_ACCOUNT
      print -n -- "   Password del cliente: "; read -r CRED_PASSWORD
    else
      CRED_ACCOUNT="$(email_cliente "$NOME_CLIENTE")"
      CRED_PASSWORD="$(password_cliente "$NOME_CLIENTE")"
      info "Email suggerita : $CRED_ACCOUNT"
      info "Password        : $CRED_PASSWORD"
    fi
    # Copia la password negli appunti (equivalente Set-Clipboard)
    [[ -n "$CRED_PASSWORD" ]] && printf '%s' "$CRED_PASSWORD" | pbcopy 2>/dev/null && info "Password copiata negli appunti."
  fi
  add_report "Account Apple ID" "OK"
else
  add_report "Account Apple ID" "SALTATO"
fi
pausa

# =============================================================================
# OTTIMIZZAZIONE macOS - comodita' via defaults (equivalente Config Windows).
# Niente debloat OEM: macOS non ha crapware del produttore da rimuovere.
# =============================================================================
titolo "Ottimizzazione macOS"
print -r -- "   Comodita': estensioni file visibili, path bar nel Finder, vista lista,"
print -r -- "   cartella screenshot dedicata, Dock che si nasconde."
print -r -- ""
chiedi "Applicare queste impostazioni? (S/N)" "S"
if [[ "$REPLY" == [Ss]* ]]; then
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
    ok "Impostazioni applicate."
    add_report "Ottimizzazione macOS" "OK"
  else
    dim "(test) applicherei impostazioni Finder/Dock/screenshot"
    add_report "Ottimizzazione macOS" "SALTATO"
  fi
else
  add_report "Ottimizzazione macOS" "SALTATO"
fi
pausa

# =============================================================================
# HOMEBREW (necessario per installare le app)
# =============================================================================
titolo "Homebrew (gestore app)"
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew gia' presente."
else
  chiedi "Homebrew non c'e'. Installarlo ora? (serve per le app) (S/N)" "S"
  if [[ "$REPLY" == [Ss]* ]] && $RUN_REALE; then
    info "Installazione Homebrew (puo' chiedere la password e qualche minuto)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
    command -v brew >/dev/null 2>&1 && ok "Homebrew installato." || errore "Installazione Homebrew non riuscita."
  else
    dim "(test/salta) installerei Homebrew"
  fi
fi
pausa

# =============================================================================
# APP (profili BASE / UFFICIO / GAMING, come su Windows)
# =============================================================================
titolo "Applicazioni"
print -r -- "   1) BASE     (VLC, Reader, Unarchiver, WhatsApp, AnyDesk, TeamViewer, Chrome)"
print -r -- "   2) UFFICIO  (BASE + Firefox, Zoom, Spotify, GIMP, LibreOffice)"
print -r -- "   3) GAMING   (BASE + Steam, Epic, Discord)"
print -r -- "   S) Salta"
chiedi_sempre "Scelta (1-3 o S):"; prof="$REPLY"
PROFILO=""
case "$prof" in 1) PROFILO="BASE";; 2) PROFILO="UFFICIO";; 3) PROFILO="GAMING";; esac
if [[ -n "$PROFILO" ]]; then
  n_ok=0
  for riga in "${CATALOGO[@]}"; do
    nome="${${(s:|:)riga}[1]}"; cask="${${(s:|:)riga}[2]}"; profili="${${(s:|:)riga}[3]}"
    if [[ " $profili " == *" $PROFILO "* ]]; then
      if $RUN_REALE && command -v brew >/dev/null 2>&1; then
        info "Installo $nome..."
        if brew install --cask "$cask" >/dev/null 2>&1; then ok "$nome"; ((n_ok++)); INSTALLATE+=("$nome"); else errore "$nome (installazione fallita)"; fi
      else
        dim "(test) installerei $nome ($cask)"
      fi
    fi
  done
  add_report "App profilo $PROFILO ($n_ok installate)" "OK"
else
  info "App saltate."
  add_report "App" "SALTATO"
fi
beep_fine; pausa

# =============================================================================
# UNIEURO CYBER PROTECTION (opzionale, come su Windows: solo portale web)
# =============================================================================
titolo "Unieuro Cyber Protection"
chiedi "Attivare Unieuro Cyber Protection? (S/N)" "N"
if [[ "$REPLY" == [Ss]* ]]; then
  $RUN_REALE && open "https://unieuro-cyber-protection.covercare.it" 2>/dev/null
  ok "Portale aperto: inserisci il codice e annota le credenziali dell'app."
  add_report "Unieuro Cyber Protection" "OK"
else
  add_report "Unieuro Cyber Protection" "SALTATO"
fi
pausa

# =============================================================================
# AGGIORNAMENTI (app brew + macOS = equivalente driver/Windows Update)
# =============================================================================
titolo "Aggiornamenti"
chiedi "Aggiornare app (brew) e macOS ora? (S/N)" "S"
if [[ "$REPLY" == [Ss]* ]] && $RUN_REALE; then
  command -v brew >/dev/null 2>&1 && { info "brew upgrade..."; brew upgrade >/dev/null 2>&1; ok "App aggiornate."; }
  info "Controllo aggiornamenti macOS..."; softwareupdate -l 2>/dev/null | sed 's/^/     /'
  add_report "Aggiornamenti" "OK"
else
  dim "(test/salta) aggiornerei brew + macOS"
  add_report "Aggiornamenti" "SALTATO"
fi
beep_fine; pausa

# =============================================================================
# FILEVAULT - CHIAVE DI RIPRISTINO (equivalente di BitLocker)
# Il piu' tardi possibile. DATO SENSIBILE: la recovery key da' accesso completo
# al disco; finisce nel report che resta col Mac del cliente (voluto: senza,
# dopo un reset o un problema il cliente resta chiuso fuori dai dati).
# =============================================================================
titolo "FileVault - Chiave di Ripristino"
FV_STATO="sconosciuto"; FV_KEY=""
if $RUN_REALE; then
  FV_STATO="$(fdesetup status 2>/dev/null)"
  if print -r -- "$FV_STATO" | grep -q "On"; then
    info "FileVault gia' attivo: rigenero una recovery key personale da salvare."
    # changerecovery -personal rigenera e STAMPA una nuova personal recovery key
    out="$(sudo fdesetup changerecovery -personal 2>/dev/null)"
    FV_KEY="$(print -r -- "$out" | grep -oE '[A-Z0-9]{4}(-[A-Z0-9]{4}){5}' | head -1)"
  else
    chiedi "FileVault e' spento. Attivarlo ora e salvare la chiave? (S/N)" "S"
    if [[ "$REPLY" == [Ss]* ]]; then
      out="$(sudo fdesetup enable -outputplist 2>/dev/null)"
      FV_KEY="$(print -r -- "$out" | grep -oE '[A-Z0-9]{4}(-[A-Z0-9]{4}){5}' | head -1)"
    fi
  fi
  if [[ -n "$FV_KEY" ]]; then ok "Chiave FileVault salvata nel riepilogo."; add_report "Chiave di ripristino FileVault" "OK"
  elif print -r -- "$FV_STATO" | grep -q "On"; then errore "FileVault attivo ma chiave non ottenuta."; add_report "Chiave di ripristino FileVault" "AVVISO"
  else info "FileVault non attivo: nessuna chiave da salvare."; add_report "Chiave di ripristino FileVault" "SALTATO"; fi
else
  dim "(test) leggerei fdesetup status e salverei la recovery key"
  add_report "Chiave di ripristino FileVault" "SALTATO"
fi
beep_fine; pausa

# =============================================================================
# REPORT FINALE (.txt sul Desktop, come su Windows)
# =============================================================================
if $RUN_REALE; then
  DESKTOP="$HOME/Desktop"
  FILE="$DESKTOP/Riepilogo-Mac_$(date +%Y%m%d_%H%M).txt"
  {
    print -r -- "$LINEA"
    print -r -- "   RIEPILOGO CONFIGURAZIONE MAC"
    print -r -- "$LINEA"
    print -r -- ""
    print -r -- "Data     : $(date '+%d/%m/%Y %H:%M')"
    print -r -- "Cliente  : ${NOME_CLIENTE:-(non impostato)}"
    print -r -- "Nome Mac : $(scutil --get ComputerName 2>/dev/null)"
    print -r -- "macOS    : $(sw_vers -productVersion 2>/dev/null)"
    print -r -- ""
    print -r -- "------------------------------------------------------------"
    print -r -- "STATO SISTEMA"
    print -r -- "------------------------------------------------------------"
    print -r -- "  Chip        : $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    print -r -- "  Disco       : $(df -h / | awk 'NR==2{print $4" liberi"}')"
    print -r -- "  FileVault   : $(fdesetup status 2>/dev/null | head -1)"
    print -r -- ""
    print -r -- "------------------------------------------------------------"
    print -r -- "SOFTWARE INSTALLATO"
    print -r -- "------------------------------------------------------------"
    if (( ${#INSTALLATE} )); then for a in "${INSTALLATE[@]}"; do print -r -- "  - $a"; done; else print -r -- "  (nessuno)"; fi
    print -r -- ""
    print -r -- "------------------------------------------------------------"
    print -r -- "OPERAZIONI"
    print -r -- "------------------------------------------------------------"
    for i in {1..${#REPORT_VOCI}}; do printf "  [%-8s] %s\n" "${REPORT_ESITI[$i]}" "${REPORT_VOCI[$i]}"; done
    print -r -- ""
    print -r -- "------------------------------------------------------------"
    print -r -- "CHIAVE DI RIPRISTINO FILEVAULT  (DATO SENSIBILE: accesso al disco)"
    print -r -- "------------------------------------------------------------"
    if [[ -n "$FV_KEY" ]]; then
      print -r -- "  Recovery key : $FV_KEY"
      print -r -- "  >> CONSERVA questa chiave: senza, dopo un reset non accedi ai dati."
    else
      print -r -- "  (nessuna chiave: FileVault spento o non attivato)"
    fi
    print -r -- ""
    print -r -- "------------------------------------------------------------"
    print -r -- "NOTE / CREDENZIALI"
    print -r -- "------------------------------------------------------------"
    print -r -- "  Account Apple ID : ${CRED_ACCOUNT:-______________________________}"
    print -r -- "  Password         : ${CRED_PASSWORD:-______________________________}"
    print -r -- ""
    print -r -- "$LINEA"
  } > "$FILE"
  ok "Riepilogo salvato sul Desktop: $FILE"
fi

print -r -- ""
$RUN_REALE && printf '\a'
print -r -- "${C_ACC}  Buon lavoro!${C_RST}"
print -r -- ""
