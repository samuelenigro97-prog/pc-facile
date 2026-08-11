@echo off
title PC Facile
REM ============================================================
REM  PC Facile.bat - launcher doppio-click per setup-pc.ps1
REM  - Si auto-eleva ad amministratore (UAC)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Scarica SEMPRE l'ultima versione da GitHub; la copia accanto al .bat
REM    e' solo il fallback offline (cosi' si aggiorna da solo, niente USB stale)
REM  Il MENU (Configura/Diagnostica/Test) e' nello script, prima schermata.
REM ============================================================

:run
REM --- Auto-elevazione: se non sono admin, mi rilancio come admin (nuova
REM     finestra, gia' post-reg -> colori ok). Passo la sentinella "run". ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Richiesta privilegi di amministratore...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'run' -Verb RunAs"
    exit /b
)

REM --- Scarico SEMPRE l'ultima versione da GitHub su file temporaneo ---
REM     (cache-buster sull'URL per evitare copie vecchie della CDN) ---
REM     Poi VERIFICO l'integrita' con lo SHA256 pubblicato accanto allo script:
REM     scarico setup-pc.ps1.sha256, calcolo l'hash del file scaricato e li
REM     confronto. Se non combaciano (download corrotto/troncato) scarto il
REM     file e uso il fallback offline. Se l'hash non e' disponibile, proseguo.
echo Scarico l'ultima versione da GitHub...
set "PS1=%TEMP%\setup-pc.ps1"
set "CORE=%TEMP%\src\PcFacile.Core.psm1"
set "COREHASH=%TEMP%\src\PcFacile.Core.psm1.sha256"
if exist "%PS1%" del "%PS1%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $t=(Get-Date -UFormat %%s); $base='https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main'; New-Item (Split-Path '%CORE%') -ItemType Directory -Force | Out-Null; irm ($base+'/setup-pc.ps1?t='+$t) -OutFile '%PS1%'; irm ($base+'/src/PcFacile.Core.psm1?t='+$t) -OutFile '%CORE%'; irm ($base+'/src/PcFacile.Core.psm1.sha256?t='+$t) -OutFile '%COREHASH%'; $atteso=(((irm ($base+'/setup-pc.ps1.sha256?t='+$t)).Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); $coreAtteso=((Get-Content '%COREHASH%' -Raw).Trim() -split '\s+')[0].ToLower(); $coreReale=(Get-FileHash '%CORE%' -Algorithm SHA256).Hash.ToLower(); if ($reale -ne $atteso -or $coreReale -ne $coreAtteso) { throw 'Impronta SHA256 non corrispondente' }; Write-Host 'Integrita'' verificata (SHA256).' -ForegroundColor Green } catch { Write-Host ('Download non valido: '+$_) -ForegroundColor Yellow; Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue }"

REM --- Se il download e' riuscito uso quello (SEMPRE aggiornato) ---
if exist "%PS1%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
    goto :fine
)

REM --- Offline: fallback sulla copia accanto al .bat (chiavetta) ---
if exist "%~dp0setup-pc.ps1" if exist "%~dp0src\PcFacile.Core.psm1" if exist "%~dp0src\PcFacile.Core.psm1.sha256" (
    echo Offline: uso la copia sulla chiavetta ^(potrebbe non essere l'ultima^).
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1"
) else (
    echo.
    echo Impossibile scaricare lo script: controlla la connessione a Internet,
    echo oppure copia setup-pc.ps1 sulla chiavetta accanto a PC Facile.bat.
)

:fine
echo.
echo ============================================================
echo   Operazione terminata. Premi un tasto per chiudere.
echo ============================================================
pause >nul
