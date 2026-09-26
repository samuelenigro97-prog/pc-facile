@echo off
title PC Facile
REM ============================================================
REM  PC Facile.bat - launcher ottimizzato 1-Click per setup-pc.ps1
REM  - Elevazione amministratore immediata (UN SOLO prompt UAC)
REM  - Sblocco automatico file (elimina gli avvisi SmartScreen/Apri file)
REM  - Parte SEMPRE con ExecutionPolicy Bypass (niente errori di blocco)
REM  - Scarica l'ultima versione da GitHub con fallback offline su USB
REM ============================================================

REM --- 0. Completa un auto-aggiornamento del launcher rimasto in sospeso ---
REM La nuova versione (gia' verificata SHA256 dal manifest) viene salvata come
REM "PC Facile.bat.nuovo" perche' cmd.exe legge il .bat mentre lo esegue: non si
REM puo' sovrascrivere mentre gira. Qui (e alla fine) la metto al suo posto.
REM Tutto dentro UN blocco tra parentesi: cmd lo legge per intero prima di
REM eseguirlo, quindi dopo il MOVE non rilegge il vecchio file e passa al nuovo.
if exist "%~f0.nuovo" (
    move /y "%~f0.nuovo" "%~f0" >nul 2>&1 && "%~f0" %*
)

REM --- 1. Elevazione immediata ad amministratore (UN SOLO prompt UAC) ---
REM "elevated"/"run" come primo argomento e' un marcatore interno del launcher:
REM lo tolgo con SHIFT. Attenzione: SHIFT non modifica %*, quindi gli argomenti
REM utente vengono ricostruiti piu' sotto partendo da %1 (vedi :elevato).
if /i "%~1"=="elevated" (
    shift
    goto :elevato
)
if /i "%~1"=="run" (
    shift
    goto :elevato
)

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%~f0\" elevated %*\"' -Verb RunAs } catch { exit 1 }"
    if %errorlevel% neq 0 (
        echo.
        echo   [!] Richiesta privilegi amministratore annullata o non concessa.
        echo   Per avviare: fai click destro su "PC Facile.bat" e scegli "Esegui come amministratore".
        echo.
        pause
    )
    exit
)

:elevato
set "USER_ARGS="
:raccogli_argomenti
if "%~1"=="" goto :argomenti_pronti
set "USER_ARGS=%USER_ARGS% %1"
shift
goto :raccogli_argomenti
:argomenti_pronti

