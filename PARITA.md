# Parità Windows / Mac — PC Facile

Regola: **una modifica a una versione va replicata sull'altra.** Questa tabella
è la mappa. `setup-pc.ps1` (Windows) e `setup-mac.sh` (Mac) devono restare
allineati come flusso e funzioni.

| Passo / funzione            | Windows (`setup-pc.ps1`)                  | Mac (`setup-mac.sh`)                          | Note |
|-----------------------------|-------------------------------------------|-----------------------------------------------|------|
| Menu C/Veloce/Diag/Test     | `[Console]::ReadKey` + `-Veloce`          | menu + `--veloce`                             | pari |
| Lingua italiana             | registro/`Set-WinSystemLocale`            | `defaults write AppleLanguages/AppleLocale`   | pari |
| Nome cliente + host         | `Set-LocalUser` + `Rename-Computer`       | `scutil --set ComputerName/HostName`          | pari |
| Punto di ripristino         | `Checkpoint-Computer`                     | `tmutil localsnapshot` (Time Machine)         | pari |
| Account + credenziali       | Apre account.microsoft.com, genera cred   | Apre appleid.apple.com, genera cred           | pari |
| Office                      | attiva 365/perpetuo (`ospp.vbs`)          | — (su Mac Office si scarica da web, opzionale)| solo Win |
| Pulizia / ottimizzazione    | AV prova + debloat OEM + config Windows   | config `defaults` (no debloat OEM: non esiste)| Mac = solo config |
| Antivirus                   | McAfee/Norton                             | — (raramente su Mac; skip)                    | solo Win |
| Unieuro Cyber Protection    | apre portale                              | apre portale (uguale)                         | pari |
| Browser                     | catalogo winget                           | cask brew                                     | pari |
| App (BASE/UFFICIO/GAMING)   | winget + GeForce se NVIDIA                | brew cask (Mac: no GeForce, GPU integrata)    | pari |
| Aggiornamenti               | `winget upgrade` + driver Windows Update  | `brew upgrade` + `softwareupdate`             | pari |
| Chiave di ripristino disco  | **BitLocker** (`manage-bde`/cmdlet)       | **FileVault** (`fdesetup`)                    | pari |
| Avviso sonoro fine passo    | `[console]::Beep`                         | `printf '\a'`                                 | pari |
| Credenziali (esist./gen.)   | `Nome123!` + `Set-Clipboard`              | `Nome123!` + `pbcopy`                         | pari |
| Report finale .txt          | Desktop `Riepilogo-PC_*.txt`              | Desktop `Riepilogo-Mac_*.txt`                 | pari |

## Cosa NON si porta su Mac (di proposito)
- **Debloat OEM**: macOS non ha crapware del produttore.
- **Rimozione antivirus di prova**: quasi mai preinstallato su Mac.
- **Attivazione Office/driver**: gestione diversa (Office da web, driver inclusi in macOS).
