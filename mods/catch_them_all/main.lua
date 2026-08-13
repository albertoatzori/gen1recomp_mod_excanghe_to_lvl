-- catch_them_all (api 2): every species your version simply does not offer
-- gets a home in the wild, so a Pokedex can be finished without a second
-- cartridge and a cable.
--
-- HOW IT DECIDES WHAT IS MISSING
--
-- Two of the three ways a Pokemon reaches your party are data, and the mod
-- reads them:
--   * the wild, from the encounter tables (data.encounters, one entry per
--     map, each with grass/water sub-tables of {species, level} slots),
--   * evolution, from each species' own evolutions list -- anything that
--     evolves from something reachable is itself reachable.
-- The third is a script: `give_pokemon`, `static_battle` and `trade` are
-- calls inside map script FUNCTIONS, not rows in a table, so they cannot be
-- discovered at load.  obtainable.lua is where those are declared, and until
-- it is filled the mod adds NOTHING and says so -- guessing would drop the
-- starters, Snorlax and Mewtwo into the first patch of grass.
--
-- HOW IT ADDS THEM
--
-- A slot's POSITION in the list is its probability (src/world/Encounter.lua
-- walks the buckets and takes slots[i]), and the mod-facing schema allows a
-- table to carry only `rate` and `slots` -- `buckets` is engine-side, so the
-- list cannot simply grow: an eleventh slot in a ten-bucket table would never
-- be rolled.  A species therefore TAKES a slot rather than being appended.
--
-- Which slot is the whole point.  A wild table repeats species across its
-- slots and across maps, so the mod counts every occurrence in the dataset
-- first and will only ever overwrite a slot whose species still has another
-- one left.  A mod that exists to make Pokemon obtainable must not make one
-- unobtainable on the way, and this is the rule that guarantees it.  The
-- rarest slots are offered up first, so the common encounters of an area
-- stay the ones you remember.
--
-- Where each species lands is derived, not random: a stable hash of its id
-- picks from the maps whose habitat suits it -- water tables for Water types,
-- grass for everyone else -- and it inherits the level of the slot it takes,
-- so nothing shows up forty levels above its neighbours.  The same dataset
-- therefore always produces the same world, which is what makes a bug in it
-- reportable.

local HOMES = {
  { "1 AREA", 1 },
  { "2 AREAS", 2 },
  { "3 AREAS", 3 },
}
local DEFAULT_HOMES = 2

-- Legendaries are never wild in any version, so with obtainable.lua filled
-- they are already excluded.  This is the belt to that pair of braces: it
-- also covers a half-filled list, and it is a list of names -- stable across
-- versions -- rather than a fact about any one cartridge.
local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  HOOH = true, CELEBI = true,
}

-- deterministic, dataset-independent: the same id always picks the same
-- home, so two players with the same game find the same world
local function hash(id)
  local h = 5381
  for i = 1, #id do
    h = (h * 33 + id:byte(i)) % 2147483647
  end
  return h
end

local function isWaterType(def)
  local types = def and (def.types or { def.type1, def.type2 })
  for _, t in ipairs(types or {}) do
    if tostring(t):upper() == "WATER" then return true end
  end
  return false
end

