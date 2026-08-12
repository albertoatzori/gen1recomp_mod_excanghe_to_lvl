-- exp_multiplier (api 2): every experience payout is multiplied by a factor
-- the player picks -- 2x, 3x, 5x, 10x, 30x, 50x or 100x -- with OFF (1x) to
-- park the mod without uninstalling it.
--
-- One seam does both games: `exp.gain` is called by src/battle/Experience.lua
-- on Red and src/battle/gen2/Battle.lua on Gold with the same ctx keys, and
-- its vanilla returns the share a single mon is about to receive -- after the
-- participant split, the traded x1.5, the trainer x1.5 and (on Gold) the
-- EXP.SHARE tax and LUCKY EGG.  Multiplying that result therefore scales what
-- the mon actually gets, in one place, without re-deriving any of it.
--
-- Stat experience is deliberately NOT scaled: it is awarded on its own path
-- from the defeated species' base stats, and multiplying it would rewrite the
-- stat spread of every mon rather than just its pace.
--
-- The factor is read inside the hook rather than at load, so choosing a new
-- one in the mod manager applies to the very next battle -- ManagerState
-- writes it straight into the live loader (`setOption`), which is what
-- mod.options:get reads.

-- Values are the multiplier itself, so the option IS the number.
local FACTORS = { 1, 2, 3, 5, 10, 30, 50, 100 }
local DEFAULT_FACTOR = 2

-- Red stores exp in a 3-byte field and, unlike Gold (src/battle/gen2/Mon.lua
-- clamps to the level-100 requirement), never clamps it: GenSave's setU24be
-- masks on export, so an over-max total would silently wrap when the save is
-- written out as a .sav.  Vanilla can never grind that far; 100x can, so the
-- payout is trimmed to whatever room is left rather than allowed past it.
local MAX_STORED_EXP = 0xFFFFFF

local function label(factor)
  if factor == 1 then return "OFF (1x)" end
  return factor .. "x"
end

return function(mod)
  local choices = {}
  for _, factor in ipairs(FACTORS) do
    choices[#choices + 1] = { label(factor), factor }
  end
  mod.options:define({
    { key = "factor", label = "EXP MULTIPLIER", type = "choice",
      default = DEFAULT_FACTOR, choices = choices },
  })

  local function factor()
    local stored = tonumber(mod.options:get("factor"))
    if not stored then return DEFAULT_FACTOR end
    for _, allowed in ipairs(FACTORS) do
      if stored == allowed then return stored end
    end
    -- an options.lua hand-edited to something off the list still has to mean
    -- something: keep it usable but inside the range the mod tested
    return math.max(1, math.min(FACTORS[#FACTORS], math.floor(stored)))
  end

  mod.hooks:wrap("exp.gain", function(next, ctx)
    local base = next(ctx)
    local mult = factor()
    -- OFF is a real passthrough: the vanilla number, not a rounded copy of it
    if mult == 1 or type(base) ~= "number" then return base end

    local scaled = math.floor(base * mult)
    -- Gold's own field is `experience`; Red's is `exp`
    local mon = ctx.mon or {}
    local held = mon.exp or mon.experience or 0
    local room = MAX_STORED_EXP - held
    if room <= 0 then return 0 end
    return math.min(scaled, room)
  end)

  mod.log:info("experience payouts are %s", label(factor()))
end
