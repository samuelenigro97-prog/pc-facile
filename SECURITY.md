# Sicurezza

## Distribuzione e integrità

`PC Facile.bat` scarica sempre l'ultima versione di `setup-pc.ps1` da `main` e
ne verifica lo **SHA256** contro `setup-pc.ps1.sha256` pubblicato accanto allo
script: se non combacia (download corrotto o troncato) scarta il file e usa la
copia locale sulla chiavetta. L'hash rileva le corruzioni ma, essendo
pubblicato nello stesso repository, **non sostituisce una firma digitale**.

Quando è disponibile un certificato aziendale di code signing, firmare
`setup-pc.ps1` con Authenticode e distribuire il certificato pubblico sui PC del
negozio. La chiave privata non deve mai finire nel repository o nei workflow
senza un archivio segreti dedicato.

## Dati sensibili

Il riepilogo finale e il file `Credenziali - <cliente>.txt` sul Desktop
contengono **intenzionalmente** credenziali in chiaro e la chiave di ripristino
BitLocker: servono al flusso interno del negozio e restano con il PC del
cliente. Vanno consegnati e conservati secondo le procedure aziendali, mai
allegati a issue, commit o log pubblici.

## Segnalazioni

Per problemi di sicurezza, aprire una **segnalazione privata** su GitHub
(Security advisory) anziché una issue pubblica.