-- every sub-table of an encounter def that actually rolls: grass, water, and
-- whatever else a dataset or another mod put there
local function terrainsOf(encDef)
  local out = {}
  for name, terrain in pairs(encDef or {}) do
    if type(terrain) == "table" and type(terrain.slots) == "table"
        and #terrain.slots > 0 then
      out[#out + 1] = { name = name, terrain = terrain }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

return function(mod)
  mod.options:define({
    { key = "homes", label = "AREAS EACH", type = "choice",
      default = DEFAULT_HOMES, choices = HOMES },
    { key = "legendaries", label = "INCLUDE LEGENDARIES", type = "toggle",
      default = false },
  })

  -- Options are read once here, unlike this repo's other mods: the encounter
  -- tables are rewritten at merge time, so these shape the DATA rather than
  -- a decision taken later.  Changing them takes effect on the next boot,
  -- and the README says so.
  local homes = math.max(1, math.min(6, math.floor(
    tonumber(mod.options:get("homes")) or DEFAULT_HOMES)))
  local withLegendaries = mod.options:get("legendaries") == true

  -- ------- the declared list, the piece that cannot be computed

  local source = mod:read("obtainable.lua")
  if not source then
    mod.log:error("obtainable.lua missing from %s -- reinstall the mod", mod.path)
    return
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/obtainable.lua")
  if not chunk then
    mod.log:error("obtainable.lua did not compile: %s", tostring(compileErr))
    return
  end
  local ok, declared = pcall(chunk)
  if not ok or type(declared) ~= "table" then
    mod.log:error("obtainable.lua did not return a table: %s", tostring(declared))
    return
  end

  -- Which list applies.  The loader does not hand a mod its generation, so
  -- this probes the merged species for a Johto starter -- present in a Gold
  -- dataset, absent from Red/Blue/Yellow.  Picking the wrong list can only
  -- make the mod more conservative, never less.
  local isGen2 = mod.content.pokemon:get("CHIKORITA") ~= nil
  local scripted = {}
  for _, id in ipairs(declared[isGen2 and "gen2" or "gen1"] or {}) do
    scripted[id] = true
  end

  -- ------- what the data already offers

  local reachable = {}
  local grassMaps, waterMaps = {}, {}
  -- how many slots in the whole dataset hold each species; a slot may only be
  -- taken while its occupant has another one left somewhere
  local census = {}

  for mapId, encDef in mod.content.encounters:each() do
    for _, entry in ipairs(terrainsOf(encDef)) do
      for _, slot in ipairs(entry.terrain.slots) do
        if slot.species then
          reachable[slot.species] = true
          census[slot.species] = (census[slot.species] or 0) + 1
        end
      end
      local home = { map = mapId, terrain = entry.name }
      if entry.name == "water" then
        waterMaps[#waterMaps + 1] = home
      else
        grassMaps[#grassMaps + 1] = home
      end
    end
  end

  for id in pairs(scripted) do reachable[id] = true end

  -- evolution closure: anything that evolves from something reachable is
  -- itself reachable, however long the chain
  local changed = true
  while changed do
    changed = false
    for id, def in mod.content.pokemon:each() do
      if reachable[id] then
        for _, evo in ipairs(def.evolutions or {}) do
          if evo.species and not reachable[evo.species] then
            reachable[evo.species] = true
            changed = true
          end
        end
      end
    end
  end

  -- ------- the gap

  local missing = {}
  for id in mod.content.pokemon:each() do
    if not reachable[id] and (withLegendaries or not LEGENDARY[id]) then
      missing[#missing + 1] = id
    end
  end
  table.sort(missing)

  -- Fail closed.  With nothing declared, "not reachable" also covers every
  -- starter, fossil, gift and static in the game, and adding those to the
  -- grass would be worse than doing nothing.
  if next(scripted) == nil then
    mod.log:warn("obtainable.lua is empty, so %d species look unobtainable "
      .. "-- including the ones scripts hand you.  Nothing added; fill "
      .. "obtainable.lua and reboot.", #missing)
    return
  end

  if #missing == 0 then
    mod.log:info("every species is already obtainable; nothing to add")
    return
  end

  -- ------- give them homes

  -- every placement, kept so the mod can hand back the table it just made:
  -- which species, where, in place of what.  Nobody can read this out of the
  -- merged data afterwards, and a player cannot see the log at all in a
  -- packaged build, so it is written to storage as a report below.
  local report = {}
  local placed = {}
  for _, id in ipairs(missing) do
    local def = mod.content.pokemon:get(id)
    local pool = isWaterType(def) and #waterMaps > 0 and waterMaps or grassMaps
    if #pool == 0 then
      mod.log:warn("%s has nowhere to live: no encounter table to add it to", id)
    else
      local h = hash(id)
      local taken = 0
      -- walk the pool from the hashed start so a species that finds no
      -- sacrificeable slot in its first area keeps looking rather than
      -- being dropped
      for n = 0, #pool - 1 do
        if taken >= homes then break end
        local home = pool[(h + n) % #pool + 1]
        local encDef = mod.content.encounters:get(home.map)
        local terrain = encDef and encDef[home.terrain]
        if terrain and terrain.slots then
          -- copy before writing: :get hands back the merged view, and a
          -- patch describes the new value rather than mutating it
          local slots = {}
          for i, slot in ipairs(terrain.slots) do
            slots[i] = { species = slot.species, level = slot.level }
          end
          -- rarest first: the tail of the list is the least likely bucket,
          -- so an area keeps the encounters it is known for
          local victim
          for i = #slots, 1, -1 do
            local occupant = slots[i].species
            if occupant ~= id and (census[occupant] or 0) > 1 then
              victim = i
              break
            end
          end
          if victim then
            local replaced = slots[victim].species
            census[replaced] = census[replaced] - 1
            slots[victim] = { species = id, level = slots[victim].level }
            census[id] = (census[id] or 0) + 1

            local mapDef = mod.content.maps and mod.content.maps:get(home.map)
            report[#report + 1] = {
              species = id,
              map = home.map,
              place = (mapDef and (mapDef.label or mapDef.name)) or home.map,
              terrain = home.terrain,
              level = slots[victim].level,
              instead_of = replaced,
            }

            local patch = {}
            for name, value in pairs(encDef) do patch[name] = value end
            patch[home.terrain] = { rate = terrain.rate, slots = slots }
            mod.content.encounters:patch(home.map, patch)
            taken = taken + 1
          end
        end
      end
      if taken > 0 then
        placed[#placed + 1] = id
      else
        mod.log:warn("%s could not be placed: every slot holds the last copy "
          .. "of its species, and none may be overwritten", id)
      end
    end
  end

  if #placed == 0 then
    mod.log:warn("%d species are missing but none could be placed: every "
      .. "encounter slot holds the last copy of its species", #missing)
    return
  end

  mod.log:info("%d species now appear in the wild (up to %d area(s) each): %s",
    #placed, homes, table.concat(placed, ", "))
  -- the same table, one line each, for anyone watching a terminal
  for _, row in ipairs(report) do
    mod.log:info("  %s -- %s (%s), level %d, in place of %s",
      row.species, row.place, row.terrain, row.level, row.instead_of)
  end

  -- And for everyone else.  A packaged build shows no log, so the report is
  -- written into the mod's own storage the first time a playthrough is open:
  -- storage is scoped to a save, so it cannot be written at load time.
  local written = false
  local function writeReport(payload)
    if written then return end
    local game = (payload and payload.game) or mod.game
    if not game then return end
    local ok = mod.storage:write(game, "report", {
      generated_for = isGen2 and "gen2" or "gen1",
      areas_each = homes,
      placements = report,
    })
    if ok then
      written = true
      mod.log:info("wrote the placement report to this playthrough's storage")
    end
  end
  mod.events:on("save.loaded", writeReport)
  mod.events:on("save.created", writeReport)
  mod.events:on("map.entered", writeReport)
end
