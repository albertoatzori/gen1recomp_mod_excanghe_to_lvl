-- encounter_rate (api 2): thin the wild grass out.  HALF, QUARTER or OFF,
-- with NORMAL to park the mod without uninstalling it.
--
-- One seam does both games: `encounter.roll` is raised by
-- src/world/OverworldController.lua on Red and src/world/gen2/World.lua on
-- Gold, with the same contract -- return nil to suppress the encounter,
-- return a table to force one, or call next() for the vanilla pick.  So the
-- mod never touches the encounter tables and never decides WHICH mon appears;
-- it only decides whether the engine gets to ask.
--
-- The die is thrown BEFORE next(), so a suppressed step consumes no vanilla
-- draw at all rather than rolling an encounter and discarding it.  It uses
-- the engine's own RNG (ctx.rng, love.math.random on both games) rather than
-- a private one, so a seeded run stays reproducible.
--
-- What this does NOT touch, by design:
--   * fishing, which comes through `encounter.fishing` -- OFF still lets you
--     fish, which is the difference between a quiet cave and a dead game,
--   * scripted and static encounters (the Ghost, the legendaries, Snorlax):
--     those are not wild rolls and never reach this hook,
--   * repel, which filters AFTER the roll and so still behaves normally.
--
-- The rate is read inside the hook rather than at load, so a new choice
-- applies to the very next step -- ManagerState writes an option straight
-- into the live loader, which is what mod.options:get reads.

-- The share of encounters that survives.  1 is vanilla; 0 suppresses every
-- wild roll.  Values are the number itself, so the option IS the rate.
local RATES = {
  { "NORMAL", 1 },
  { "HALF", 0.5 },
  { "QUARTER", 0.25 },
  { "OFF (none)", 0 },
}
local DEFAULT_RATE = 0.5

return function(mod)
  mod.options:define({
    { key = "rate", label = "WILD ENCOUNTERS", type = "choice",
      default = DEFAULT_RATE, choices = RATES },
  })

  local function rate()
    local stored = tonumber(mod.options:get("rate"))
    if not stored then return DEFAULT_RATE end
    -- an options.lua hand-edited off the list still has to mean something:
    -- clamp into the range rather than falling back to the default, so a
    -- 0.1 someone typed by hand thins the grass instead of being ignored
    return math.max(0, math.min(1, stored))
  end

  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local keep = rate()
    if keep >= 1 then return next(encDef, ctx) end
    if keep <= 0 then return nil end

    local rng = (ctx and ctx.rng) or (love and love.math and love.math.random)
      or math.random
    if rng() >= keep then return nil end
    return next(encDef, ctx)
  end)

  local function label()
    local current = rate()
    for _, choice in ipairs(RATES) do
      if choice[2] == current then return choice[1] end
    end
    return string.format("%g%% of normal", current * 100)
  end
  mod.log:info("wild encounters: %s", label())
end
