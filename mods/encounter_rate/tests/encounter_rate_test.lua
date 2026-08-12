-- Standalone: luajit mods/encounter_rate/tests/encounter_rate_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, and the suppression is then measured through the hook the
-- engine actually raises, with a scripted RNG -- so what is asserted is what
-- a step in the grass does, not a private copy of the arithmetic.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")
local Runtime = require("src.mods.Runtime")

local MOD = "mods/encounter_rate"

-- Writes are dropped so no case leaves the loader's option-schema snapshot in
-- the checkout, and the "mods" listing is narrowed to this mod so the other
-- committed mods stay out of the merge.
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
    if path == "mods" then return { "encounter_rate" } end
    return inner.getDirectoryItems(path)
  end
  fs.write = function() return true end
  return fs
end

-- The engine's own call shape (OverworldController:rollEncounter): vanilla
-- returns an encounter table, and the mod decides whether it is reached.
local ENCOUNTER = { species = "FIXMON_A", level = 7 }

-- `draws` is fed to ctx.rng in order, so each case states exactly which die
-- the mod is answering rather than depending on a real RNG.
local function step(draws)
  local i = 0
  local vanillaCalls = 0
  local function vanilla()
    vanillaCalls = vanillaCalls + 1
    return ENCOUNTER
  end
  local ctx = {
    mapId = "FIXMAP", terrain = "grass",
    rng = function()
      i = i + 1
      return draws[i] or 0
    end,
  }
  local enc = Runtime.call("encounter.roll", vanilla, { }, ctx)
  return enc, vanillaCalls, i
end

-- ------- the mod is off the merge until it is loaded

local enc = step({ 0.99 })
T.eq(enc, ENCOUNTER, "with no mod loaded the vanilla roll is what comes back")

-- ------- NORMAL is a real passthrough, not a re-rolled copy

local run = T.sdk.loadMods({ MOD },
  { data = T.fixtures.fresh(), fs = checkoutFs({ encounter_rate = { rate = 1 } }) })
T.eq(#run.errors, 0, "NORMAL: the mod loads clean")

local encNormal, calls, draws = step({ 0.99 })
T.eq(encNormal, ENCOUNTER, "NORMAL still returns the vanilla encounter")
T.eq(calls, 1, "and reached the vanilla roll")
T.eq(draws, 0, "without spending a die of its own")
run.release()

-- ------- HALF: the draw decides, and a suppressed step costs no vanilla roll

run = T.sdk.loadMods({ MOD },
  { data = T.fixtures.fresh(), fs = checkoutFs({ encounter_rate = { rate = 0.5 } }) })
T.eq(#run.errors, 0, "HALF: the mod loads clean")

local kept, keptCalls = step({ 0.10 })
T.eq(kept, ENCOUNTER, "HALF: a draw under the rate keeps the encounter")
T.eq(keptCalls, 1, "and that one did reach the vanilla roll")

local dropped, droppedCalls = step({ 0.90 })
T.eq(dropped, nil, "HALF: a draw over the rate suppresses it")
T.eq(droppedCalls, 0, "and never asks the engine to pick a mon")

-- the boundary belongs to the suppressed side (rng() >= keep), so exactly
-- half of a uniform [0,1) stream survives rather than half plus one edge
local edge = step({ 0.5 })
T.eq(edge, nil, "HALF: a draw exactly at the rate is suppressed")
run.release()

-- ------- QUARTER moves that boundary, and nothing else

run = T.sdk.loadMods({ MOD },
  { data = T.fixtures.fresh(), fs = checkoutFs({ encounter_rate = { rate = 0.25 } }) })
T.eq((step({ 0.20 })), ENCOUNTER, "QUARTER keeps a draw under 0.25")
T.eq((step({ 0.30 })), nil, "QUARTER drops a draw the HALF setting kept")
run.release()

-- ------- OFF suppresses without spending a die at all

run = T.sdk.loadMods({ MOD },
  { data = T.fixtures.fresh(), fs = checkoutFs({ encounter_rate = { rate = 0 } }) })
local off, offCalls, offDraws = step({ 0.001 })
T.eq(off, nil, "OFF suppresses even the luckiest draw")
T.eq(offCalls, 0, "the engine is never asked for a mon")
T.eq(offDraws, 0, "and no die is thrown to decide it")
run.release()

-- ------- a hand-edited options.lua stays usable

run = T.sdk.loadMods({ MOD },
  { data = T.fixtures.fresh(), fs = checkoutFs({ encounter_rate = { rate = 0.1 } }) })
T.eq((step({ 0.05 })), ENCOUNTER, "an off-list 0.1 still keeps a low draw")
T.eq((step({ 0.5 })), nil, "and still drops a high one")
run.release()

run = T.sdk.loadMods({ MOD },
  { data = T.fixtures.fresh(), fs = checkoutFs({ encounter_rate = { rate = 42 } }) })
T.eq((step({ 0.99 })), ENCOUNTER, "a nonsense 42 clamps to NORMAL, not to nothing")
run.release()

-- ------- the default, with no options.lua at all

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(), fs = checkoutFs(nil) })
T.eq(#run.errors, 0, "a fresh install loads clean")
T.eq((step({ 0.10 })), ENCOUNTER, "the default keeps a low draw")
T.eq((step({ 0.90 })), nil, "and drops a high one -- HALF out of the box")
run.release()

-- ------- and the hook is gone once the mod is released

T.eq((step({ 0.99 })), ENCOUNTER, "released: the vanilla roll is reached again")

T.finish("encounter_rate")
