# Automazioni Fantasy Grounds

Estensioni (automazioni) per **Fantasy Grounds Unity**, ruleset **D&D 5E**.

Questo è un progetto **separato** dallo script `pc-facile` (che configura i PC):
qui c'è codice che gira *dentro* Fantasy Grounds.

---

## Cos'è un'estensione

Un'estensione è un file **`.ext`** = uno **ZIP rinominato** che contiene, alla radice,
un manifest `extension.xml` più il codice (Lua) e la grafica.

```
mia-estensione.ext  (zip)
├── extension.xml     ← manifest (nome, versione, ruleset, quali script caricare)
├── scripts/          ← codice Lua (la logica / le automazioni)
├── xml/              ← finestre, bottoni, template UI (opzionale)
└── graphics/         ← icone, immagini (opzionale)
```

Il linguaggio è **Lua** e si usa l'**API di Fantasy Grounds**: oggetti globali come
`DB` (database della campagna), `CombatManager`, `ChatManager`, `Comm`,
`EffectManager`, `ActionAttack`/`ActionDamage`.

---

## Esempio incluso: `mia-prima-estensione/`

Uno **scheletro pronto** da cui partire. Quando lo carichi:

- scrive un messaggio in **console** (`/console`) → utile per il debug;
- scrive un messaggio nella **chat** appena si carica;
- aggiunge due **comandi di chat**:
  - `/ciao` (o `/ciao Samuele`) → risponde in chat;
  - `/combattenti` → conta i combattenti nel Combat Tracker (esempio di lettura dal database).

File sorgente:

```
mia-prima-estensione/
├── extension.xml        # manifest
├── scripts/main.lua     # la logica, tutta commentata in italiano
└── build.ps1            # crea il file .ext
```

---

## Come costruire il `.ext`

### Windows (PowerShell)
Dentro `mia-prima-estensione/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Ottieni `Mia-Prima-Estensione.ext`.

### Mac / Linux (a mano)
Dalla cartella `mia-prima-estensione/`:

```bash
zip -r Mia-Prima-Estensione.ext extension.xml scripts
```

> ⚠️ `extension.xml` deve stare **alla radice** dello zip, non dentro una sottocartella.

---

## Come installarla e provarla

1. Copia il file `.ext` nella cartella delle estensioni di FG:
   - **Windows:** `%APPDATA%\SmileyMouth\Fantasy Grounds\extensions`
   - (in FG puoi aprire questa cartella da **Settings → Folder**)
2. Avvia Fantasy Grounds → **Load Campaign** (o creane una nuova con ruleset **5E**).
3. Nella schermata della campagna, tab **Extensions**: metti la **spunta** su *Mia Prima Estensione*.
4. Entra come **GM**. Dovresti vedere il messaggio di caricamento in chat.
5. Prova a scrivere in chat: `/ciao` e `/combattenti`.
6. Errori? Apri la console con `/console`: gli errori Lua compaiono lì.

Dopo ogni modifica al codice: ricostruisci il `.ext`, sostituisci il file nella
cartella `extensions` e **ricarica la campagna**.

---

## Note

- Il campo `release="8|CoreRPG:4"` nel manifest indica la compatibilità. Se FG mostra
  un avviso di compatibilità, l'estensione si carica comunque; puoi aggiornare quel
  valore a una build più recente in seguito.
- L'API 5E è ampia: da questo scheletro si passa facilmente ad automazioni reali
  (effetti/buff automatici, attacco→danno→applicazione ai PF, bottoni sulla scheda).
  Chiedi pure il prossimo passo.
