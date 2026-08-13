-- Standalone: luajit mods/catch_them_all/tests/catch_them_all_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, and what is asserted is the MERGED encounter tables the
-- engine would then roll against -- so what is under test is the data
-- src/world/Encounter.lua will actually read.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")

local MOD = "mods/catch_them_all"

-- Writes are dropped so no case leaves the loader's option-schema snapshot in
-- the checkout, and the "mods" listing is narrowed to this mod so the other
-- committed mods stay out of the merge.  `obtainable` overrides the mod's own
-- data file, which is how a filled list is exercised without shipping one.
local function checkoutFs(modOptions, obtainable)
  local inner = FsIo.new(".")
  local body = modOptions and SaveSerializer.encode({ modOptions = modOptions })
  local declared = obtainable and ("return " .. obtainable)
  local fs = {}
  for key, value in pairs(inner) do fs[key] = value end
  fs.getInfo = function(path)
    if path == "options.lua" then
      if body then return { type = "file" } end
      return nil
    end
    return inner.getInfo(path)
  end
  fs.read = function(path)
    if path == "options.lua" then return body end
    if declared and path:match("obtainable%.lua$") then return declared end
    return inner.read(path)
  end
  fs.getDirectoryItems = function(path)
    if path == "mods" then return { "catch_them_all" } end
    return inner.getDirectoryItems(path)
  end
  fs.write = function() return true end
  return fs
end

local SCRIPTED = '{ gen1 = { "FIXMON_A" } }'

-- The fixture route has two grass slots (FIXMON_A, FIXMON_C) out of three
-- species, so FIXMON_B is what nothing offers -- a version exclusive in
-- miniature.  A duplicate slot and a water table are added so there is one
-- slot the mod is allowed to spend and somewhere for habitat routing to go.
local function dataset()
  local data = T.fixtures.fresh()
  -- the fixture evolves FIXMON_A into FIXMON_B, which would make B reachable
  -- and leave nothing missing; the case that tests the closure puts it back
  data.pokemon.FIXMON_A.evolutions = {}
  data.encounters.FIX_ROUTE.grass.slots[3] = { level = 5, species = "FIXMON_A" }
  data.encounters.FIX_ROUTE.water = {
    rate = 10, slots = { { level = 10, species = "FIXMON_A" },
                         { level = 11, species = "FIXMON_A" } },
  }
  return data
end

