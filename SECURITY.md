# Sicurezza

## Distribuzione

Usare preferibilmente gli artefatti delle Release GitHub e verificare sempre `setup-pc.ps1.sha256`. L'hash rileva corruzioni ma, essendo pubblicato nello stesso repository, non sostituisce una firma digitale.

Quando è disponibile un certificato aziendale di code signing, firmare `setup-pc.ps1` con Authenticode prima della release e distribuire il certificato pubblico sui PC del negozio. La chiave privata non deve essere inserita nel repository o nei workflow senza un archivio segreti dedicato.

## Dati sensibili

Il riepilogo operativo contiene intenzionalmente credenziali e chiavi di ripristino per il flusso interno del negozio. Va consegnato e conservato secondo le procedure aziendali, mai allegato a issue o commit.

Per segnalazioni di sicurezza, aprire una segnalazione privata GitHub anziché un'issue pubblica.
