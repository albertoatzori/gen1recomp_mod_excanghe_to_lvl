-- Quale sequenza di byte disegna quale codice di glifo.
--
-- Vuoto di proposito: senza pagine di glifi aggiuntive (vedi font.lua)
-- non c'e' niente da mappare.  Le lettere accentate passano dal TTF, che
-- l'engine indirizza direttamente dai byte UTF-8 del catalogo.
--
-- Da riempire solo insieme a lang/font.lua:
--   ["a-grave"] = 0x100,
return {}
