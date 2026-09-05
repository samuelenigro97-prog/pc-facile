@echo off
title PC Facile
REM ============================================================
REM  PC Facile.bat - launcher ottimizzato 1-Click per setup-pc.ps1
REM  - Elevazione amministratore immediata (UN SOLO prompt UAC)
REM  - Sblocco automatico file (elimina gli avvisi SmartScreen/Apri file)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Scarica l'ultima versione da GitHub con fallback offline su USB
REM ============================================================

REM --- 1. Elevazione immediata ad amministratore (1 solo popup UAC) ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated %*' -Verb RunAs"
    exit /b
)

REM Consuma l'argomento sentinel se rilanciato da elevazione
if /i "%~1"=="elevated" shift
if /i "%~1"=="run" shift

set "USER_ARGS=%1 %2 %3 %4 %5 %6 %7 %8 %9"
set "USER_ARGS=%USER_ARGS:   = %"
set "USER_ARGS=%USER_ARGS:  = %"

REM --- 2. Impostazioni console e sblocco file da blocchi Windows ---
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Console" /v FaceName /t REG_SZ /d "Consolas" /f >nul 2>&1
reg add "HKCU\Console" /v FontWeight /t REG_DWORD /d 700 /f >nul 2>&1

REM Sblocca automaticamente i file della chiavetta per eliminare gli avvisi "Apri file / SmartScreen"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

REM --- 3. Scarica l'ultima versione da GitHub (con fallback offline) ---
set "HAS_LOCAL="
if exist "%~dp0setup-pc.ps1" set "HAS_LOCAL=1"

echo Scarico l'ultima versione da GitHub...
del "%TEMP%\setup-pc*.ps1" /f /q >nul 2>&1
set "PS1=%TEMP%\setup-pc-%RANDOM%%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; $bases=@('https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main','https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'); $done=$false; foreach($base in $bases){ if($done){break}; for($i=1;$i -le 2 -and -not $done;$i++){ try { $t=(Get-Date -UFormat %%s); irm ($base+'/setup-pc.ps1?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -OutFile '%PS1%' -ErrorAction Stop; try { $atteso=(((irm ($base+'/setup-pc.ps1.sha256?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -ErrorAction Stop).Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); if ($atteso -and $reale -ne $atteso) { Write-Host 'Impronta SHA256 non combacia: scarto.' -ForegroundColor Yellow; Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue } else { Write-Host ('Scaricato e verificato da: '+$base) -ForegroundColor Green; $done=$true } } catch { Write-Host 'Verifica SHA256 saltata.' -ForegroundColor Yellow; $done=$true } } catch { Start-Sleep -Milliseconds 500 } } }; if(-not $done){ Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue; if ('%HAS_LOCAL%' -eq '1') { Write-Host 'Download online non riuscito: avvio diretto dalla copia offline su chiavetta...' -ForegroundColor Yellow } else { Write-Host 'Impossibile scaricare lo script: connessione assente o bloccata.' -ForegroundColor Yellow } }"

REM --- 4. Esecuzione script ---
if exist "%PS1%" (
    copy /y "%PS1%" "%~dp0setup-pc.ps1" >nul 2>&1
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDir "%~dp0" %USER_ARGS%
    goto :fine
)

if exist "%~dp0setup-pc.ps1" (
    echo Offline: uso la copia sulla chiavetta ^(funziona al 100%% senza Internet^).
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" -TargetDir "%~dp0" %USER_ARGS%
) else (
    echo.
    echo ============================================================
    echo   ATTENZIONE: Connessione a Internet assente e nessun file
    echo   'setup-pc.ps1' trovato sulla chiavetta USB!
    echo.
    echo   Soluzioni:
    echo   1. Connetti questo PC al Wi-Fi (in basso a destra) e riprova.
    echo   2. Oppure copia 'setup-pc.ps1' sulla chiavetta USB accanto
    echo      a 'PC Facile.bat' per farlo funzionare sempre al 100%% OFFLINE!
    echo ============================================================
)

:fine
echo.
echo ============================================================
echo   Operazione terminata. Premi un tasto per chiudere.
echo ============================================================
pause >nul
