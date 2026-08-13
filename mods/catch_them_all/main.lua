-- catch_them_all (api 2): every species this version never puts in the grass
-- gets a home there anyway, so a Pokedex can be finished without a second
-- cartridge, a cable, or a Game Corner grind.
--
-- WHAT IT ADDS TO, AND WHY NOTHING IS TAKEN AWAY
--
-- The first version of this mod rewrote the merged encounter tables, giving a
-- newcomer a slot some other species used to hold.  A slot's POSITION is its
-- probability -- src/world/Encounter.lua walks the buckets and takes slots[i]
-- -- and the mod-facing schema exposes only `rate` and `slots`, so the list
-- cannot grow: an eleventh slot in a ten-bucket table would never be rolled.
-- Somebody always had to lose their place.
--
-- This version never touches a table.  `encounter.roll` is allowed to FORCE
-- an encounter -- "returns nil to suppress, a table without calling next to
-- force" -- so the mod lets the engine roll first and only acts on the steps
-- where the answer was "nothing here".  Every vanilla species keeps every one
-- of its encounters; the newcomers fill the silence between them.  The only
-- thing that rises is how often you meet anything at all, which is the honest
-- price of adding without removing.
--
-- HOW OFTEN
--
-- The guest chance is a share of the map's OWN encounter rate, not a flat
-- number: a cave that rolls rarely stays rare, a route that rolls often gets
-- proportionally more.  At UNCOMMON a guest is a quarter as likely as an
-- ordinary encounter, so roughly one wild battle in five is a newcomer.
--
-- WHERE
--
-- homes.lua says which map, which terrain and which levels, per species.
-- Nothing is derived, guessed or hashed: a species with no declared home is
-- reported and left alone rather than dropped somewhere plausible.  For the
-- version exclusives those homes are the ones the other cartridge uses; for
-- the gift, trade and event species -- which live nowhere in any version --
-- they are chosen, and homes.lua records the reasoning next to each.

-- Guest chance as a share of the map's own encounter rate.
local CHANCES = {
  { "RARE", 0.10 },
  { "UNCOMMON", 0.25 },
  { "COMMON", 0.50 },
}
local DEFAULT_CHANCE = 0.25

-- Never placed unless asked for: a legendary in the grass is a different mod.
-- Names, not encounter facts, so this stays true across versions.
local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  HOOH = true, CELEBI = true,
}

local function loadDataFile(mod, name)
  local source = mod:read(name)
  if not source then
    mod.log:error("%s missing from %s -- reinstall the mod", name, mod.path)
    return nil
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. name)
  if not chunk then
    mod.log:error("%s did not compile: %s", name, tostring(compileErr))
    return nil
  end
  local ok, value = pcall(chunk)
  if not ok or type(value) ~= "table" then
    mod.log:error("%s did not return a table: %s", name, tostring(value))
    return nil
  end
  return value
end

