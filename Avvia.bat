@echo off
title Avvio PC Pro
REM ============================================================
REM  Avvia.bat - launcher doppio-click per setup-pc.ps1
REM  - Si auto-eleva ad amministratore (UAC)
REM  - Se setup-pc.ps1 e' accanto: lo esegue (funziona OFFLINE)
REM  - Altrimenti scarica l'ultima versione da GitHub ed esegue
REM  Basta questo solo file: doppio click e parte.
REM ============================================================

REM --- Auto-elevazione: se non sono admin, mi rilancio come admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Richiesta privilegi di amministratore...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM --- Se lo script e' accanto al .bat, usalo (uso offline da USB) ---
if exist "%~dp0setup-pc.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1"
    goto :fine
)

REM --- Altrimenti scarica ed esegue l'ultima versione da GitHub ---
echo setup-pc.ps1 non trovato: scarico l'ultima versione da GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { irm 'https://raw.githubusercontent.com/samuelenigro97-prog/test-setup-pc/main/setup-pc.ps1' | iex } catch { Write-Host 'Errore: serve una connessione a Internet, oppure copia setup-pc.ps1 accanto a Avvia.bat.' -ForegroundColor Red }"

:fine
pause
