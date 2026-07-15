# Traduzione Italiano — D&D 5E

Estensione che traduce in **italiano le etichette dell'interfaccia** del ruleset
**5E** di Fantasy Grounds Unity.

> Traduce **solo l'interfaccia** (etichette, bottoni, titoli). **Non** traduce i
> contenuti dei manuali (mostri, incantesimi, avventure): quelli sono dati
> protetti da copyright e vivono nei moduli `.mod`, non qui.

---

## Come funziona (il concetto)

Fantasy Grounds tiene ogni testo dell'interfaccia in una **stringa con un nome**:

```xml
<string name="char_label_hp">Hit Points</string>
```

Questa estensione fornisce le **stesse stringhe** con il testo in italiano:

```xml
<string name="char_label_hp">Punti Ferita</string>
```

Le estensioni si caricano **dopo** il ruleset, quindi le stringhe con lo stesso
`name` **sovrascrivono** quelle originali. Risultato: l'interfaccia in italiano.

**La regola d'oro:** il `name` deve essere **identico** a quello del ruleset. Se
sbagli il nome, quella riga non traduce nulla (nessun errore, ma nessun effetto).
Per questo i nomi si **estraggono** dal ruleset — non si inventano.

---

## Contenuto

```
traduzione-italiano-5e/
├── extension.xml            # manifest (include il file di stringhe)
├── strings/strings_it.xml   # le stringhe tradotte (con esempi da verificare)
└── build.ps1                # crea il file .ext
```

⚠️ Le stringhe in `strings_it.xml` sono **esempi illustrativi**. Prima di fidarti,
verifica i loro `name` con il procedimento qui sotto e aggiungi le altre.

---

## Estrarre i nomi delle stringhe (il passo che conta)

I nomi reali stanno dentro i file del ruleset. Procedimento:

1. **Trova i file del ruleset.** Nella cartella di installazione di Fantasy Grounds:
   ```
   <installazione FG>\rulesets\
   ```
   Il ruleset 5E e la base **CoreRPG** sono file `.pak` (che sono **ZIP**).
   Molte etichette generiche (bottoni, finestre comuni) vengono da `CoreRPG.pak`;
   quelle specifiche di 5E dal pak del 5E.

2. **Apri il `.pak` come ZIP** (copialo e rinominalo `.zip`, oppure aprilo con 7-Zip).
   Cerca i file delle stringhe, di solito nella cartella `strings/`
   (es. `strings/strings.xml`, `strings/strings_client.xml`, ecc.).

3. **Dentro trovi le righe** `<string name="...">Testo inglese</string>`.
   Copia le righe che vuoi tradurre in `strings/strings_it.xml`, **mantenendo il
   `name` invariato** e cambiando **solo** il testo in italiano.

4. **Ricostruisci il `.ext`** (vedi sotto), sostituiscilo, ricarica la campagna.

> Suggerimento: traduci a blocchi (prima la scheda personaggio, poi il combat
> tracker, ecc.) e verifica ogni volta in gioco. È più gestibile che fare tutto
> insieme.

---

## Prima di partire: esiste già?

Tradurre a mano l'intera interfaccia sono **centinaia** di stringhe. Vale la pena
controllare se esiste già una traduzione italiana della community (Fantasy Grounds
**Forge**, forum ufficiali). Se c'è, puoi partire da quella e integrare solo i pezzi
mancanti invece di rifare tutto.

---

## Costruire il `.ext`

### Windows (PowerShell)
Dentro `traduzione-italiano-5e/`:
```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

### Mac / Linux
```bash
zip -r Traduzione-Italiano-5E.ext extension.xml strings
```
> `extension.xml` deve stare **alla radice** dello zip.

---

## Installare e provare

1. Copia il `.ext` in `%APPDATA%\SmileyMouth\Fantasy Grounds\extensions`.
2. In FG: **Load Campaign** (ruleset **5E**) → tab **Extensions** → spunta
   *Traduzione Italiano - 5E*.
3. Apri una scheda personaggio: le etichette con `name` corretto appaiono in italiano.
4. Non cambia niente? Il `name` non combacia con quello del ruleset: ricontrolla
   il passo "Estrarre i nomi delle stringhe".

---

## Encoding (accenti à è é ì ò ù)

`strings_it.xml` è salvato in **UTF-8** (dichiarato in cima al file). Le versioni
moderne di FGU lo gestiscono. Se in gioco gli accenti appaiono come simboli strani,
risalva il file in **ANSI/Latin-1** e cambia la dichiarazione in
`encoding="iso-8859-1"` (è la codifica storica di FG).
