#!/bin/zsh
# =============================================================================
# PC Facile.command - launcher doppio-click per setup-mac.sh (macOS)
# Gemello di "PC Facile.bat". Scarica SEMPRE l'ultima versione da GitHub e la
# esegue solo se il suo SHA256 combacia con setup-mac.sh.sha256; altrimenti usa
# la copia accanto (fallback offline). Doppio-click dal Finder.
# =============================================================================
cd "$(dirname "$0")" || exit 1

BASE="https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main"
# File temporaneo univoco (mktemp), non un percorso fisso e prevedibile in /tmp.
TMP="$(mktemp -t setup-mac.XXXXXX)" || { echo "Impossibile creare un file temporaneo."; exit 1; }
trap 'rm -f -- "$TMP"' EXIT

scarica_verificato() {
    local t atteso reale
    t="$(date +%s)"
    curl -fsSL "$BASE/setup-mac.sh?t=$t" -o "$TMP" 2>/dev/null || return 1
    atteso="$(curl -fsSL "$BASE/setup-mac.sh.sha256?t=$t" 2>/dev/null | awk '{print tolower($1); exit}')"
    reale="$(shasum -a 256 "$TMP" 2>/dev/null | awk '{print tolower($1)}')"
    [[ "$atteso" =~ '^[0-9a-f]{64}$' && "$reale" == "$atteso" ]]
}

echo "Scarico l'ultima versione da GitHub..."
if scarica_verificato; then
    echo "Scaricato e verificato (SHA256)."
    zsh "$TMP"
elif [[ -f "./setup-mac.sh" ]]; then
    echo "Download non riuscito o impronta SHA256 non valida: uso la copia accanto (potrebbe non essere l'ultima)."
    zsh "./setup-mac.sh"
else
    echo "Impossibile scaricare/verificare lo script e nessuna copia locale: controlla la rete."
fi

echo ""
echo "============================================================"
echo "  Operazione terminata. Premi INVIO per chiudere."
echo "============================================================"
read -r _
