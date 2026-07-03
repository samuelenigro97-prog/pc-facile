@echo off
title Avvio PC Pro
REM ============================================================
REM  Avvia.bat - launcher doppio-click per setup-pc.ps1
REM  - Si auto-eleva ad amministratore (UAC)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Usa setup-pc.ps1 accanto (offline) o lo scarica da GitHub
REM  Il MENU (Configura/Diagnostica/Test) e' nello script, prima schermata.
REM ============================================================

REM --- Auto-elevazione: se non sono admin, mi rilancio come admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Richiesta privilegi di amministratore...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM --- Se setup-pc.ps1 e' accanto al .bat, uso quello (offline da USB) ---
if exist "%~dp0setup-pc.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1"
    goto :fine
)

REM --- Altrimenti scarico ed eseguo IN MEMORIA (bypassa il blocco script) ---
echo Scarico l'ultima versione da GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/samuelenigro97-prog/test-setup-pc/main/setup-pc.ps1'))) } catch { Write-Host ('Errore: ' + $_) -ForegroundColor Red }"

:fine
echo.
pause
