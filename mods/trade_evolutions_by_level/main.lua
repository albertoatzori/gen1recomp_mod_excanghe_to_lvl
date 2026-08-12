-- trade_evolutions_by_level (api 2): the lines that vanilla only lets you
-- finish over a link cable -- KADABRA, MACHOKE, GRAVELER, HAUNTER on Red,
-- plus ONIX, SCYTHER, SEADRA and PORYGON on Gold -- evolve on their own at
-- level 36, so a solo playthrough can complete them.
--
-- Only a species whose EVERY evolution row is a trade row is rewritten,
-- which is exactly what "evolves only by trade" means.  POLIWHIRL (Water
-- Stone) and SLOWPOKE (level 37) keep their own routes untouched: they
-- already evolve without a cable, and a second row firing on the same
-- trigger would silently steal the vanilla evolution.
--
-- Red spells its rows LEVEL / TRADE, Gold spells them EVOLVE_LEVEL /
-- EVOLVE_TRADE, so both vocabularies are handled.  Each row is copied field
-- by field and only `method`, `level` and `item` are touched, so the target
-- species -- `species` on Red, `into` on Gold -- rides along untouched.
--
-- Data only: no hook is wrapped and no engine module is required, so the
-- rewritten rows flow through the ordinary evolution paths (after-battle
-- check, Rare Candy, the evolution movie).

local DEFAULT_LEVEL = 36
local MIN_LEVEL, MAX_LEVEL = 2, 100

-- a trade method id -> the level method id of the same generation
local LEVEL_METHOD = { TRADE = "LEVEL", EVOLVE_TRADE = "EVOLVE_LEVEL" }
-- the same pair as a set, for recognising a row this mod wrote
local LEVEL_METHOD_ID = { LEVEL = true, EVOLVE_LEVEL = true }

-- Gold's one item that refuses an evolution outright; the engine tests it
-- inside the check this mod answers ahead of, so it is tested here too
local EVERSTONE = "EVERSTONE"

-- true when the species can evolve, and every way it can is a trade
local function tradeOnly(evolutions)
  if type(evolutions) ~= "table" or #evolutions == 0 then return false end
  for _, evo in ipairs(evolutions) do
    if not LEVEL_METHOD[evo.method] then return false end
  end
  return true
end

-- rows are copied rather than re-listed: the merged view's own tables stay
-- out of the patch, so nothing this writes aliases what it just read
local function copyRow(evo)
  local row = {}
  for key, value in pairs(evo) do row[key] = value end
  return row
end

-- the same row, evolving by level instead.  `item` goes because Gold's
-- held-item trades (ONIX + METAL_COAT) have no held-item level method to
-- carry it into; the level alone is the requirement now.
local function asLevelRow(evo, level)
  local row = copyRow(evo)
  row.method = LEVEL_METHOD[evo.method]
  row.level = level
  row.item = nil
  return row
end

return function(mod)
  mod.options:define({
    { key = "level", label = "EVOLVE AT", type = "number",
      default = DEFAULT_LEVEL, min = MIN_LEVEL, max = MAX_LEVEL, step = 1 },
    -- off means the cable stops working for these lines entirely; on keeps
    -- the original row alongside the new one, and the two never collide
    -- because each answers a different trigger
    { key = "keep_trade", label = "TRADING STILL EVOLVES", type = "toggle",
      default = true },
  })

  -- The level the manager is showing RIGHT NOW.  Read on every decision, not
  -- once at load: the manager writes a changed option straight into the live
  -- loader, so a mod that snapshots it at boot ends up enforcing one number
  -- while the settings screen displays another, with nothing on screen to
  -- say they disagree.  That is a debugging trap, and the merged rows below
  -- can only ever hold the value that was current when the game booted.
  local function wantedLevel()
    local stored = tonumber(mod.options:get("level")) or DEFAULT_LEVEL
    return math.max(MIN_LEVEL, math.min(MAX_LEVEL, math.floor(stored)))
  end

  local level = wantedLevel()
  local keepTrade = mod.options:get("keep_trade") ~= false

  -- each() walks the merged view -- the engine's species plus every mod
  -- ahead of this one -- so a mod-added trade evolution is converted too
  -- instead of this hard-coding the four Red lines
  local changed = {}
  local converted = {}
  for id, mon in mod.content.pokemon:each() do
    -- read the species out before patching it: the row count below has to
    -- describe what was there, not what this loop just wrote
    local vanilla = mon.evolutions
    if tradeOnly(vanilla) then
      local rows = {}
      for _, evo in ipairs(vanilla) do
        rows[#rows + 1] = asLevelRow(evo, level)
        if keepTrade then rows[#rows + 1] = copyRow(evo) end
      end
      -- a list replaces wholesale even inside a patch, so the new rows are
      -- written out in full while every other field of the species is left
      -- to whatever the merged view already says
      mod.content.pokemon:patch(id, { evolutions = rows })
      changed[#changed + 1] = id
      converted[id] = true
      if #vanilla > 1 then
        -- only reachable through another mod: the first matching row wins,
        -- so the rest can never fire once they all share one level
        mod.log:warn(
          "%s has %d trade evolutions; only the first can fire at level %d",
          id, #vanilla, level)
      end
    end
  end

  -- The rows above carry the level as of boot; this is what actually decides,
  -- so the settings screen is never lying about what the game will do.  Only
  -- the converted species' level rows are answered here -- every other row,
  -- including their kept trade row, falls through to the engine, which is
  -- also how a Gold Everstone and a stone in use keep their say.
  mod.hooks:wrap("evolution.check", function(next, first, mon, evo, trigger)
    local species = mon and mon.species
    if not (species and converted[species] and evo and LEVEL_METHOD_ID[evo.method]) then
      return next(first, mon, evo, trigger)
    end
    if trigger and trigger.kind then
      -- Gen 1: an explicit trigger, and only a level-up is ours
      if trigger.kind ~= "levelup" then return next(first, mon, evo, trigger) end
    else
      -- Gold: the after-battle sweep is the moment with neither a link up
      -- nor a stone being forced; leave both of those to the engine
      if trigger and (trigger.link or trigger.force) then
        return next(first, mon, evo, trigger)
      end
      if mon.item == EVERSTONE then return next(first, mon, evo, trigger) end
    end
    return (mon.level or 0) >= wantedLevel()
  end)

  table.sort(changed)
  if #changed == 0 then
    mod.log:warn("no trade-only species in the merged view; nothing to do")
  else
    mod.log:info("%d species now evolve at level %d: %s",
      #changed, level, table.concat(changed, ", "))
  end
end
