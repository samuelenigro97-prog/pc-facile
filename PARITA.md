# Parità Windows / Mac — PC Facile

Regola: **una modifica a una versione va replicata sull'altra.** Questa tabella
è la mappa. `setup-pc.ps1` (Windows) e `setup-mac.sh` (Mac) devono restare
allineati come flusso e funzioni.

| Passo / funzione            | Windows (`setup-pc.ps1`)                  | Mac (`setup-mac.sh`)                          | Note |
|-----------------------------|-------------------------------------------|-----------------------------------------------|------|
| Menu C/Veloce/Diag/Test     | `[Console]::ReadKey` + `-Veloce`          | menu + `--veloce`                             | pari |
| Lingua italiana             | `Install-Language it-IT -CopyToSettings`  | `defaults write AppleLanguages/AppleLocale`   | pari |
| Sincronizzazione orario     | `w32tm` + W32Time auto + tzautoupdate     | `systemsetup -setusingnetworktime on` + sntp  | pari |
| Nome cliente + host         | `Set-LocalUser` + `Rename-Computer`       | `scutil --set ComputerName/HostName`          | pari |
| Punto di ripristino         | `Checkpoint-Computer`                     | `tmutil localsnapshot` (Time Machine)         | pari |
| Account + credenziali       | Apre account.microsoft.com, genera cred   | Apre appleid.apple.com, genera cred           | pari |
| Office                      | installa (winget) + riscatto card PIN sul web | — (su Mac Office si scarica da web, opzionale)| solo Win |
| Pulizia / ottimizzazione    | AV prova + debloat OEM + config Windows   | config `defaults` (no debloat OEM: non esiste)| Mac = solo config |
| Antivirus                   | McAfee/Norton                             | — (raramente su Mac; skip)                    | solo Win |
| Unieuro Cyber Protection    | apre portale                              | apre portale (uguale)                         | pari |
| Browser                     | catalogo winget                           | cask brew                                     | pari |
| App (BASE/UFFICIO/GAMING)   | winget + tool GPU se dedicata (NVIDIA/Intel Arc/AMD) | brew cask (Mac: GPU integrata) | pari |
| Aggiornamenti               | `winget upgrade` + driver Windows Update  | `brew upgrade` + `softwareupdate`             | pari |
| Chiave di ripristino disco  | **BitLocker** (`manage-bde`/cmdlet)       | **FileVault** (`fdesetup`)                    | pari |
| Barra attesa download/install| `Show-BarraAttesa` (winget in Start-Process)| — (brew mostra gia' il progresso)             | solo Win |
| Avviso sonoro fine passo    | `[console]::Beep`                         | `printf '\a'`                                 | pari |
| Bip di richiamo se non rispondi| runspace: dopo 2 min bip corto ogni ~4s | —                                             | solo Win |
| Credenziali (esist./gen.)   | `Nome123!` + `Set-Clipboard`              | `Nome123!` + `pbcopy`                         | pari |
| Report finale .txt          | Desktop `Riepilogo-PC_*.txt`              | Desktop `Riepilogo-Mac_*.txt`                 | pari |
| Pulizia finale (auto-elimina)| rimuove `%TEMP%\setup-pc.ps1` + reg colori + checkpoint | `rm` dello script scaricato in `/tmp` | pari |
| Ripresa sessione interrotta | checkpoint JSON in `ProgramData\PCFacile` | —                                             | solo Win |
| Collegamenti Office Desktop | WScript.Shell dopo installazione Office   | —                                             | solo Win |
| Icona Desktop per ogni app  | copia lnk da Start / shell:AppsFolder     | —                                             | solo Win |
| Errori: rete di sicurezza   | `trap` a livello script + lista imprevisti | (`set -e` / trap shell)                       | solo Win (per ora) |
| Log strutturato             | JSON + CSV in `ProgramData\PCFacile\log`  | — (TODO)                                       | solo Win (per ora) |

## Infrastruttura (a livello di repo, vale per entrambi)
- **Test Pester** (`tests/`) sulle funzioni pure di `setup-pc.ps1`.
- **CI GitHub Actions**: sintassi + PSScriptAnalyzer + Pester + verifica SHA256.
- **SHA256** (`setup-pc.ps1.sha256`) verificato dal `.bat` allo scaricamento.

## Solo Windows (non esiste su Mac)
- **Debloat OEM**: macOS non ha crapware del produttore.
- **Rimozione antivirus di prova**: quasi mai preinstallato su Mac.
- **Attivazione Office/driver**: Office da web, driver inclusi in macOS.
- **GeForce se NVIDIA**: i Mac recenti non hanno GPU NVIDIA.

## Solo Mac (non esiste su Windows)
- **Rosetta 2** su Apple Silicon (arm64): serve a far girare le app solo-Intel.
