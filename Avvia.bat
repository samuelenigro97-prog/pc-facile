@echo off
title Avvio PC Pro
REM ============================================================
REM  Avvia.bat - lancia setup-pc.ps1 come amministratore
REM  Doppio click su questo file: chiede UAC e parte lo script.
REM  Tieni Avvia.bat e setup-pc.ps1 nella STESSA cartella.
REM ============================================================

REM --- Auto-elevazione: se non sono admin, mi rilancio come admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Richiesta privilegi di amministratore...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM --- Verifica che lo script sia accanto al .bat ---
if not exist "%~dp0setup-pc.ps1" (
    echo ERRORE: setup-pc.ps1 non trovato in questa cartella.
    echo Metti Avvia.bat e setup-pc.ps1 nella stessa cartella e riprova.
    pause
    exit /b 1
)

REM --- Avvia lo script con ExecutionPolicy Bypass ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1"

pause
