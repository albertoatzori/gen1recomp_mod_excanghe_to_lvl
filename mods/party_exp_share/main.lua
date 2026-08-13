-- party_exp_share (api 2): every Pokemon in the party that is still standing
-- gains experience from a battle, not just the ones that fought -- the
-- modern EXP. SHARE, without the item and without a slot in the bag.
--
-- One seam does both games.  `battle.exp_award` is raised by
-- src/battle/BattleState.lua on Red and src/battle/gen2/Battle.lua on Gold,
-- and the engine factored it out for exactly this: its comment says "so a mod
-- can replace it wholesale (e.g. a flat undivided share to every non-fainted
-- party mon) without re-deriving participants/alive".  So this REPLACES the
-- vanilla split rather than wrapping it -- calling next() as well would pay
-- the fighters twice.
--
-- ctx.applyShare(mon, split, announce) is the same helper vanilla uses, and
-- it is what makes this small: it divides the payout by `split`, prints the
-- gain, raises the level, plays the fanfare, teaches the moves due at that
-- level and marks the mon for the after-battle evolution sweep.  The mod
-- decides who is paid and how much of a share each one gets; the engine keeps
-- doing everything that follows.
--
-- Because it replaces the split, it also supersedes Red's EXP.ALL: holding
-- the item changes nothing while this is on, which is the point of it.
--
-- The options are read inside the hook rather than at load, so a new choice
-- applies to the very next battle -- ManagerState writes an option straight
-- into the live loader, which is what mod.options:get reads.

-- How much a mon that did NOT fight receives, as a share of what a fighter
-- gets.  Fighters are always paid their vanilla share; this is the rest of
-- the party's cut of that same amount.
local SHARES = {
  { "FULL (same as fighters)", 1 },
  { "HALF", 0.5 },
  { "QUARTER", 0.25 },
}
local DEFAULT_SHARE = 1

-- Vanilla prints one "gained N EXP. Points!" box per mon paid.  With six
-- mons that is six boxes after every battle, so the quiet setting announces
-- only the fighters.  Level-ups are NOT part of this: applyShare prints
-- "grew to level" and shows the stat box outside the announcement branch, so
-- a silent share still tells you when someone levels.
local ANNOUNCE = {
  { "FIGHTERS ONLY", "fighters" },
  { "EVERY POKEMON", "all" },
}
local DEFAULT_ANNOUNCE = "fighters"

-- Red hangs the party off the game; Gold's battle carries its own reference.
local function partyOf(battle)
  if not battle then return nil end
  local game = battle.game
  if game and game.save and game.save.party then return game.save.party end
  return battle.party
end

return function(mod)
  mod.options:define({
    { key = "share", label = "BENCH GETS", type = "choice",
      default = DEFAULT_SHARE, choices = SHARES },
    { key = "announce", label = "EXP MESSAGES", type = "choice",
      default = DEFAULT_ANNOUNCE, choices = ANNOUNCE },
  })

  local function share()
    local stored = tonumber(mod.options:get("share"))
    if not stored then return DEFAULT_SHARE end
    -- an options.lua hand-edited off the list still has to mean something,
    -- but a share of 0 would silently pay the bench nothing at all, which is
    -- this mod switched off wearing its own name: floor it just above that
    return math.max(0.01, math.min(1, stored))
  end

  local function announceAll()
    return tostring(mod.options:get("announce") or DEFAULT_ANNOUNCE) == "all"
  end

  mod.hooks:wrap("battle.exp_award", function(_, ctx)
    -- the fighters, paid exactly as vanilla pays them
    local fought = {}
    for _, mon in ipairs(ctx.alive or {}) do
      fought[mon] = true
      ctx.applyShare(mon, ctx.participants, true)
    end

    local party = partyOf(ctx.battle)
    if not party then return end

    -- and the bench.  A bigger `split` is a smaller payout, so a HALF share
    -- is the fighters' divisor doubled.  Fainted mons are skipped, which is
    -- the one rule vanilla's own EXP.ALL pass keeps.
    local split = math.max(1, math.floor(ctx.participants / share() + 0.5))
    local loud = announceAll()
    for _, mon in ipairs(party) do
      if not fought[mon] and (mon.hp or 0) > 0 then
        ctx.applyShare(mon, split, loud)
      end
    end
  end)

  mod.log:info("the whole party gains exp; the bench gets %g of a fighter's share",
    share())
end
