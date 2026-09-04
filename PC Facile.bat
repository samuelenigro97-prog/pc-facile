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

REM Uso opzionale: "PC Facile.bat skipRestore" salta la creazione del punto di
REM ripristino (viene passato allo script come -skipRestore). La variabile
REM EXTRAPS1 sopravvive ai ri-launch (start + UAC) perche' le finestre figlie
REM ereditano l'ambiente; qui sotto NON viene re-inizializzata nei ri-launch.
set "EXTRAPS1="
if /i "%~1"=="skipRestore" set "EXTRAPS1=-skipRestore"

REM Virtual Terminal ON (colori ANSI truecolor: arancione Unieuro esatto)
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
REM Slot "DarkBlue" (indice 1) rimappato al navy SCURO #0A0E24.
REM DWORD = 0x00BBGGRR = 0x00240E0A.
reg add "HKCU\Console" /v ColorTable01 /t REG_DWORD /d 0x00240E0A /f >nul 2>&1
REM Font piu' GRANDE e leggibile (Consolas 20px, grassetto). Vale sulla console
REM classica (conhost, quella del doppio-click sul .bat); Windows Terminal lo
REM ignora. FontSize: altezza nel WORD alto -> 0x0014=20px. Ripristinato a fine.
reg add "HKCU\Console" /v FaceName /t REG_SZ /d "Consolas" /f >nul 2>&1
reg add "HKCU\Console" /v FontFamily /t REG_DWORD /d 54 /f >nul 2>&1
reg add "HKCU\Console" /v FontWeight /t REG_DWORD /d 700 /f >nul 2>&1
reg add "HKCU\Console" /v FontSize /t REG_DWORD /d 0x00140000 /f >nul 2>&1
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

REM --- Scarico l'ultima versione su file temporaneo (con fallback offline) ---
set "HAS_LOCAL="
if exist "%~dp0setup-pc.ps1" set "HAS_LOCAL=1"

echo Scarico l'ultima versione da GitHub...
del "%TEMP%\setup-pc*.ps1" /f /q >nul 2>&1
set "PS1=%TEMP%\setup-pc-%RANDOM%%RANDOM%.ps1"

REM     DUE FONTI con TLS 1.2 forzato: prima GitHub raw, poi jsDelivr CDN
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13; $bases=@('https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main','https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'); $done=$false; foreach($base in $bases){ if($done){break}; for($i=1;$i -le 2 -and -not $done;$i++){ try { $t=(Get-Date -UFormat %%s); irm ($base+'/setup-pc.ps1?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -OutFile '%PS1%' -ErrorAction Stop; try { $atteso=(((irm ($base+'/setup-pc.ps1.sha256?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -ErrorAction Stop).Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); if ($atteso -and $reale -ne $atteso) { Write-Host 'Impronta SHA256 non combacia: scarto.' -ForegroundColor Yellow; Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue } else { Write-Host ('Scaricato e verificato da: '+$base) -ForegroundColor Green; $done=$true } } catch { Write-Host 'Verifica SHA256 saltata.' -ForegroundColor Yellow; $done=$true } } catch { Start-Sleep -Milliseconds 500 } } }; if(-not $done){ Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue; if ('%HAS_LOCAL%' -eq '1') { Write-Host 'Download online non riuscito: avvio diretto dalla copia offline su chiavetta...' -ForegroundColor Yellow } else { Write-Host 'Impossibile scaricare lo script: connessione assente o bloccata.' -ForegroundColor Yellow } }"

REM --- Se il download e' riuscito uso quello (SEMPRE aggiornato) ---
REM     e ne SALVO una copia sulla chiavetta come riserva OFFLINE (best effort)
if exist "%PS1%" (
    copy /y "%PS1%" "%~dp0setup-pc.ps1" >nul 2>&1
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %EXTRAPS1%
    goto :fine
)

REM --- Offline: fallback sulla copia accanto al .bat (chiavetta) ---
if exist "%~dp0setup-pc.ps1" (
    echo Offline: uso la copia sulla chiavetta ^(funziona al 100%% senza Internet^).
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" %EXTRAPS1%
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
