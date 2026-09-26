#!/bin/zsh
# =============================================================================
# PC Facile.command - launcher doppio-click per setup-mac.sh (macOS)
# Gemello di "PC Facile.bat". Scarica SEMPRE l'ultima versione da GitHub e la
# esegue solo se il suo SHA256 combacia con setup-mac.sh.sha256; altrimenti usa
# la copia accanto (fallback offline). Doppio-click dal Finder.
# =============================================================================
cd "$(dirname "$0")" || exit 1

BASE="https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main"
BASE_CDN="https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main"
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

# Aggiornamento automatico della chiavetta: scarica manifest.txt e ogni file
# elencato (raw, poi jsDelivr), ne verifica lo SHA256 e solo allora sostituisce
# la copia accanto (file temporaneo + mv, atomico). In wifi/ scrive solo
# wifi.txt e UNIEURO_EXPO.xml (se elencati nel manifest). Se qualcosa fallisce restano i file attuali. Il manifest arriva
# dallo stesso posto dei file: protegge da corruzioni, non da manomissioni.
# Su macOS mv sostituisce il file (nuovo inode): anche questo .command, pur in
# esecuzione, si aggiorna senza problemi.
aggiorna_chiavetta() {
    # Solo se questa e' una cartella PC Facile (chiavetta o copia offline).
    [[ -f "./setup-mac.sh" || -f "./setup-pc.ps1" || "$PWD" == /Volumes/* ]] || return 0
    local man t riga hash nome dest tmpf base url ok
    man="$(mktemp -t pcf-manifest.XXXXXX)" || return 0
    t="$(date +%s)"
    if ! curl -fsSL "$BASE/manifest.txt?t=$t" -o "$man" 2>/dev/null &&
       ! curl -fsSL "$BASE_CDN/manifest.txt?t=$t" -o "$man" 2>/dev/null; then
        rm -f -- "$man"; echo "Aggiornamento chiavetta saltato (manifest non raggiungibile)."; return 0
    fi
    echo "Aggiorno i file della chiavetta (manifest.txt)..."
    while IFS= read -r riga || [[ -n "$riga" ]]; do
        riga="${riga%$'\r'}"
        [[ -z "$riga" || "$riga" == \#* ]] && continue
        [[ "$riga" =~ '^[0-9a-fA-F]{64} [ *].+$' ]] || continue
        hash="${(L)riga[1,64]}"
        nome="${riga[67,-1]}"
        # Percorsi sicuri soltanto: niente assoluti, "..", ":"; in wifi/ solo i file Wi-Fi previsti.
        [[ "$nome" == /* || "$nome" == *..* || "$nome" == *:* ]] && continue
        if [[ "${(L)nome}" == wifi/* && "${(L)nome}" != "wifi/wifi.txt" && "${(L)nome}" != "wifi/unieuro_expo.xml" ]]; then continue; fi
        dest="./$nome"
        if [[ -f "$dest" && "$(shasum -a 256 "$dest" 2>/dev/null | awk '{print tolower($1)}')" == "$hash" ]]; then
            continue
        fi
        mkdir -p -- "$(dirname -- "$dest")" 2>/dev/null
        tmpf="$dest.pcfacile-tmp"
        ok=false
        for base in "$BASE" "$BASE_CDN"; do
            url="$base/${nome// /%20}?t=$t"
            if curl -fsSL "$url" -o "$tmpf" 2>/dev/null &&
               [[ "$(shasum -a 256 "$tmpf" 2>/dev/null | awk '{print tolower($1)}')" == "$hash" ]]; then
                ok=true; break
            fi
        done
        if $ok; then
            [[ "$nome" == *.command || "$nome" == *.sh ]] && chmod +x "$tmpf" 2>/dev/null
            if mv -f -- "$tmpf" "$dest" 2>/dev/null; then echo "  aggiornato: $nome"; else rm -f -- "$tmpf"; fi
        else
            rm -f -- "$tmpf"
            echo "  non aggiornato (download o verifica SHA256 non riusciti): $nome"
        fi
    done < "$man"
    rm -f -- "$man"
}

echo "Scarico l'ultima versione da GitHub..."
if scarica_verificato; then
    echo "Scaricato e verificato (SHA256)."
    aggiorna_chiavetta
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
