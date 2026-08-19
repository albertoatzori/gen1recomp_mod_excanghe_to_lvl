# Tradurre in italiano

Tutto quello che il giocatore legge e' una stringa di due tipi, e i due
tipi stanno in posti diversi per un motivo preciso.

| file in `lang/` | Cos'e' | Chiave |
|---|---|---|
| `dialogue.lua` | ogni riga del copione estratto | l'etichetta originale, es. `_PalletTownText1` |
| `strings.lua` | testo scritto dall'engine: menu, lotta, launcher, rete | la frase inglese sorgente |
| `species_names.lua` `move_names.lua` `item_names.lua` `trainer_names.lua` | nomi | l'id vanilla |
| `status_labels.lua` | DOR, CON, AVV... come appaiono nel riquadro PS | l'id dello stato |
| `charmap.lua` (e `font.lua`, da rigenerare) | il foglio di glifi e cosa disegna cosa | vedi sotto |
| `naming.lua` | la griglia per inserire i nomi | - |

Riempi un valore e ha effetto al boot successivo. Lascialo `""` e quella
stringa resta in inglese: il gioco e' giocabile in ogni momento del
lavoro, quindi si puo' pubblicare presto e completare dopo.

## Dov'e' l'inglese

I cataloghi contengono le chiavi e il *tuo* testo, mai l'inglese
originale. Per `dialogue.lua` e per i nomi, l'inglese di riferimento si
genera in una cartella sorella della mod:

```
python3 tools/modkit.py translation Italiano --refresh
```

crea `mods/Italiano-worksheet/`, un file separato da tabulazioni per ogni
catalogo:

```
_AbandonLearningText	Abandon learning\n{RAM:wStringBuffer}?
```

Quella cartella sta **fuori** dalla mod di proposito. Il copione estratto
e i nomi vanilla sono contenuto della ROM, e `modkit pack` zippa tutto
quello che sta sotto la cartella della mod: un worksheet tenuto dentro
finirebbe nella release qualunque cosa dica un `.gitignore`. Tienilo
accanto alla mod, mai dentro.

`lang/strings.lua` e' l'eccezione: quelle frasi sono sorgente Lua di
questo repository, non testo della ROM, quindi li' la chiave *e'*
l'inglese e si traduce direttamente leggendo il file.

## Da dove conviene cominciare

`dialogue.lua` e' la parte grossa e va riempita nell'ordine in cui si
gioca, cosi' ogni sessione di lavoro si prova subito:

1. `PalletTown*`, `RedsHouse*`, `OaksLab*` - l'inizio
2. `ViridianCity*`, `Route1*`, `ViridianMart*`
3. `PewterCity*`, `MtMoon*`, le palestre nell'ordine delle medaglie

Le etichette sono ordinate alfabeticamente nel catalogo, quindi le righe
di una stessa mappa stanno vicine.

## Regole che modkit fa rispettare

Una traduzione che perde o sposta un marcatore viene rifiutata, perche' a
runtime sarebbe un errore, non un refuso:

- **direttive di formato** `%s`, `%d`, `%3d`, `%.1f`: stesso numero e
  stesso ordine dell'inglese. L'engine passa queste stringhe a
  `string.format`.
- **marcatori** `{PLAYER}`, `{RIVAL}`, `{RAM:...}`, `{STRBUF}`,
  `{NUM:...}`: vanno riportati identici.
- **caratteri di controllo**: `\n` va a capo dentro la stessa finestra,
  `\f` apre una finestra nuova, `\v` fa scorrere. Cambiarli cambia il
  ritmo delle finestre di dialogo.

## Larghezza delle righe

La finestra di testo e' larga 18 colonne. L'engine manda a capo da solo
quando una riga sfora, quindi una frase italiana piu' lunga
dell'originale non viene mai troncata, ma va a capo dove capita: se la
riga conta, spezzala tu con `\n`.

L'italiano e' mediamente piu' lungo dell'inglese del 15-20%, e nei menu
lo spazio e' quello che e'. Per le etichette corte conviene abbreviare
come fa il gioco (`MED. MASSO`, `PRELEVA STRUM.`) invece di lasciare che
vadano a capo.

## Accenti e maiuscole

**Scrivi gli accenti con l'apostrofo**: `perche'`, `e'`, `piu'`,
`VELOCITA'`, `PUO'`. Le pagine di font vanilla non hanno le vocali
accentate, e finche' nessuna traduzione ne usa, il gioco puo' continuare a
disegnare con le sue tile e la mod non deve toccare il font.

Non registrare il TTF dell'engine per aggirare la cosa. Copre il latino
accentato, ma sostituisce il font a tile per tutti i caratteri ordinari, e
con esso cambia la metrica di ogni riga: le schermate costruite sulla
griglia 8x8 -- la lista della squadra in particolare -- si accavallano.

Il test rifiuta qualsiasi carattere che il font vanilla non sappia
disegnare, quindi un accento vero viene intercettato prima di arrivare a
schermo. Se ti servono davvero, **aggiungi** una pagina di glifi invece di
sostituire il font: un'immagine di celle 8x8 piu' una charmap che dice
quale sequenza di byte disegna quale cella, descritte in `lang/font.lua` e
`lang/charmap.lua`. Le pagine vanilla stanno a `$60` e `$80`; da `0x100`
in su e' spazio libero, cosi' un alfabeto si aggiunge senza toccare la
metrica di quello esistente.

## Il ciclo di lavoro

```
POKEPORT_DEV=1 love .                             # lascialo aperto
                                                  # F5 ricarica a caldo
python3 tools/modkit.py validate italiano         # prima di condividere
python3 tools/modkit.py pack mods/Italiano        # per pubblicare
```
