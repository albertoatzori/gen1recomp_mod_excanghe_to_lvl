# Italiano

Traduzione italiana per il motore LOVE2D di Poke Red (mod api 2).

Tutto quello che il gioco disegna passa da due cataloghi diversi, e questa
mod li riempie con criteri diversi:

| `lang/` | Cos'e' | Chiave | Stato |
|---|---|---|---|
| `strings.lua` | testo scritto dall'engine: menu, opzioni, messaggi di lotta, launcher, gioco in rete | la frase inglese sorgente | 697 / 839 |
| `item_names.lua` | nomi degli strumenti | id vanilla | 81 / 97 |
| `move_names.lua` | nomi delle mosse | id vanilla | 165 / 165 |
| `trainer_names.lua` | classi di Allenatore | id vanilla | 30 / 47 |
| `status_labels.lua` | sigle di stato nel riquadro PS | id dello stato | 5 / 5 |
| `species_names.lua` | nomi dei Pokemon | id vanilla | 0 / 155 |
| `dialogue.lua` | copione estratto dalla ROM | etichetta pokered | 0 / 2585 |

Una voce vuota non e' "traduci in stringa vuota": e' "non ancora
tradotta", e l'engine continua a disegnare l'inglese. La partita e'
quindi giocabile a qualsiasi punto del lavoro.

## Cosa e' gia' in italiano

L'intero strato d'interfaccia. Menu START e borsa, il PC e i BOX, il
POKéDEX, il negozio, le opzioni, la schermata del titolo, il gestore
delle mod, il launcher con l'importazione della ROM e dei salvataggi, il
gioco in rete (cavo, online, tornei), e i messaggi di sistema della
lotta: cosa usa un Pokemon, quanti punti esperienza guadagna, quando sale
di livello, quando viene catturato, quando e' esausto.

Insieme a questi, i nomi che l'interfaccia mostra di continuo: tutte e
165 le mosse, gli strumenti, le classi di Allenatore, le sigle degli
stati alterati (DOR, CON, AVV, SCO, PAR).

## Cosa e' rimasto in inglese, e perche'

**Il copione (`dialogue.lua`, 2585 voci).** Sono le battute degli NPC e
le scene della storia, e quel testo vive nella ROM del giocatore, non in
questo repository. Il catalogo qui contiene solo le etichette, mai il
testo: l'inglese di riferimento sta nel worksheet fuori dalla cartella
della mod, perche' `modkit pack` zippa tutto quello che sta dentro. Vedi
`TRANSLATING.md` per il flusso di lavoro.

**Le 142 voci narrative dentro `strings.lua`.** Nello stesso catalogo
dell'interfaccia ci sono anche i discorsi del PROF. OAK, alcune battute
di personaggi e il diploma. Sono contenuto narrativo dell'originale, non
etichette d'interfaccia, e restano vuote per la stessa ragione. Insieme a
loro restano vuote le stringhe di solo formato (`"%s :L%d"`), che non
contengono parole, e i nomi propri.

**I nomi dei Pokemon.** Non e' una mancanza: nei giochi italiani di prima
generazione le specie non sono tradotte, si chiamano come nell'originale.
Il catalogo resta con le chiavi al loro posto per chi voglia cambiarle in
una conversione totale.

## Accenti, e perche' il font non cambia

Questa mod **non registra nessun font**: il gioco continua a disegnare con
le sue pagine di tile, esattamente come prima di installarla.

La scelta e' deliberata. L'engine include un TTF (Plain Pixel) che copre il
latino accentato, e registrarlo sarebbe il modo rapido di avere e-grave e
o-grave. Ma quel TTF sostituisce il font a tile per tutti i caratteri
ordinari, e con esso cambiano larghezza e altezza di ogni riga: le
schermate costruite sulla griglia 8x8 -- la lista della squadra su tutte,
dove nome, barra PS e numeri stanno su misura -- finiscono per
accavallarsi.

Serviva a coprire le vocali accentate, e questa traduzione non ne usa
nessuna: le scrive con l'apostrofo, in maiuscolo (VELOCITA', PUO') e in
minuscolo (perche', e', piu'). E' l'uso italiano corrente quando l'accento
non e' disponibile, ed e' anche piu' stretto nei menu. Ogni carattere che
la mod introduce e' quindi gia' disegnabile dal font vanilla -- il test lo
verifica riga per riga, cosi' la garanzia non si perde a una modifica
distratta.

Chi volesse gli accenti veri deve **aggiungere una pagina di glifi**
(`lang/font.lua`, da `0x100` in su e' spazio libero sopra le pagine vanilla
`$60`/`$80`) invece di sostituire il font intero: cosi' si aggiunge un
alfabeto senza toccare la metrica di quello esistente. `main.lua` la
raccoglie da sola appena il catalogo esiste, e
`modkit translation Italiano --refresh` lo ricrea.

## Gioco in rete

Restare in italiano non impedisce di giocare con chi ha il gioco in
inglese. Il fingerprint che i due giochi si scambiano prima di collegarsi
copre la matematica della lotta -- potenza, tipo, precisione, PP, effetto
-- e non i nomi: `src/link/Fingerprint.lua` tiene `name` fuori da
`MOVE_FIELDS` proprio perche' un nome diverso non cambia il risultato di
un turno. Due giocatori vedono la stessa mossa scritta in due lingue e la
lotta resta sincronizzata.

Per questo il manifest non dichiara `affects_link`: il valore effettivo
resta `false`, che e' la risposta giusta, senza per questo affermare
qualcosa che il loader dovrebbe verificare a ogni scrittura.

## Aggiornare i cataloghi

I cataloghi sono nel formato che `tools/modkit.py` legge e riscrive,
quindi una rigenerazione conserva ogni riga gia' tradotta e sposta in un
blocco `ORPHANED` quelle la cui chiave e' sparita:

```
python3 tools/modkit.py translation Italiano --refresh
python3 tools/modkit.py validate italiano
python3 tools/modkit.py pack mods/Italiano
```

Il `--refresh` ha bisogno di `luajit` e legge il dataset importato: con
una ROM importata rigenera `dialogue.lua` e i nomi sul set reale invece
che sugli id del manifest.
