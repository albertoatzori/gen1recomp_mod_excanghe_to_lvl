-- Standalone: luajit mods/Italiano/tests/italiano_test.lua
--
-- ROM-free.  La mod viene caricata dal vero loader headless contro il
-- dataset fixture, e quello che si verifica non e' il catalogo su disco ma
-- cosa finisce nei registry dopo il merge: e' quello che il gioco disegna.
--
-- Il grosso delle asserzioni riguarda l'invariante che rompe una
-- traduzione a runtime invece che a occhio: una riga che perde o sposta
-- una direttiva %s, o che lascia per strada un marcatore {PLAYER}, non e'
-- un refuso ma un errore in string.format o un buco nella frase.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local MOD = "mods/Italiano"

-- ------------------------------------------------------------ i cataloghi
--
-- Letti direttamente perche' le asserzioni sulle direttive vanno fatte
-- sulla coppia chiave/valore: dopo il merge la chiave non c'e' piu'.
-- `optional` vale per i cataloghi che possono legittimamente mancare:
-- main.lua fa ripiegare catalog() su {} quando mod:read non trova il file,
-- quindi un catalogo assente e' un catalogo vuoto, non un errore.  E' il
-- caso di font.lua, che non viene spedito perche' senza pagine di glifi da
-- aggiungere sarebbe una tabella vuota.
local function catalog(name, optional)
  local path = MOD .. "/lang/" .. name .. ".lua"
  local handle = io.open(path, "r")
  if not handle then
    T.check(optional, name .. ".lua esiste (o e' dichiarato opzionale)")
    return {}
  end
  local body = handle:read("*a")
  handle:close()
  local chunk, err = loadstring(body, path)
  T.check(chunk ~= nil, name .. ".lua compila: " .. tostring(err))
  if not chunk then return {} end
  local ok, tbl = pcall(chunk)
  T.check(ok and type(tbl) == "table", name .. ".lua restituisce una tabella")
  return (ok and type(tbl) == "table") and tbl or {}
end

local CATALOGS = { "dialogue", "strings", "species_names", "move_names",
                   "item_names", "trainer_names", "status_labels",
                   "charmap", "naming" }
local OPTIONAL = { font = true }

local loaded = {}
for _, name in ipairs(CATALOGS) do loaded[name] = catalog(name) end
for name in pairs(OPTIONAL) do loaded[name] = catalog(name, true) end

-- Un catalogo opzionale assente deve comportarsi da vuoto, non far saltare
-- il caricamento: e' la stessa garanzia su cui si regge main.lua.
for name in pairs(OPTIONAL) do
  T.eq(next(loaded[name]), nil, name .. " assente vale come catalogo vuoto")
end