-- every sub-table of an encounter def that actually rolls
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
  local chances = {}
  for _, row in ipairs(CHANCES) do chances[#chances + 1] = row end
  mod.options:define({
    { key = "chance", label = "HOW OFTEN", type = "choice",
      default = DEFAULT_CHANCE, choices = chances },
    -- the player asked for everything to be findable in the grass, including
    -- what a gift, a trade or an event normally hands over; turning this off
    -- restores the narrower "only what no route offers" reading
    { key = "include_scripted", label = "ALSO GIFTS AND TRADES", type = "toggle",
      default = true },
    { key = "legendaries", label = "INCLUDE LEGENDARIES", type = "toggle",
      default = false },
  })

  local declared = loadDataFile(mod, "obtainable.lua")
  local homesFile = loadDataFile(mod, "homes.lua")
  if not (declared and homesFile) then return end

  -- Which generation's lists apply.  The loader does not hand a mod its
  -- generation, so this probes the merged species for a Johto starter.
  local isGen2 = mod.content.pokemon:get("CHIKORITA") ~= nil
  local key = isGen2 and "gen2" or "gen1"

  local scripted = {}
  for _, id in ipairs(declared[key] or {}) do scripted[id] = true end
  local homes = homesFile[key] or {}

  -- ------- what the running dataset already offers

  -- what the cartridge itself puts in the grass or the water
  local wild = {}
  for _, encDef in mod.content.encounters:each() do
    for _, entry in ipairs(terrainsOf(encDef)) do
      for _, slot in ipairs(entry.terrain.slots) do
        if slot.species then wild[slot.species] = true end
      end
    end
  end

  -- anything that evolves from something in `seeds` is obtainable too
  local function closure(seeds)
    local out = {}
    for id in pairs(seeds) do out[id] = true end
    local changed = true
    while changed do
      changed = false
      for id, def in mod.content.pokemon:each() do
        if out[id] then
          for _, evo in ipairs(def.evolutions or {}) do
            if evo.species and not out[evo.species] then
              out[evo.species] = true
              changed = true
            end
          end
        end
      end
    end
    return out
  end

  -- ------- the gap

  local includeScripted = mod.options:get("include_scripted") ~= false
  local withLegendaries = mod.options:get("legendaries") == true

  -- with gifts and trades included, only the wild counts as already-there
  local base = {}
  for id in pairs(wild) do base[id] = true end
  if not includeScripted then
    for id in pairs(scripted) do base[id] = true end
  end
  local reachable = closure(base)

  local missing, toPlace = {}, {}
  for id in mod.content.pokemon:each() do
    if not reachable[id] and (withLegendaries or not LEGENDARY[id]) then
      missing[#missing + 1] = id
      if homes[id] then toPlace[id] = true end
    end
  end
  table.sort(missing)

  -- placing a base form covers its whole line, so an evolution with no home
  -- of its own is not homeless -- it is one level-up away from a wild one
  local covered = closure((function()
    local seeds = {}
    for id in pairs(base) do seeds[id] = true end
    for id in pairs(toPlace) do seeds[id] = true end
    return seeds
  end)())

  local homeless = {}
  for _, id in ipairs(missing) do
    if not covered[id] then homeless[#homeless + 1] = id end
  end

  -- ------- index the homes by map and terrain, so a step is a lookup

  local guests, placed, report = {}, {}, {}
  for id in pairs(toPlace) do
    for _, spot in ipairs(homes[id]) do
      local mapId = spot.map or spot[1]
      local terrain = spot.terrain or spot[2] or "grass"
      local slot = { species = id,
                     min = spot.min or spot[3] or 5,
                     max = spot.max or spot[4] or spot.min or spot[3] or 5 }
      guests[mapId] = guests[mapId] or {}
      guests[mapId][terrain] = guests[mapId][terrain] or {}
      local bucket = guests[mapId][terrain]
      bucket[#bucket + 1] = slot

      -- a home on a map that never rolls is a home nobody can visit; say so
      -- at load rather than leaving the player to wonder for twenty hours
      local encDef = mod.content.encounters:get(mapId)
      local table_ = encDef and (encDef[terrain] or encDef.grass)
      if not (table_ and (tonumber(table_.rate) or 0) > 0
              and #(table_.slots or {}) > 0) then
        mod.log:warn("%s is homed in %s (%s), which has no wild encounters "
          .. "in this version -- it will never turn up there",
          id, mapId, terrain)
      end

      local mapDef = mod.content.maps and mod.content.maps:get(mapId)
      report[#report + 1] = {
        species = id, map = mapId,
        place = (mapDef and (mapDef.label or mapDef.name)) or mapId,
        terrain = terrain, min = slot.min, max = slot.max,
        normally = scripted[id] and "gift, trade or event" or "another version",
      }
    end
    placed[#placed + 1] = id
  end
  table.sort(placed)

  -- ------- the step

  local function share()
    local stored = tonumber(mod.options:get("chance"))
    if not stored then return DEFAULT_CHANCE end
    return math.max(0.01, math.min(1, stored))
  end

  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    -- vanilla first, and vanilla always wins: nothing it offers is taken away
    local enc = next(encDef, ctx)
    if enc then return enc end

    local byTerrain = ctx and ctx.mapId and guests[ctx.mapId]
    local bucket = byTerrain and byTerrain[ctx.terrain or "grass"]
    if not (bucket and #bucket > 0) then return nil end

    -- The step was empty.  A guest appears at a share of this map's own
    -- encounter rate, so a quiet cave stays quiet.  For water the engine
    -- passes the water table under `grass` (OverworldState:rollEncounter),
    -- which is why the rate is read from the def rather than by terrain name.
    local table_ = encDef and (encDef.grass or encDef.water)
    local rate = (table_ and tonumber(table_.rate)) or 0
    if rate <= 0 then return nil end

    local rng = (ctx and ctx.rng) or (love and love.math and love.math.random)
      or math.random
    if rng() >= (rate / 256) * share() then return nil end

    local pick = bucket[math.floor(rng() * #bucket) + 1] or bucket[1]
    local level = pick.min
    if pick.max > pick.min then
      level = pick.min + math.floor(rng() * (pick.max - pick.min + 1))
      if level > pick.max then level = pick.max end
    end
    return { species = pick.species, level = level }
  end)

  -- ------- say what happened

  if #placed == 0 then
    if #missing > 0 then
      mod.log:warn("%d species are missing from this version and none has a "
        .. "declared home yet: %s", #missing, table.concat(missing, ", "))
    else
      mod.log:info("every species is already obtainable; nothing to add")
    end
    return
  end

  mod.log:info("%d species now appear in the wild:", #placed)
  for _, row in ipairs(report) do
    mod.log:info("  %s -- %s (%s), levels %d-%d, normally %s",
      row.species, row.place, row.terrain, row.min, row.max, row.normally)
  end
  if #homeless > 0 then
    mod.log:warn("%d missing species have no declared home and were left "
      .. "alone: %s", #homeless, table.concat(homeless, ", "))
  end

  -- A packaged build shows no log, so the same table goes into the
  -- playthrough's storage.  Storage is scoped to a save and cannot be written
  -- at load time, so it hangs off the first save event, whichever arrives.
  local written = false
  local function writeReport(payload)
    if written then return end
    local game = (payload and payload.game) or mod.game
    if not game then return end
    if mod.storage:write(game, "report", {
      generated_for = key,
      placements = report,
      no_home_yet = homeless,
    }) then
      written = true
      mod.log:info("wrote the placement report to this playthrough's storage")
    end
  end
  mod.events:on("save.loaded", writeReport)
  mod.events:on("save.created", writeReport)
  mod.events:on("map.entered", writeReport)
end
