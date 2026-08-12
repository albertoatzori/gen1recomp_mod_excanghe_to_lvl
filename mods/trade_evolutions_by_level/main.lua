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

  local level = math.floor(tonumber(mod.options:get("level")) or DEFAULT_LEVEL)
  level = math.max(MIN_LEVEL, math.min(MAX_LEVEL, level))
  local keepTrade = mod.options:get("keep_trade") ~= false

  -- each() walks the merged view -- the engine's species plus every mod
  -- ahead of this one -- so a mod-added trade evolution is converted too
  -- instead of this hard-coding the four Red lines
  local changed = {}
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
      if #vanilla > 1 then
        -- only reachable through another mod: the first matching row wins,
        -- so the rest can never fire once they all share one level
        mod.log:warn(
          "%s has %d trade evolutions; only the first can fire at level %d",
          id, #vanilla, level)
      end
    end
  end

  table.sort(changed)
  if #changed == 0 then
    mod.log:warn("no trade-only species in the merged view; nothing to do")
  else
    mod.log:info("%d species now evolve at level %d: %s",
      #changed, level, table.concat(changed, ", "))
  end
end
