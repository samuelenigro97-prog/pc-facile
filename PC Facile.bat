@echo off
title PC Facile
REM ============================================================
REM  PC Facile.bat - launcher doppio-click per setup-pc.ps1
REM  - Si auto-eleva ad amministratore (UAC)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Usa setup-pc.ps1 accanto (offline) o lo scarica su file e lo lancia
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

REM --- Altrimenti scarico su file temporaneo e lo lancio con -File (stabile) ---
echo Scarico l'ultima versione da GitHub...
set "PS1=%TEMP%\setup-pc.ps1"
if exist "%PS1%" del "%PS1%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { irm 'https://raw.githubusercontent.com/samuelenigro97-prog/test-setup-pc/main/setup-pc.ps1' -OutFile '%PS1%' } catch { Write-Host ('Download fallito: ' + $_) -ForegroundColor Red }"
if exist "%PS1%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
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
