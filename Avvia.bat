@echo off
title Avvio PC Pro
REM ============================================================
REM  Avvia.bat - launcher doppio-click per setup-pc.ps1
REM  - Si auto-eleva ad amministratore (UAC)
REM  - Menu: Configura / Diagnostica / Test
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Usa setup-pc.ps1 accanto (offline) o lo scarica da GitHub
REM ============================================================

REM --- Auto-elevazione: se non sono admin, mi rilancio come admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Richiesta privilegi di amministratore...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo ============================================================
echo    AVVIO PC PRO
echo ============================================================
echo.
echo    1) Configura il PC   (installa e imposta)
echo    2) Diagnostica       (controlla, NON installa)
echo    3) Test a vuoto      (percorre tutto, NON installa)
echo.
set /p scelta="Scelta (1/2/3, INVIO=1): "

set "modo="
if "%scelta%"=="2" set "modo=-Diagnostica"
if "%scelta%"=="3" set "modo=-Test"

REM --- Se setup-pc.ps1 e' accanto al .bat, uso quello (offline da USB) ---
if exist "%~dp0setup-pc.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" %modo%
    goto :fine
)

REM --- Altrimenti scarico ed eseguo IN MEMORIA: bypassa il blocco script
REM     e passa i parametri (-Diagnostica/-Test) correttamente ---
echo.
echo Scarico l'ultima versione da GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/samuelenigro97-prog/test-setup-pc/main/setup-pc.ps1'))) %modo% } catch { Write-Host ('Errore: ' + $_) -ForegroundColor Red }"

:fine
echo.
pause
