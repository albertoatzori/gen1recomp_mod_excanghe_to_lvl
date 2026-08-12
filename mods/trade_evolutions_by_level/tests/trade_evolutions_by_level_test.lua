-- Standalone:
--   luajit mods/trade_evolutions_by_level/tests/trade_evolutions_by_level_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, so the merge, the schema validation and the option read
-- are the production ones.  The fixture ships no trade evolution of its
-- own, so each case plants the rows it wants to see rewritten.
--
-- The rewritten rows are then fed to the engine's own evolution dispatch --
-- Red's Evolution.pendingFor, Gold's Evolution.checkMon -- because "the
-- data says LEVEL 36" and "the mon actually evolves at 36" are two
-- different claims, and only the second one is the mod's stated effect.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")
local Evolution = require("src.pokemon.Evolution")
local Experience = require("src.battle.Experience")

local MOD = "mods/trade_evolutions_by_level"

local function dataset(rows)
  local data = T.fixtures.fresh()
  for id, evolutions in pairs(rows) do
    data.pokemon[id].evolutions = evolutions
  end
  return data
end

-- Every case runs on a filesystem whose writes are dropped: the loader
-- publishes an option-schema snapshot beside options.lua once a mod defines
-- options, and a test suite must not leave that in the checkout.  The
-- "mods" listing is narrowed to this mod so the other committed mods stay
-- out of the merge (the default loadMod path does the same through its
-- aliasing filesystem).  `modOptions`, when given, is served as options.lua
-- so a case can run against a non-default setting.
local function checkoutFs(modOptions)
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
    return inner.read(path)
  end
  fs.getDirectoryItems = function(path)
    if path == "mods" then return { "trade_evolutions_by_level" } end
    return inner.getDirectoryItems(path)
  end
  fs.write = function() return true end
  return fs
end

-- ------- defaults: level 36, trading still works

