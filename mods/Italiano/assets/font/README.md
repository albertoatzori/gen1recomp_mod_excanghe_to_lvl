# Fogli di glifi

Vuoto di proposito.

La mod non registra nessun font: il gioco disegna con le sue pagine di tile
come prima di installarla. Le vocali accentate, che quelle pagine non
hanno, sono scritte con l'apostrofo (`VELOCITA'`, `perche'`), quindi non
c'e' niente da aggiungere.

Il TTF Plain Pixel incluso nell'engine coprirebbe il latino accentato, ma
sostituisce il font a tile per tutti i caratteri ordinari e ne cambia la
metrica: le schermate costruite sulla griglia 8x8, prima fra tutte la lista
della squadra, si accavallano. Per questo resta fuori.

Se vuoi gli accenti veri, **aggiungi** una pagina invece di sostituire il
font: metti qui il PNG delle celle 8x8 e descrivilo in `lang/font.lua`, con
`base` da `0x100` in su -- spazio libero sopra le pagine vanilla `$60`/`$80`
-- cosi' l'alfabeto si somma senza toccare la metrica esistente.
