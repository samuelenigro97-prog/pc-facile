#!/bin/zsh
# =============================================================================
# PC Facile.command - launcher doppio-click per setup-mac.sh (macOS)
# Gemello di "PC Facile.bat". Scarica SEMPRE l'ultima versione da GitHub;
# la copia accanto e' il fallback offline. Doppio-click dal Finder.
# =============================================================================
cd "$(dirname "$0")" || exit 1

URL="https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main/setup-mac.sh"
TMP="/tmp/setup-mac.sh"

echo "Scarico l'ultima versione da GitHub..."
if curl -fsSL "$URL?t=$(date +%s)" -o "$TMP" 2>/dev/null; then
    zsh "$TMP"
elif [[ -f "./setup-mac.sh" ]]; then
    echo "Offline: uso la copia accanto (potrebbe non essere l'ultima)."
    zsh "./setup-mac.sh"
else
    echo "Impossibile scaricare e nessuna copia locale: controlla la rete."
fi

echo ""
echo "============================================================"
echo "  Operazione terminata. Premi INVIO per chiudere."
echo "============================================================"
read -r _
