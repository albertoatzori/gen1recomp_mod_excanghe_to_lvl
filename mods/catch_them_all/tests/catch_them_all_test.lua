-- Standalone: luajit mods/catch_them_all/tests/catch_them_all_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, and the placement is then measured through the hook the
-- engine actually raises, with a scripted RNG -- so what is asserted is what
-- a step in the grass does.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")
local Runtime = require("src.mods.Runtime")

local MOD = "mods/catch_them_all"

-- Writes are dropped so no case leaves the loader's option-schema snapshot in
-- the checkout, and the "mods" listing is narrowed to this mod so the other
-- committed mods stay out of the merge.  `files` overrides the mod's own data
-- files, which is how a case states its world in one place.
local function checkoutFs(modOptions, files)
  local inner = FsIo.new(".")
  local body = modOptions and SaveSerializer.encode({ modOptions = modOptions })
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
    for name, source in pairs(files or {}) do
      if path:match(name:gsub("%.", "%%.") .. "$") then return "return " .. source end
    end
    return inner.read(path)
  end
  fs.getDirectoryItems = function(path)
    if path == "mods" then return { "catch_them_all" } end
    return inner.getDirectoryItems(path)
  end
  fs.write = function() return true end
  return fs
end

-- FIXMON_B is in no encounter table, so it stands in for anything this
-- version never offers.  The fixture evolves A into B, which would make B
-- reachable; the closure case puts that back on purpose.
local function dataset()
  local data = T.fixtures.fresh()
  data.pokemon.FIXMON_A.evolutions = {}
  data.encounters.FIX_ROUTE.water = {
    rate = 20, slots = { { level = 10, species = "FIXMON_A" } },
  }
  return data
end

local HOMES = '{ gen1 = { FIXMON_B = { { map = "FIX_ROUTE", terrain = "grass", min = 7, max = 9 } } } }'
local NO_HOMES = "{ gen1 = {} }"
local SCRIPTED = '{ gen1 = { "FIXMON_A" } }'

local function load(opts, files)
  return T.sdk.loadMods({ MOD },
    { data = dataset(), fs = checkoutFs(opts, files) })
end

-- One step in the grass.  `draws` feeds ctx.rng in order; `vanilla` is what
-- the engine's own roll returned, nil for an empty step.
local function step(vanilla, draws, terrain)
  local i = 0
  local encDef = { grass = { rate = 128, slots = { { level = 3, species = "FIXMON_A" } } } }
  local ctx = {
    mapId = "FIX_ROUTE", terrain = terrain or "grass",
    rng = function() i = i + 1 return draws[i] or 0 end,
  }
  return Runtime.call("encounter.roll", function() return vanilla end, encDef, ctx)
end

local VANILLA = { species = "FIXMON_A", level = 3 }

-- ------- nothing vanilla offers is ever taken away

local run = load(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES })
T.eq(#run.errors, 0, "the mod loads clean")

local enc = step(VANILLA, { 0.0 })
T.eq(enc, VANILLA, "a step the engine filled is returned untouched")
T.eq(enc.species, "FIXMON_A", "with the species the engine picked")

-- ------- and an empty step can become a guest

enc = step(nil, { 0.0, 0.0 })
T.check(enc ~= nil, "an empty step can produce a guest")
T.eq(enc.species, "FIXMON_B", "which is the species with a home here")
T.check(enc.level >= 7 and enc.level <= 9,
  "at a level from its home's range, got " .. tostring(enc and enc.level))

-- ------- but only sometimes: the die is a share of the map's own rate

enc = step(nil, { 0.99 })
T.eq(enc, nil, "an unlucky empty step stays empty")

-- rate 128/256 = 0.5, UNCOMMON = 0.25 -> the guest chance is 0.125
enc = step(nil, { 0.124, 0.0 })
T.check(enc ~= nil, "a draw just under the chance produces one")
enc = step(nil, { 0.126 })
T.eq(enc, nil, "a draw just over it does not")
run.release()

-- ------- HOW OFTEN moves that line, and nothing else

run = load({ catch_them_all = { chance = 0.5 } },
  { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES })
T.check(step(nil, { 0.24, 0.0 }) ~= nil, "COMMON: a draw at 0.24 produces one")
T.eq(step(nil, { 0.26 }), nil, "and 0.26 does not -- the line moved to 0.25")
run.release()

run = load({ catch_them_all = { chance = 0.1 } },
  { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES })
T.eq(step(nil, { 0.06 }), nil, "RARE: 0.06 no longer produces one")
T.check(step(nil, { 0.04, 0.0 }) ~= nil, "but 0.04 still does")
run.release()

-- ------- a map with no home for anyone is untouched

run = load(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = NO_HOMES })
T.eq(step(nil, { 0.0, 0.0 }), nil, "with no homes declared no step is filled")
T.eq(step(VANILLA, { 0.0 }), VANILLA, "and vanilla still comes through")
run.release()

-- ------- the terrain has to match

run = load(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES })
T.eq(step(nil, { 0.0, 0.0 }, "water"), nil,
  "a grass home does not fill an empty step on the water")