local function slotsOf(data, map, terrain)
  local out = {}
  for _, slot in ipairs(data.encounters[map][terrain].slots) do
    out[#out + 1] = slot.species
  end
  return table.concat(out, ",")
end

local function has(data, map, terrain, species)
  for _, slot in ipairs(data.encounters[map][terrain].slots) do
    if slot.species == species then return slot end
  end
  return nil
end

-- ------- fail closed: an empty obtainable.lua adds nothing at all

local data = dataset()
local before = slotsOf(data, "FIX_ROUTE", "grass")
local run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, "{}") })
T.eq(#run.errors, 0, "an empty list is not a load error")
T.eq(slotsOf(data, "FIX_ROUTE", "grass"), before,
  "with nothing declared the mod adds nothing -- it cannot tell a version "
  .. "exclusive from a starter")
run.release()

-- ------- with the scripted species declared, the gap is filled

data = dataset()
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
T.eq(#run.errors, 0, "a filled list loads clean")
T.check(has(data, "FIX_ROUTE", "grass", "FIXMON_B") ~= nil,
  "FIXMON_B, which nothing offered, is now catchable")
run.release()

-- ------- it never takes the last copy of a species

data = dataset()
data.encounters.FIX_ROUTE.water = nil
data.encounters.FIX_ROUTE.grass.slots = {
  { level = 30, species = "FIXMON_A" },
  { level = 31, species = "FIXMON_C" },
  { level = 32, species = "FIXMON_A" },
}
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
local slots = data.encounters.FIX_ROUTE.grass.slots
T.eq(#slots, 3, "the table keeps its shape -- a slot's position is its odds")
T.check(has(data, "FIX_ROUTE", "grass", "FIXMON_A") ~= nil,
  "FIXMON_A keeps a slot: its duplicate was spent, never its last copy")
T.check(has(data, "FIX_ROUTE", "grass", "FIXMON_C") ~= nil,
  "FIXMON_C is untouched -- it only ever had the one")
T.eq(slots[3].species, "FIXMON_B", "the rarest slot is the one given up")
T.eq(slots[3].level, 32,
  "and the newcomer inherits its level, so it fits the area")
run.release()

-- ------- when every slot is a last copy, nothing is touched at all

data = dataset()
data.encounters.FIX_ROUTE.water = nil
data.encounters.FIX_ROUTE.grass.slots = {
  { level = 5, species = "FIXMON_A" }, { level = 6, species = "FIXMON_C" },
}
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
T.eq(slotsOf(data, "FIX_ROUTE", "grass"), "FIXMON_A,FIXMON_C",
  "with no duplicate anywhere the table is left exactly as it was")
run.release()

-- ------- evolutions are followed, so an evolved form is not "missing"

data = dataset()
data.pokemon.FIXMON_A.evolutions = {
  { method = "LEVEL", level = 16, species = "FIXMON_B" },
}
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
T.eq(has(data, "FIX_ROUTE", "grass", "FIXMON_B"), nil,
  "a species reachable by evolving a wild one is left alone")
run.release()

-- ------- and a declared species is never treated as missing

data = dataset()
run = T.sdk.loadMods({ MOD },
  { data = data, fs = checkoutFs(nil, '{ gen1 = { "FIXMON_A", "FIXMON_B" } }') })
T.eq(has(data, "FIX_ROUTE", "grass", "FIXMON_B"), nil,
  "a species a script hands you is not put in the grass")
run.release()

-- ------- legendaries are held back unless asked for

local function withMewtwo()
  local d = dataset()
  d.pokemon.MEWTWO = { name = "MEWTWO", types = { "PSYCHIC" },
    baseStats = d.pokemon.FIXMON_B.baseStats,
    growthRate = d.pokemon.FIXMON_B.growthRate, evolutions = {} }
  return d
end

data = withMewtwo()
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
T.eq(has(data, "FIX_ROUTE", "grass", "MEWTWO"), nil,
  "MEWTWO is not dropped into the grass by default")
T.check(has(data, "FIX_ROUTE", "grass", "FIXMON_B") ~= nil,
  "while the ordinary missing species still is")
run.release()

data = withMewtwo()
run = T.sdk.loadMods({ MOD },
  { data = data, fs = checkoutFs({ catch_them_all = { legendaries = true } },
                                 SCRIPTED) })
T.check(has(data, "FIX_ROUTE", "grass", "MEWTWO") ~= nil
        or has(data, "FIX_ROUTE", "water", "MEWTWO") ~= nil,
  "and is, when the option asks for it")
run.release()

-- ------- Water types are routed to water where there is any

data = dataset()
data.pokemon.FIXMON_B.types = { "WATER" }
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
T.check(has(data, "FIX_ROUTE", "water", "FIXMON_B") ~= nil,
  "a Water type takes a slot in the water table")
T.eq(has(data, "FIX_ROUTE", "grass", "FIXMON_B"), nil, "and not in the grass")
run.release()

-- ------- the placement is derived, so two runs agree

local function placement()
  local d = dataset()
  local r = T.sdk.loadMods({ MOD }, { data = d, fs = checkoutFs(nil, SCRIPTED) })
  local where = slotsOf(d, "FIX_ROUTE", "grass") .. "|"
    .. slotsOf(d, "FIX_ROUTE", "water")
  r.release()
  return where
end
T.eq(placement(), placement(), "the same dataset always produces the same world")

-- ------- AREAS EACH bounds how many slots one species takes

data = dataset()
run = T.sdk.loadMods({ MOD },
  { data = data, fs = checkoutFs({ catch_them_all = { homes = 1 } }, SCRIPTED) })
local count = 0
for _, terrain in ipairs({ "grass", "water" }) do
  for _, slot in ipairs(data.encounters.FIX_ROUTE[terrain].slots) do
    if slot.species == "FIXMON_B" then count = count + 1 end
  end
end
T.eq(count, 1, "at 1 AREA it takes exactly one slot")
run.release()

-- ------- the report survives a save event with nowhere to write
--
-- Storage is scoped to a playthrough, so the report is written on a save
-- event rather than at load.  A headless run has no persistence backend and
-- no save, and the mod must simply not write rather than fail the boot.

local Runtime = require("src.mods.Runtime")
data = dataset()
run = T.sdk.loadMods({ MOD }, { data = data, fs = checkoutFs(nil, SCRIPTED) })
local ok, err = pcall(function()
  Runtime.emit("save.loaded", { game = { save = nil } })
  Runtime.emit("save.created", {})
end)
T.check(ok, "a save event with no writable playthrough is survivable: "
  .. tostring(err))
run.release()

-- ------- the list the mod actually ships
--
-- The Gen 1 half was read out of data/scripts/ rather than recalled, and it
-- is the one part of this mod that cannot be derived at load.  Emptying it
-- would silently turn the mod off, so its shape is pinned here.

local shipped = dofile("mods/catch_them_all/obtainable.lua")
T.check(type(shipped) == "table" and type(shipped.gen1) == "table",
  "obtainable.lua returns a table with a gen1 list")
T.check(#shipped.gen1 > 30,
  "the Gen 1 list is filled (" .. #shipped.gen1 .. " species)")

local seen = {}
for _, id in ipairs(shipped.gen1) do
  T.check(type(id) == "string" and id:match("^[A-Z][A-Z_0-9]*$") ~= nil,
    "every entry is a species id: " .. tostring(id))
  T.eq(seen[id], nil, "and appears once: " .. tostring(id))
  seen[id] = true
end

-- the three routes that motivated the file, each represented
T.check(seen.SQUIRTLE, "a starter is declared (give_pokemon)")
T.check(seen.SNORLAX, "a static battle is declared")
T.check(seen.FARFETCHD, "an in-game trade is declared")
T.check(seen.OMANYTE, "a fossil revival is declared")
T.check(seen.VULPIX,
  "and VULPIX, the Game Corner prize a from-memory list would have missed")

T.finish("catch_them_all")
