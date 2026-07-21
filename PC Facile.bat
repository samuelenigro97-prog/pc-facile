@echo off
title PC Facile
REM ============================================================
REM  PC Facile.bat - launcher doppio-click per setup-pc.ps1
REM  - Imposta i colori (registro) e RIAPRE in una finestra nuova
REM  - Si auto-eleva ad amministratore (UAC)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Scarica SEMPRE l'ultima versione da GitHub; la copia accanto al .bat
REM    e' solo il fallback offline (cosi' si aggiorna da solo, niente USB stale)
REM  Il MENU (Configura/Diagnostica/Test) e' nello script, prima schermata.
REM ============================================================

REM --- PRIMA PASSATA: imposto i colori nel registro, poi RIAPRO in una finestra
REM     NUOVA. conhost legge il registro SOLO all'apertura della finestra: se
REM     l'account e' gia' admin (es. "oem") non c'e' rilancio UAC, quindi la
REM     finestra corrente e' nata prima del reg e resterebbe col blu chiaro.
REM     La sentinella "run" evita di ripetere all'infinito. ---
if /i "%~1"=="run" goto :run

REM Virtual Terminal ON (colori ANSI truecolor: arancione Unieuro esatto)
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
REM Slot "DarkBlue" (indice 1) rimappato al navy SCURO #0A0E24.
REM DWORD = 0x00BBGGRR = 0x00240E0A.
reg add "HKCU\Console" /v ColorTable01 /t REG_DWORD /d 0x00240E0A /f >nul 2>&1
start "PC Facile" "%~f0" run
exit /b

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
if exist "%PS1%" del "%PS1%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $t=(Get-Date -UFormat %%s); $base='https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main'; irm ($base+'/setup-pc.ps1?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -OutFile '%PS1%'; try { $atteso=(((irm ($base+'/setup-pc.ps1.sha256?t='+$t) -Headers @{ 'Cache-Control'='no-cache' }).Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); if ($atteso -and $reale -ne $atteso) { Write-Host 'ATTENZIONE: impronta SHA256 non corrisponde: scarto il download.' -ForegroundColor Red; Remove-Item '%PS1%' -Force } else { Write-Host 'Integrita'' verificata (SHA256).' -ForegroundColor Green } } catch { Write-Host 'Verifica SHA256 saltata (impronta non disponibile).' -ForegroundColor Yellow } } catch { Write-Host ('Download fallito: '+$_) -ForegroundColor Yellow }"

REM --- Se il download e' riuscito uso quello (SEMPRE aggiornato) ---
if exist "%PS1%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
    goto :fine
)

REM --- Offline: fallback sulla copia accanto al .bat (chiavetta) ---
if exist "%~dp0setup-pc.ps1" (
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
