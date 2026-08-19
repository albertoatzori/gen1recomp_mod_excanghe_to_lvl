-- Italiano: traduzione italiana del gioco.
--
-- Ogni tabella sotto lang/ e' una mappa chiave -> testo italiano.  Una voce
-- lasciata a "" non e' "traduci in stringa vuota" ma "non ancora tradotta",
-- e continua a essere disegnata in inglese: la partita resta quindi sempre
-- giocabile, anche a traduzione incompleta.
--
-- Le due categorie di stringhe hanno chiavi diverse per un motivo preciso:
--   * lang/strings.lua  -> testo scritto dall'engine.  La chiave E' la
--     frase inglese, perche' quei letterali sono sorgente Lua di questo
--     repository e si possono leggere direttamente.
--   * lang/dialogue.lua -> copione estratto dalla ROM del giocatore.  La
--     chiave e' l'etichetta pokered (_PalletTownText1, ...) e l'inglese
--     NON sta qui: e' contenuto della ROM e non va ridistribuito.  Sta nel
--     worksheet accanto alla mod (vedi TRANSLATING.md).
--
-- Prima di modificare qualcosa leggi TRANSLATING.md: la parte che si
-- sbaglia piu' spesso e' il font, non il testo.
return function(mod)
  -- mod:read e' la via supportata per leggere dentro la propria cartella;
  -- i cataloghi sono tabelle Lua semplici, quindi si leggono ed eseguono
  -- invece di passare da require().
  local function catalog(name)
    local rel = "lang/" .. name .. ".lua"
    local body = mod:read(rel)
    if not body then return {} end
    local chunk, err = loadstring(body, rel)
    if not chunk then
      mod.log:warn("%s ha un errore di sintassi: %s", rel, tostring(err))
      return {}
    end
    local ok, table_ = pcall(chunk)
    if not ok or type(table_) ~= "table" then
      mod.log:warn("%s non ha restituito una tabella: %s", rel, tostring(table_))
      return {}
    end
    return table_
  end

  -- Una voce vuota vuol dire "non tradotta", mai "traduci in vuoto".
  local function each(name, apply)
    local n = 0
    for key, value in pairs(catalog(name)) do
      if type(value) == "string" and value ~= "" then
        apply(key, value)
        n = n + 1
      end
    end
    return n
  end

  -- ---- glifi ---------------------------------------------------------
  -- Nessun font viene registrato, ed e' una scelta, non una dimenticanza.
  --
  -- Registrare il TTF Plain Pixel sostituisce il font a tile per tutti i
  -- caratteri ordinari, e con esso cambiano larghezza e altezza di ogni
  -- riga: le schermate costruite sulla griglia 8x8 -- la lista della
  -- squadra su tutte, dove nome, barra PS e numeri stanno su misura -- si
  -- accavallano.  Serviva a coprire le vocali accentate, che le pagine
  -- vanilla ($60/$80) non hanno.
  --
  -- Ma questa traduzione non ne usa nessuna: le maiuscole accentate sono
  -- scritte con l'apostrofo (VELOCITA', PUO') e le minuscole pure
  -- (perche', e', piu'), che e' l'uso italiano corrente quando l'accento
  -- non c'e' ed e' anche piu' stretto nei menu.  Ogni carattere che questa
  -- mod introduce e' quindi gia' disegnabile dal font vanilla, e il test
  -- lo verifica riga per riga.  Senza vocali accentate da coprire, il TTF
  -- non porta niente e costa il layout: resta fuori.
  --
  -- Chi volesse davvero gli accenti veri deve aggiungere una pagina di
  -- glifi (lang/font.lua, da 0x100 in su e' spazio libero sopra le pagine
  -- vanilla) invece di sostituire il font intero.  Il ciclo qui sotto la
  -- raccoglie da sola appena il catalogo esiste; `modkit translation
  -- Italiano --refresh` lo ricrea.
  for id, page in pairs(catalog("font")) do
    mod.content.font:register(id, page)
  end
  -- charmap: quale sequenza di byte disegna quale codice
  for seq, code in pairs(catalog("charmap")) do
    mod.content.font:register("charmap:" .. seq, { seq = seq, code = code })
  end

  -- ---- testo ---------------------------------------------------------
  local counts = {}
  counts.dialogue = each("dialogue", function(id, value)
    mod.content.text:override(id, value)
  end)
  counts.strings = each("strings", function(source, value)
    mod.content.strings:override(source, value)
  end)
  counts.species = each("species_names", function(id, value)
    mod.content.pokemon:patch(id, { name = value })
  end)
  counts.moves = each("move_names", function(id, value)
    mod.content.moves:patch(id, { name = value })
  end)
  counts.items = each("item_names", function(id, value)
    mod.content.items:patch(id, { name = value })
  end)
  counts.trainers = each("trainer_names", function(id, value)
    mod.content.trainers:patch(id, { name = value })
  end)
  counts.statuses = each("status_labels", function(id, value)
    mod.content.statuses:patch(id, { label = value })
  end)

  -- ---- localita' ------------------------------------------------------
  -- I nomi che compaiono sulla Mappa, nel menu VOLO e nella schermata ZONA
  -- del POKeDEX non stanno in un registry di record ma dentro field, sotto
  -- townMap.locations, uno per id di mappa.
  --
  -- `field` ha semantica "deep" (src/mods/Schemas.lua R.field), e
  -- Merge.deepMerge fonde i dizionari chiave per chiave: passare il solo
  -- `name` lascia quindi al loro posto le coordinate x/y estratte dalla
  -- ROM, che questa mod non ha nessun motivo di toccare.
  local places = catalog("location_names")
  if next(places) then
    local locations = {}
    for mapId, italian in pairs(places) do
      if type(italian) == "string" and italian ~= "" then
        locations[mapId] = { name = italian }
        counts.places = (counts.places or 0) + 1
      end
    end
    mod.content.field:patch("townMap", { locations = locations })
  end

  -- ---- inserimento nomi ----------------------------------------------
  -- La griglia di lettere della schermata "dai un nome".  lang/naming.lua
  -- resta vuoto: l'alfabeto inglese contiene gia' tutte le lettere che
  -- servono a scrivere un nome italiano, e le accentate si scrivono senza
  -- accento come nel gioco originale.
  local grid = catalog("naming")
  if grid.upper then
    -- NamingScreen chiama Runtime.call("ui.naming.grid", sameGrid, base, ctx),
    -- quindi il callback riceve (next, base, ctx): next(base, ctx) e' la
    -- griglia vanilla, che resta il ripiego se il catalogo non ha la pagina
    -- richiesta.
    mod.hooks:wrap("ui.naming.grid", function(next, base, ctx)
      local vanilla = next(base, ctx)
      local want = (ctx and ctx.lower) and grid.lower or grid.upper
      return want or vanilla
    end)
  end

  mod.events:on("game.ready", function()
    local total = 0
    for _, n in pairs(counts) do total = total + n end
    mod.log:info("Italiano: %d stringhe tradotte", total)
  end)
end
