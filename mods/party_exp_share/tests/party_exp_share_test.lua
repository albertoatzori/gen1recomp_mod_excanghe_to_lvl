-- Standalone: luajit mods/party_exp_share/tests/party_exp_share_test.lua
--
-- ROM-free: the mod is loaded through the real headless loader against the
-- fixture dataset, and the award is then driven through the hook the engine
-- actually raises, with the same ctx it passes -- an applyShare that records
-- who was paid and with which divisor, standing in for the engine helper that
-- would print the box and raise the level.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local SaveSerializer = require("src.core.SaveSerializer")
local Runtime = require("src.mods.Runtime")

local MOD = "mods/party_exp_share"

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
    if path == "mods" then return { "party_exp_share" } end
    return inner.getDirectoryItems(path)
  end
  fs.write = function() return true end
  return fs
end

local function mon(name, hp)
  return { species = "FIXMON_A", nickname = name, hp = hp == nil and 20 or hp,
           level = 5, exp = 0, stats = { hp = 20 }, dvs = {}, statExp = {} }
end

-- The engine's own call shape.  `paid[name]` is the divisor that mon was
-- awarded with -- a bigger divisor is a smaller payout -- and `announced` is
-- what the third applyShare argument said for it.
local function award(party, fighters, opts)
  opts = opts or {}
  local paid, announced, order = {}, {}, {}
  local ctx = {
    battle = opts.gold and { party = party }
                       or { game = { save = { party = party } } },
    participants = opts.participants or #fighters,
    alive = fighters,
    applyShare = function(m, split, announce)
      paid[m.nickname] = split
      announced[m.nickname] = announce
      order[#order + 1] = m.nickname
    end,
  }
  local vanillaCalls = 0
  Runtime.call("battle.exp_award", function() vanillaCalls = vanillaCalls + 1 end, ctx)
  return paid, announced, vanillaCalls, order
end

-- ------- with no mod loaded the engine's own split is what runs

local party = { mon("LEAD"), mon("BENCH") }
local _, _, vanillaCalls = award(party, { party[1] })
T.eq(vanillaCalls, 1, "unmodded: the vanilla award is what gets called")

-- ------- FULL: the bench is paid exactly what the fighter is

local run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 1 } }) })
T.eq(#run.errors, 0, "FULL: the mod loads clean")

party = { mon("LEAD"), mon("BENCH"), mon("FAINTED", 0) }
local paid, announced, calls = award(party, { party[1] })

T.eq(calls, 0, "the vanilla split is replaced, not run as well")
T.eq(paid.LEAD, 1, "the fighter keeps its vanilla divisor")
T.eq(paid.BENCH, 1, "and the bench is paid on the same divisor at FULL")
T.eq(paid.FAINTED, nil, "a fainted party member is skipped")
T.eq(announced.LEAD, true, "the fighter's gain is announced")
T.eq(announced.BENCH, false, "the bench is quiet by default")
run.release()

-- ------- the fighters' own share is never touched, however many fought

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 1 } }) })
party = { mon("A"), mon("B"), mon("C") }
paid = award(party, { party[1], party[2] }, { participants = 2 })
T.eq(paid.A, 2, "two fighters still split the payout two ways, as vanilla does")
T.eq(paid.B, 2, "for both of them")
T.eq(paid.C, 2, "and the bench matches that share at FULL")
run.release()

-- ------- HALF and QUARTER move only the bench's cut

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 0.5 } }) })
party = { mon("LEAD"), mon("BENCH") }
paid = award(party, { party[1] })
T.eq(paid.LEAD, 1, "HALF: the fighter is unaffected")
T.eq(paid.BENCH, 2, "and the bench is divided twice as hard")
run.release()

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 0.25 } }) })
party = { mon("LEAD"), mon("BENCH") }
paid = award(party, { party[1] })
T.eq(paid.LEAD, 1, "QUARTER: the fighter is still unaffected")
T.eq(paid.BENCH, 4, "and the bench takes a quarter share")
run.release()

-- ------- the loud setting announces the bench too

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 1, announce = "all" } }) })
party = { mon("LEAD"), mon("BENCH") }
local _, loud = award(party, { party[1] })
T.eq(loud.LEAD, true, "EVERY POKEMON: the fighter announces")
T.eq(loud.BENCH, true, "and so does the bench")
run.release()

-- ------- Gold's ctx carries the party on the battle itself

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 1 } }) })
party = { mon("LEAD"), mon("BENCH") }
paid = award(party, { party[1] }, { gold = true })
T.eq(paid.LEAD, 1, "Gold: the fighter is paid")
T.eq(paid.BENCH, 1, "and the bench is found on battle.party")
run.release()

-- ------- a hand-edited options.lua stays usable

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(),
  fs = checkoutFs({ party_exp_share = { share = 0 } }) })
party = { mon("LEAD"), mon("BENCH") }
paid = award(party, { party[1] })
T.check(paid.BENCH ~= nil and paid.BENCH > 1,
  "a share of 0 would pay the bench nothing, so it is floored instead")
run.release()

-- ------- the default, with no options.lua at all

run = T.sdk.loadMods({ MOD }, { data = T.fixtures.fresh(), fs = checkoutFs(nil) })
T.eq(#run.errors, 0, "a fresh install loads clean")
party = { mon("LEAD"), mon("BENCH") }
paid, announced = award(party, { party[1] })
T.eq(paid.BENCH, 1, "out of the box the bench gets a full share")
T.eq(announced.BENCH, false, "and stays quiet about it")
run.release()

-- ------- and the engine's own split is back once the mod is released

party = { mon("LEAD"), mon("BENCH") }
local _, _, backToVanilla = award(party, { party[1] })
T.eq(backToVanilla, 1, "released: the vanilla award runs again")

T.finish("party_exp_share")
