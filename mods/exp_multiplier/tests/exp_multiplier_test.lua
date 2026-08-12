-- Standalone: luajit mods/exp_multiplier/tests/exp_multiplier_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, and the payout is then measured through the engine's own
-- Experience.apply -- the function that raises `exp.gain` on Red -- so what
-- is asserted is the exp a mon actually banks, not the hook in isolation.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")
local Experience = require("src.battle.Experience")
local Runtime = require("src.mods.Runtime")

local MOD = "mods/exp_multiplier"

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
    if path == "mods" then return { "exp_multiplier" } end
    return inner.getDirectoryItems(path)
  end
  fs.write = function() return true end
  return fs
end

local function newMon(level, exp)
  return { species = "FIXMON_A", level = level or 5, exp = exp or 0,
           hp = 20, stats = { hp = 20 }, dvs = {}, statExp = {} }
end

-- one kill, and the exp it banked
local function award(data, mon, opts)
  opts = opts or {}
  local _, gained = Experience.apply(data, mon, data.pokemon.FIXMON_B,
    opts.level or 20, opts.isTrainer or false, opts.participants or 1,
    opts.traded or false)
  return gained
end

-- ------- the vanilla baselines, measured rather than hard-coded
--
-- All of them are taken BEFORE any mod is loaded: the hook lives on the
-- process-wide Runtime, not on the dataset, so a "vanilla" reading taken
-- while the mod is up would be a scaled one and every comparison below
-- would quietly compare 2x against 2x.

local plain = T.fixtures.fresh()
local vanillaGain = award(plain, newMon(5))
local trainerVanilla = award(plain, newMon(5), { isTrainer = true })
local sharedVanilla = award(plain, newMon(5), { participants = 2 })

local slow = newMon(5)
for _ = 1, 6 do award(plain, slow) end
local slowLevel = slow.level

T.check(vanillaGain > 0, "the fixture pays some exp to begin with")
T.check(trainerVanilla > vanillaGain, "a trainer battle really is worth more")
T.check(sharedVanilla < vanillaGain, "and a split kill really is worth less")

-- ------- default: 2x

local data = T.fixtures.fresh()
local run = T.sdk.loadMod(MOD, { data = data, fs = checkoutFs() })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

T.eq(award(data, newMon(5)), vanillaGain * 2, "the default doubles the payout")

-- the boosts vanilla applies before the hook still compound with it: a
-- trainer battle is worth x1.5, and the mod scales that result
T.eq(award(data, newMon(5), { isTrainer = true }), trainerVanilla * 2,
  "a trainer payout is scaled on top of its own x1.5")

-- the participant split happens before the hook too, so a shared kill is
-- scaled after being divided rather than instead of it
T.eq(award(data, newMon(5), { participants = 2 }), sharedVanilla * 2,
  "a split payout is scaled after the split")

-- ------- the exp really lands on the mon, and levels follow

local mon = newMon(5)
local before = mon.exp
local gained = award(data, mon)
T.eq(mon.exp - before, gained, "the mon banked exactly the scaled amount")

local fast = newMon(5)
for _ = 1, 6 do award(data, fast) end
T.check(fast.level > slowLevel,
  "six kills at 2x outlevel six kills at 1x (" ..
  fast.level .. " vs " .. slowLevel .. ")")

run.release()

-- ------- OFF (1x) is a true passthrough

local off = T.fixtures.fresh()
local runOff = T.sdk.loadMod(MOD, {
  data = off,
  fs = checkoutFs({ exp_multiplier = { factor = 1 } }),
})
T.eq(#runOff.errors, 0, "loads clean at 1x")
T.eq(award(off, newMon(5)), vanillaGain, "1x pays exactly the vanilla amount")
runOff.release()

-- ------- 100x, and the ceiling that only 100x can reach

local big = T.fixtures.fresh()
local runBig = T.sdk.loadMod(MOD, {
  data = big,
  fs = checkoutFs({ exp_multiplier = { factor = 100 } }),
})
T.eq(#runBig.errors, 0, "loads clean at 100x")
T.eq(award(big, newMon(5)), vanillaGain * 100, "100x pays a hundred times")

-- Red never clamps exp itself and the save file stores it in three bytes, so
-- the payout is trimmed to the room left instead of wrapping on export
local MAX = 0xFFFFFF
local nearMax = newMon(100, MAX - 10)
award(big, nearMax)
T.eq(nearMax.exp, MAX, "a payout at the ceiling fills it exactly")
T.check(nearMax.exp <= MAX, "and never exceeds the 3-byte exp field")

local atMax = newMon(100, MAX)
T.eq(award(big, atMax), 0, "at the ceiling the payout is zero, not a wrap")
T.eq(atMax.exp, MAX, "and the total stays put")

runBig.release()

-- ------- changing the factor mid-game takes effect on the next battle
--
-- ManagerState:setOption writes into the live loader, which is what
-- mod.options:get reads -- so this is the path the mod manager itself uses,
-- and no reload happens in between.

local live = T.fixtures.fresh()
local runLive = T.sdk.loadMod(MOD, { data = live, fs = checkoutFs() })
T.eq(award(live, newMon(5)), vanillaGain * 2, "starts at the default 2x")

runLive.loader.modOptions = runLive.loader.modOptions or {}
runLive.loader.modOptions.exp_multiplier = { factor = 10 }
T.eq(award(live, newMon(5)), vanillaGain * 10,
  "the next battle already pays 10x, with no reload")

runLive.loader.modOptions.exp_multiplier = { factor = 1 }
T.eq(award(live, newMon(5)), vanillaGain, "and switching to OFF is immediate")

runLive.release()

-- ------- with the mod released, the engine is vanilla again

T.check(not Runtime.wantsHook("exp.gain"),
  "the hook is gone once the mod is released")
T.eq(award(T.fixtures.fresh(), newMon(5)), vanillaGain,
  "and the payout is the vanilla one again")

T.finish("exp_multiplier")