local data = dataset({
  -- trade-only, the KADABRA / MACHOKE / GRAVELER / HAUNTER shape
  FIXMON_B = { { method = "TRADE", level = 1, species = "FIXMON_C" } },
  -- a mixed line (POLIWHIRL's shape): it already evolves without a cable
  FIXMON_A = {
    { method = "LEVEL", level = 16, species = "FIXMON_B" },
    { method = "TRADE", level = 1, species = "FIXMON_C" },
  },
})

local run = T.sdk.loadMod(MOD, { data = data, fs = checkoutFs() })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

local evos = data.pokemon.FIXMON_B.evolutions
T.eq(#evos, 2, "the trade-only line keeps both routes by default")
T.eq(evos[1].method, "LEVEL", "the trade row became a level row")
T.eq(evos[1].level, 36, "and it fires at level 36")
T.eq(evos[1].species, "FIXMON_C", "into the same species as the trade")
T.eq(evos[2].method, "TRADE", "the original trade row is kept")

-- everything the patch did not name survived
T.check(#data.pokemon.FIXMON_B.learnset > 0, "FIXMON_B keeps its learnset")
T.eq(data.pokemon.FIXMON_B.types[1], "FIRE", "FIXMON_B keeps its types")
T.eq(data.pokemon.FIXMON_B.baseStats.speed, 65, "and its base stats")

local mixed = data.pokemon.FIXMON_A.evolutions
T.eq(#mixed, 2, "a species with another route is left alone")
T.eq(mixed[1].method, "LEVEL", "its own level row is untouched")
T.eq(mixed[1].level, 16, "at its own level")
T.eq(mixed[2].method, "TRADE", "and its trade row still needs a cable")

-- ------- the engine's own dispatch, on the merged dataset
--
-- pendingFor is the single point both the after-battle sweep
-- (Evolution.checkParty) and the Rare Candy path go through, and it reads
-- the merged evolution_methods registry -- so a match here is the mod
-- working, not the rows merely looking right.

local game = { data = data, save = { pokedex = { seen = {}, owned = {} } } }
local function pending(level, kind)
  local species, evo =
    Evolution.pendingFor(game, { species = "FIXMON_B", level = level },
                         { kind = kind })
  return species, evo and evo.method
end

T.eq(pending(35, "levelup"), nil, "nothing happens at level 35")
T.eq(pending(36, "levelup"), "FIXMON_C", "it evolves on the level-up to 36")
T.eq(select(2, pending(36, "levelup")), "LEVEL", "as a level evolution")
T.eq(pending(50, "levelup"), "FIXMON_C", "and still later, if it got there first")
T.eq(pending(5, "trade"), "FIXMON_C", "a trade at any level evolves it too")
T.eq(select(2, pending(5, "trade")), "TRADE", "through the kept trade row")
T.eq(pending(36, "item"), nil, "no stone gained an effect")

-- and the evolution really lands: apply is what checkParty runs after the
-- movie, so this is the last step of the flow the mod feeds
local mon = { species = "FIXMON_B", level = 36, hp = 20,
              stats = { hp = 20 }, dvs = {}, statExp = {} }
Evolution.apply(game, mon, (pending(36, "levelup")), "LEVEL")
T.eq(mon.species, "FIXMON_C", "the mon became the evolved species")
T.check(mon.stats.hp > 0, "with stats recalculated for it")
T.check(game.save.pokedex.owned.FIXMON_C, "and the dex records it as owned")

-- ------- crossing the level mid-battle
--
-- Gen 1 sweeps for evolutions ONCE, after the battle ends, on whatever level
-- the mon finished with -- it does not re-check at each level crossed.  So a
-- mon that jumps 35 -> 39 inside one fight (what an exp multiplier makes
-- routine) prints a "grew to level" box for 36, 37, 38 and 39 and only then
-- evolves, as a 39.  That reads like "it ignored 36", which is why it is
-- pinned here: the threshold is honoured, the offer is just not per level.

local Growth = require("src.pokemon.Growth")
local jumper = { species = "FIXMON_B", level = 35, hp = 50,
                 stats = { hp = 50 }, dvs = {}, statExp = {} }
jumper.exp = Growth.expForLevel(data.pokemon.FIXMON_B.growthRate, 35,
                                data.growth_rates)

-- one trainer battle, its six mons knocked out in turn: the payouts land
-- during the fight, the evolution sweep only runs once it is over
local strong = { baseExp = 250, baseStats = data.pokemon.FIXMON_B.baseStats }
local crossed = {}
for _ = 1, 6 do
  for _, level in ipairs(Experience.apply(data, jumper, strong, 100, true, 1, false)) do
    crossed[#crossed + 1] = level
  end
end
T.check(#crossed > 1, "the battle crossed several levels (" ..
  table.concat(crossed, ", ") .. ")")
T.eq(crossed[1], 36, "the threshold went by mid-battle, with no offer of its own")
T.check(jumper.level > 36, "and ended well past the threshold")
T.eq((Evolution.pendingFor(game, jumper, { kind = "levelup" })), "FIXMON_C",
  "the after-battle sweep still evolves it")

run.release()

-- ------- options: a different level, and trading switched off

local tuned = dataset({
  FIXMON_B = { { method = "TRADE", level = 1, species = "FIXMON_C" } },
})

local run2 = T.sdk.loadMod(MOD, {
  data = tuned,
  fs = checkoutFs({
    trade_evolutions_by_level = { level = 20, keep_trade = false },
  }),
})
T.eq(#run2.errors, 0, "loads clean with options (" .. tostring(run2.errors[1]) .. ")")

local tunedEvos = tuned.pokemon.FIXMON_B.evolutions
T.eq(#tunedEvos, 1, "keep_trade off drops the cable route")
T.eq(tunedEvos[1].method, "LEVEL", "leaving one level row")
T.eq(tunedEvos[1].level, 20, "at the configured level")

local tunedGame = { data = tuned, save = { pokedex = { seen = {}, owned = {} } } }
local function tunedPending(level, kind)
  return (Evolution.pendingFor(tunedGame, { species = "FIXMON_B", level = level },
                               { kind = kind }))
end
T.eq(tunedPending(19, "levelup"), nil, "still nothing one level short")
T.eq(tunedPending(20, "levelup"), "FIXMON_C", "it evolves at the chosen level")
T.eq(tunedPending(50, "trade"), nil, "and a trade no longer evolves it")

run2.release()

-- ------- a second load (the F5 dev loop, or another mod ahead of this one
-- having done the same job) must not convert what is already converted

local reloaded = dataset({
  FIXMON_B = {
    { method = "LEVEL", level = 36, species = "FIXMON_C" },
    { method = "TRADE", level = 1, species = "FIXMON_C" },
  },
})

local run3 = T.sdk.loadMod(MOD, { data = reloaded, fs = checkoutFs() })
T.eq(#run3.errors, 0, "loads clean on a converted dataset")

local twice = reloaded.pokemon.FIXMON_B.evolutions
T.eq(#twice, 2, "the rows are left exactly as they were")
T.eq(twice[1].method, "LEVEL", "no second level row was appended")
T.eq(twice[1].level, 36, "at the level the first pass set")
T.eq(twice[2].method, "TRADE", "and the trade row is not duplicated either")

run3.release()

-- ------- Gold's vocabulary
--
-- Gold spells the same rows EVOLVE_TRADE / EVOLVE_LEVEL and points at
-- `into` rather than `species`.  A Gen 2 boot needs a Gen 2 dataset, so the
-- entry chunk is driven directly here with a stub `mod` -- the same object
-- shape the loader hands it, minus everything this mod never touches.

local entry = assert(loadfile(MOD .. "/main.lua"))()

local gold = {
  ONIX = {
    evolutions = { { method = "EVOLVE_TRADE", item = "METAL_COAT",
                     into = "STEELIX" } },
  },
  POLIWHIRL = {
    evolutions = {
      { method = "EVOLVE_ITEM", item = "WATER_STONE", into = "POLIWRATH" },
      { method = "EVOLVE_TRADE", item = "KINGS_ROCK", into = "POLITOED" },
    },
  },
}

local logged = {}
entry({
  -- nil for every key: the stub has no stored values, so the entry chunk
  -- falls back to its own defaults exactly as it does on a fresh install
  options = { define = function() end, get = function() return nil end },
  content = {
    pokemon = {
      each = function()
        return coroutine.wrap(function()
          for id, mon in pairs(gold) do coroutine.yield(id, mon) end
        end)
      end,
      patch = function(_, id, fields)
        for key, value in pairs(fields) do gold[id][key] = value end
      end,
    },
  },
  log = {
    info = function(_, fmt) logged[#logged + 1] = { "info", fmt } end,
    warn = function(_, fmt) logged[#logged + 1] = { "warn", fmt } end,
  },
})

T.eq(#logged, 1, "one log line: the summary, with nothing to warn about")
T.eq(logged[1][1], "info", "and it is an info line")

local onix = gold.ONIX.evolutions
T.eq(#onix, 2, "ONIX's trade route gained a level route")
T.eq(onix[1].method, "EVOLVE_LEVEL", "written with Gold's own level method")
T.eq(onix[1].level, 36, "at level 36")
T.eq(onix[1].into, "STEELIX", "keeping Gold's `into` key")
T.eq(onix[1].item, nil, "the held-item requirement is dropped from it")
T.eq(onix[2].method, "EVOLVE_TRADE", "and the cable route is kept")
T.eq(onix[2].item, "METAL_COAT", "with its held item intact")

local poliwhirl = gold.POLIWHIRL.evolutions
T.eq(#poliwhirl, 2, "POLIWHIRL is not trade-only, so it is left alone")
T.eq(poliwhirl[1].method, "EVOLVE_ITEM", "its stone route survives")
T.eq(poliwhirl[2].method, "EVOLVE_TRADE", "and so does its trade route")

-- the rewritten rows through Gold's own dispatch, which is where its two
-- cross-cutting gates (a link is up / a stone is being used) and the
-- Everstone live
local Gen2Evolution = require("src.core.gen2.Evolution")

local function goldPending(level, ctx, held)
  -- checkMon takes a dataset, and `gold` is only its species table
  local entry = Gen2Evolution.checkMon({ pokemon = gold },
    { species = "ONIX", level = level, item = held,
      stats = { attack = 45, defense = 160 } }, ctx or {})
  return entry and entry.method, entry and entry.into
end

T.eq(goldPending(35, {}), nil, "ONIX does not evolve at 35 after a battle")
T.eq(goldPending(36, {}), "EVOLVE_LEVEL", "it evolves at 36 with no Metal Coat")
T.eq(select(2, goldPending(36, {})), "STEELIX", "into STEELIX")
T.eq(goldPending(36, {}, "EVERSTONE"), nil, "an Everstone still stops it")
T.eq(goldPending(5, { link = true }, "METAL_COAT"), "EVOLVE_TRADE",
  "and the Metal Coat trade still evolves it")
T.eq(goldPending(36, { force = true, item = "FIRE_STONE" }), nil,
  "using a stone does not trip the new level row")

T.finish("trade_evolutions_by_level")
