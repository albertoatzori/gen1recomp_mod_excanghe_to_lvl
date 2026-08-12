-- Standalone:
--   luajit mods/trade_evolutions_by_level/tests/trade_evolutions_by_level_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, so the merge, the schema validation and the option read
-- are the production ones.  The fixture ships no trade evolution of its
-- own, so each case plants the rows it wants to see rewritten.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")

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

run2.release()

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

T.finish("trade_evolutions_by_level")