run.release()

-- ------- gifts and trades are placed too, and the toggle takes them back

local GIFT_HOME =
  '{ gen1 = { FIXMON_A = { { map = "FIX_ROUTE", terrain = "grass", min = 4, max = 4 } } } }'

-- FIXMON_A IS in the fixture's grass, so it is not missing and stays out
run = load(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = GIFT_HOME })
T.eq(step(nil, { 0.0, 0.0 }), nil,
  "a species already in this version's grass is never added again")
run.release()

-- ------- the evolution closure still holds

run = load(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES })
local placedB = step(nil, { 0.0, 0.0 })
T.check(placedB ~= nil, "FIXMON_B is placed when nothing reaches it")
run.release()

local data = dataset()
data.pokemon.FIXMON_A.evolutions = {
  { method = "LEVEL", level = 16, species = "FIXMON_B" },
}
run = T.sdk.loadMods({ MOD }, { data = data,
  fs = checkoutFs(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES }) })
T.eq(step(nil, { 0.0, 0.0 }), nil,
  "but not when a wild species evolves into it")
run.release()

-- ------- legendaries stay out unless asked for

local LEG_HOME =
  '{ gen1 = { MEWTWO = { { map = "FIX_ROUTE", terrain = "grass", min = 30, max = 30 } } } }'
local function withMewtwo()
  local d = dataset()
  d.pokemon.MEWTWO = { name = "MEWTWO", types = { "PSYCHIC" },
    baseStats = d.pokemon.FIXMON_B.baseStats,
    growthRate = d.pokemon.FIXMON_B.growthRate, evolutions = {} }
  return d
end

run = T.sdk.loadMods({ MOD }, { data = withMewtwo(),
  fs = checkoutFs(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = LEG_HOME }) })
T.eq(step(nil, { 0.0, 0.0 }), nil, "MEWTWO is not in the grass by default")
run.release()

run = T.sdk.loadMods({ MOD }, { data = withMewtwo(),
  fs = checkoutFs({ catch_them_all = { legendaries = true } },
                  { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = LEG_HOME }) })
local leg = step(nil, { 0.0, 0.0 })
T.check(leg ~= nil and leg.species == "MEWTWO",
  "and is when the option asks for it")
run.release()

-- ------- the encounter tables themselves are never rewritten

data = dataset()
local before = {}
for _, slot in ipairs(data.encounters.FIX_ROUTE.grass.slots) do
  before[#before + 1] = slot.species
end
run = T.sdk.loadMods({ MOD }, { data = data,
  fs = checkoutFs(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES }) })
local after = {}
for _, slot in ipairs(data.encounters.FIX_ROUTE.grass.slots) do
  after[#after + 1] = slot.species
end
T.eq(table.concat(after, ","), table.concat(before, ","),
  "no slot is added, removed or renamed -- the mod only answers steps")
run.release()

-- ------- a save event with nowhere to write is survivable

run = load(nil, { ["obtainable.lua"] = SCRIPTED, ["homes.lua"] = HOMES })
local ok, err = pcall(function()
  Runtime.emit("save.loaded", { game = { save = nil } })
  Runtime.emit("save.created", {})
end)
T.check(ok, "a save event with no writable playthrough is survivable: "
  .. tostring(err))
run.release()

-- ------- the files the mod actually ships

local homes = dofile("mods/catch_them_all/homes.lua")
T.check(type(homes) == "table" and type(homes.gen1) == "table",
  "homes.lua returns a table with a gen1 map")

local count = 0
for id, spots in pairs(homes.gen1) do
  count = count + 1
  T.check(id:match("^[A-Z][A-Z_0-9]*$") ~= nil, "a species id: " .. id)
  T.check(#spots > 0, id .. " has at least one home")
  for _, spot in ipairs(spots) do
    T.check(type(spot.map) == "string" and spot.map:match("^[A-Z][A-Z_0-9]*$"),
      id .. " names a map id: " .. tostring(spot.map))
    T.check(spot.terrain == "grass" or spot.terrain == "water",
      id .. " names a terrain the engine rolls: " .. tostring(spot.terrain))
    T.check(type(spot.min) == "number" and type(spot.max) == "number"
      and spot.min >= 2 and spot.max >= spot.min and spot.max <= 100,
      id .. " has a sane level range")
  end
end
T.check(count >= 14, "the nowhere-wild species are homed (" .. count .. ")")

-- the map ids must be ones this engine knows
local manifest = io.open("tools/rom_manifest_yellow.json")
if manifest then
  local body = manifest:read("*a")
  manifest:close()
  for id, spots in pairs(homes.gen1) do
    for _, spot in ipairs(spots) do
      T.check(body:find('"' .. spot.map .. '"', 1, true) ~= nil,
        spot.map .. " (" .. id .. ") is a map the version manifest lists")
    end
  end
end

local declared = dofile("mods/catch_them_all/obtainable.lua")
T.check(#declared.gen1 > 30,
  "obtainable.lua still carries the declared list (" .. #declared.gen1 .. ")")

T.finish("catch_them_all")