-- ------------------------------------------- direttive e marcatori intatti
--
-- Solo per strings.lua: e' l'unico catalogo in cui la chiave E' la frase
-- inglese, quindi l'unico dove si puo' confrontare originale e traduzione.
-- Per dialogue.lua la chiave e' un'etichetta e il confronto va fatto contro
-- il worksheet, che sta fuori dalla mod.
local function directives(text)
  local found = {}
  for d in text:gmatch("%%[-+ #0-9.]*%a") do found[#found + 1] = d end
  return found
end

local function markers(text)
  local found = {}
  for m in text:gmatch("%b{}") do found[#found + 1] = m end
  table.sort(found)
  return found
end

local function listEq(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local badDirectives, badMarkers, translated = 0, 0, 0
for source, italian in pairs(loaded.strings) do
  if type(italian) == "string" and italian ~= "" then
    translated = translated + 1
    if not listEq(directives(source), directives(italian)) then
      badDirectives = badDirectives + 1
      print("  direttive diverse: " .. string.format("%q", source))
    end
    if not listEq(markers(source), markers(italian)) then
      badMarkers = badMarkers + 1
      print("  marcatori diversi: " .. string.format("%q", source))
    end
  end
end
T.check(translated > 0, "strings.lua ha almeno una voce tradotta")
T.eq(badDirectives, 0, "ogni traduzione conserva le direttive di formato")
T.eq(badMarkers, 0, "ogni traduzione conserva i marcatori {...}")

-- Un valore non-stringa passerebbe il caricamento e romperebbe il disegno.
local badTypes = 0
for _, name in ipairs({ "dialogue", "strings", "species_names", "move_names",
                        "item_names", "trainer_names", "status_labels" }) do
  for key, value in pairs(loaded[name]) do
    if type(key) ~= "string" or type(value) ~= "string" then
      badTypes = badTypes + 1
      print("  voce non testuale in " .. name .. ": " .. tostring(key))
    end
  end
end
T.eq(badTypes, 0, "ogni voce dei cataloghi e' stringa -> stringa")

-- ------------------------------------------ nessun glifo fuori dal vanilla
--
-- Questo e' l'invariante che tiene in piedi la scelta di NON registrare un
-- font: se ogni carattere introdotto dalla traduzione e' gia' disegnabile
-- dalle pagine vanilla, il TTF non serve, e senza TTF la griglia 8x8 resta
-- quella che le schermate si aspettano.  Una vocale accentata infilata qui
-- dentro romperebbe il patto in silenzio -- si vedrebbe come un buco a
-- schermo, o costringerebbe a rimettere il TTF e con lui le sovrapposizioni
-- nella lista della squadra.
--
-- Consentiti: ASCII stampabile, piu' i quattro extra che il font vanilla
-- disegna davvero (verificati contro tools/rom_manifest.json: e-acuta usata
-- in POKeMON, i puntini di sospensione, il triangolo e il simbolo della
-- valuta).  Un carattere gia' presente nella frase inglese passa comunque:
-- quello lo disegnava gia' il gioco, non lo stiamo introducendo noi.
local VANILLA_EXTRA = { ["\195\169"] = true, ["\226\128\166"] = true,
                        ["\226\150\182"] = true, ["\194\165"] = true }

-- I caratteri di controllo non sono glifi ma impaginazione -- \n va a capo,
-- \f apre una finestra, \v scorre -- e una traduzione piu' lunga
-- dell'originale ha tutto il diritto di aggiungerne uno che l'inglese non
-- aveva.  Il font non c'entra: non vengono disegnati.
local LAYOUT = { ["\n"] = true, ["\r"] = true, ["\f"] = true, ["\v"] = true }

-- itera i caratteri UTF-8 di una stringa
local function chars(text)
  local out, i = {}, 1
  while i <= #text do
    local b = text:byte(i)
    local width = (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
    out[#out + 1] = text:sub(i, i + width - 1)
    i = i + width
  end
  return out
end

local exotic = 0
for source, italian in pairs(loaded.strings) do
  if italian ~= "" then
    local inSource = {}
    for _, c in ipairs(chars(source)) do inSource[c] = true end
    for _, c in ipairs(chars(italian)) do
      local ascii = #c == 1 and c:byte() >= 0x20 and c:byte() <= 0x7E
      if not (ascii or LAYOUT[c] or VANILLA_EXTRA[c] or inSource[c]) then
        exotic = exotic + 1
        print("  glifo fuori dal font vanilla: " .. c .. " in " ..
              string.format("%q", italian))
      end
    end
  end
end
for _, name in ipairs({ "item_names", "move_names", "trainer_names",
                        "status_labels" }) do
  for _, value in pairs(loaded[name]) do
    for _, c in ipairs(chars(value)) do
      local ascii = #c == 1 and c:byte() >= 0x20 and c:byte() <= 0x7E
      if not (ascii or LAYOUT[c] or VANILLA_EXTRA[c]) then
        exotic = exotic + 1
        print("  glifo fuori dal font vanilla nei nomi: " .. c ..
              " in " .. value)
      end
    end
  end
end
T.eq(exotic, 0, "nessun carattere fuori da quello che il font vanilla disegna")

-- ------------------------------------------------- il carico vero e proprio
local r = T.sdk.loadMod(MOD)
T.eq(#r.errors, 0, "la mod carica senza errori: " .. table.concat(r.errors, "; "))
T.check(r.mod ~= nil, "il loader ha trovato la mod")

-- I registry su cui main.lua scrive devono esistere davvero nell'engine:
-- un nome sbagliato qui sarebbe una traduzione che non compare mai.
local registries = {}
for _, name in ipairs(T.catalog.registries()) do registries[name] = true end
for _, name in ipairs({ "text", "strings", "pokemon", "moves", "items",
                        "trainers", "statuses", "font" }) do
  T.check(registries[name], "il registry '" .. name .. "' esiste")
end

-- ------------------------------------------------ la traduzione e' arrivata
--
-- Misurato dopo il merge, sul dataset che il gioco leggerebbe.
local data = r.data

-- Il fixture ha tre specie inventate e non gli id vanilla, quindi i nomi
-- veri non ci sono da confrontare: si verifica data.strings, cioe' quello
-- che il merge ha davvero consegnato all'engine, che e' il catalogo da cui
-- src/core/Strings.lua pesca a ogni disegno.
local merged = data.strings
T.check(type(merged) == "table", "il merge ha prodotto data.strings")
T.eq(merged["CANCEL"], "ANNULLA", "una voce tradotta e' arrivata in italiano")
T.eq(merged["FIGHT"], "LOTTA", "i comandi di lotta sono arrivati in italiano")
T.eq(merged["%s used\n%s!"], "%s usa\n%s!",
     "la voce con due direttive e' arrivata intatta")

-- Una voce lasciata vuota non deve finire nel catalogo: se ci finisse,
-- cancellerebbe il testo invece di lasciarlo in inglese.  main.lua salta
-- le stringhe vuote proprio per questo.
local blanks = 0
for source, italian in pairs(loaded.strings) do
  if italian == "" and merged[source] ~= nil then
    blanks = blanks + 1
    print("  voce vuota finita nel catalogo: " .. string.format("%q", source))
  end
end
T.eq(blanks, 0, "nessuna voce vuota e' stata registrata")

-- I nomi non devono contenere accenti maiuscoli: nelle etichette tutte
-- maiuscole questa traduzione usa la forma con apostrofo.
local accented = 0
for _, name in ipairs({ "item_names", "move_names", "trainer_names" }) do
  for _, value in pairs(loaded[name]) do
    if value ~= "" and value:find("[\195][\128-\158]") then
      accented = accented + 1
      print("  accento maiuscolo in " .. name .. ": " .. value)
    end
  end
end
T.eq(accented, 0, "nessun accento maiuscolo nei nomi")

r.release()
T.finish("Italiano")