REM --- 2. Impostazioni console a tema Unieuro (Navy #00122B & Arancio #EE7203) ---
set "SEE_MASK_NOZONECHECKS=1"
REM Backup delle impostazioni console ORIGINALI (una sola volta): setup-pc.ps1
REM le ripristina nella pulizia finale. Un backup gia' presente NON viene
REM sovrascritto (es. ripresa dopo riavvio: le chiavi sarebbero gia' modificate).
if not exist "%ProgramData%\PCFacile" mkdir "%ProgramData%\PCFacile" >nul 2>&1
if not exist "%ProgramData%\PCFacile\console-backup.reg" reg export "HKCU\Console" "%ProgramData%\PCFacile\console-backup.reg" /y >nul 2>&1
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Console" /v FaceName /t REG_SZ /d "Consolas" /f >nul 2>&1
reg add "HKCU\Console" /v FontWeight /t REG_DWORD /d 700 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable00 /t REG_DWORD /d 0x002B1200 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable01 /t REG_DWORD /d 0x002B1200 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable02 /t REG_DWORD /d 0x005EC522 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable03 /t REG_DWORD /d 0x00FDC593 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable04 /t REG_DWORD /d 0x004444EF /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable06 /t REG_DWORD /d 0x000372EE /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable07 /t REG_DWORD /d 0x00FCFAF8 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable08 /t REG_DWORD /d 0x00B8A394 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable09 /t REG_DWORD /d 0x00FDC593 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable10 /t REG_DWORD /d 0x005EC522 /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable11 /t REG_DWORD /d 0x00AAD7FE /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable12 /t REG_DWORD /d 0x004444EF /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable14 /t REG_DWORD /d 0x000372EE /f >nul 2>&1
reg add "HKCU\Console" /v ColorTable15 /t REG_DWORD /d 0x00FFFFFF /f >nul 2>&1
reg add "HKCU\Console" /v ScreenColors /t REG_DWORD /d 7 /f >nul 2>&1

REM Sblocca automaticamente tutti i file della chiavetta ed elimina gli avvisi SmartScreen / Apri file
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:SEE_MASK_NOZONECHECKS=1; Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

REM --- Auto-connessione Wi-Fi Negozio da chiavetta USB (se non ancora connesso a Internet) ---
REM Controllo Internet via HTTP con piu' fallback: il solo ping ICMP a 8.8.8.8 e'
REM spesso bloccato dalle reti dei negozi anche quando Internet funziona.
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { if ((Invoke-WebRequest 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 5).Content -like 'Microsoft Connect Test*') { exit 0 } } catch {}; foreach ($u in @('https://raw.githubusercontent.com/','https://www.google.com/generate_204')) { try { Invoke-WebRequest $u -Method Head -UseBasicParsing -TimeoutSec 5 | Out-Null; exit 0 } catch { if ($_.Exception.Response) { exit 0 } } }; if (@(Test-Connection -ComputerName 1.1.1.1,8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue) -contains $true) { exit 0 }; exit 1" >nul 2>&1
if %errorlevel% neq 0 (
    echo Connessione a Internet assente: verifico configurazione Wi-Fi su chiavetta...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $dirs=@('%~dp0wifi','%~dp0'); foreach($d in $dirs){ if(Test-Path $d){ Get-ChildItem -Path $d -Filter '*.xml' | ForEach-Object { $c=Get-Content $_.FullName -Raw; if($c -match '<name>(.*?)</name>'){ & netsh wlan add profile filename=$_.FullName user=all >nul 2>&1; & netsh wlan connect name=$Matches[1] >nul 2>&1 } }; if(Test-Path (Join-Path $d 'wifi.txt')){ $lines=Get-Content (Join-Path $d 'wifi.txt'); $s=''; $p=''; foreach($l in $lines){ if($l -match '^(SSID|WIFI|RETE)\s*[:=]\s*(.+)$'){$s=$Matches[2].Trim()} elseif($l -match '^(PASS|PASSWORD|KEY|CHIAVE)\s*[:=]\s*(.+)$'){$p=$Matches[2].Trim()} }; if($s -and $p){ $se=[Security.SecurityElement]::Escape($s); $pe=[Security.SecurityElement]::Escape($p); $xml = '<?xml version=\"1.0\"?><WLANProfile xmlns=\"http://www.microsoft.com/networking/WLAN/profile/v1\"><name>'+$se+'</name><SSIDConfig><SSID><name>'+$se+'</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption><sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>'+$pe+'</keyMaterial></sharedKey></security></MSM></WLANProfile>'; $t=$env:TEMP+'\w.xml'; [IO.File]::WriteAllText($t,$xml); & netsh wlan add profile filename=$t user=all >nul 2>&1; & netsh wlan connect name=$s >nul 2>&1; Remove-Item $t -Force } } } }; Start-Sleep -Seconds 3" >nul 2>&1
)

REM --- 3. Scarica l'ultima versione da GitHub (con fallback offline) ---
REM Il file scaricato viene tenuto SOLO se il suo SHA256 combacia con
REM setup-pc.ps1.sha256. Se l'impronta non si scarica o non combacia il download
REM viene scartato e si usa la copia sulla chiavetta (nessuna esecuzione "al buio").
set "HAS_LOCAL="
if exist "%~dp0setup-pc.ps1" set "HAS_LOCAL=1"

echo Scarico l'ultima versione da GitHub...
del "%TEMP%\setup-pc*.ps1" /f /q >nul 2>&1
set "PS1=%TEMP%\setup-pc-%RANDOM%%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; $bases=@('https://raw.githubusercontent.com/samuelenigro97-prog/pc-facile/main','https://cdn.jsdelivr.net/gh/samuelenigro97-prog/pc-facile@main'); $done=$false; foreach($base in $bases){ if($done){break}; for($i=1;$i -le 2 -and -not $done;$i++){ try { $t=(Get-Date).Ticks; irm ($base+'/setup-pc.ps1?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -OutFile '%PS1%' -ErrorAction Stop; $atteso=((([string](irm ($base+'/setup-pc.ps1.sha256?t='+$t) -Headers @{ 'Cache-Control'='no-cache' } -ErrorAction Stop)).Trim()) -split '\s+')[0].ToLower(); $reale=(Get-FileHash '%PS1%' -Algorithm SHA256).Hash.ToLower(); if ($atteso -match '^[0-9a-f]{64}$' -and $reale -eq $atteso) { Write-Host ('Scaricato e verificato da: '+$base) -ForegroundColor Green; $done=$true } else { Write-Host 'Impronta SHA256 assente o non combacia: scarto il download.' -ForegroundColor Yellow; Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue } } catch { Write-Host 'Download o verifica SHA256 non riusciti: scarto il download.' -ForegroundColor Yellow; Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 500 } } }; if(-not $done){ Remove-Item '%PS1%' -Force -ErrorAction SilentlyContinue; if ('%HAS_LOCAL%' -eq '1') { Write-Host 'Download online non riuscito: avvio diretto dalla copia offline su chiavetta...' -ForegroundColor Yellow } else { Write-Host 'Impossibile scaricare lo script: connessione assente o bloccata.' -ForegroundColor Yellow } }"

REM --- 4. Esecuzione script ---
set "TARGET_DIR=%~dp0"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

REM %PS1% esiste solo se il download e' stato VERIFICATO (SHA256): solo allora
REM aggiorno la chiavetta con TUTTI i file elencati in manifest.txt (ognuno
REM verificato SHA256 prima di sostituire la copia; i file Wi-Fi non si toccano).
REM Se qualcosa non va, restano i file attuali e si prosegue comunque.
if exist "%PS1%" (
    echo Aggiorno i file della chiavetta ^(manifest.txt^)...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -AggiornaUSB -TargetDir "%TARGET_DIR%" -LauncherPath "%~f0"
    if defined USER_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDir "%TARGET_DIR%" %USER_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDir "%TARGET_DIR%"
    )
    goto :fine
)

if exist "%~dp0setup-pc.ps1" (
    echo Offline: uso la copia sulla chiavetta ^(funziona al 100%% senza Internet^).
    if defined USER_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" -TargetDir "%TARGET_DIR%" %USER_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-pc.ps1" -TargetDir "%TARGET_DIR%"
    )
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

REM Auto-aggiornamento del launcher: sostituisco questo file con la nuova
REM versione verificata ed esco nello STESSO blocco (cmd non rilegge il file).
if exist "%~f0.nuovo" (
    move /y "%~f0.nuovo" "%~f0" >nul 2>&1
    exit /b
)
exit /b
