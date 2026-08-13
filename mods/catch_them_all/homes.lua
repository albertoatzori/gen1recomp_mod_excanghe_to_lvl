-- Where a species that this version never puts in the grass should turn up.
--
--   SPECIES = { { map = "MAP_ID", terrain = "grass"|"water", min = N, max = N } }
--
-- Two kinds of entry live here, and they are NOT the same sort of claim.
--
-- 1. VERSION EXCLUSIVES -- species Yellow drops but another Gen 1 cartridge
--    puts in the grass.  Their homes are FACTS, copied from that cartridge's
--    own encounter tables, so they turn up on the same route, in the same
--    terrain, at the same levels as a player of that version would meet them.
--    These are added by reading an imported Red (or Blue) dataset; anything
--    still absent from this file is waiting for that read, and the mod
--    reports it as homeless rather than inventing a spot.
--
-- 2. NOWHERE-WILD SPECIES -- the starters, the fossils, the Dojo pair, the
--    trade-only four, Porygon, Eevee, Lapras.  No cartridge ever puts these
--    in any grass, so there is no fact to copy and the home is a DESIGN
--    CHOICE.  Each one below carries its reason: type, habitat, and where the
--    game already tells that species' story.  Disagreeing with one of these
--    is disagreeing with a judgement, not spotting a bug -- edit the row.
--
-- Map ids are the engine's own (the 249 in the version manifest), and levels
-- follow the area's progression so a newcomer never arrives forty levels
-- above its neighbours.  A home on a map with no encounter table is reported
-- at load rather than silently never happening.

return {
  gen1 = {
    -- ---- the starters: each to the habitat its line belongs to

    -- a seed Pokemon in the wood every Kanto journey starts by crossing
    BULBASAUR = { { map = "VIRIDIAN_FOREST", terrain = "grass", min = 5, max = 8 } },
    -- Kanto's one burning place, and already home to its other fire types
    CHARMANDER = { { map = "POKEMON_MANSION_1F", terrain = "grass", min = 28, max = 34 } },
    -- the sea route where the water types thin out enough for a small turtle
    SQUIRTLE = { { map = "ROUTE_21", terrain = "water", min = 20, max = 26 } },

    -- ---- the fossils: the rock they were dug out of

    -- Mt. Moon B2F is where the Helix and Dome Fossils are found; the pair
    -- goes back where the game says they slept
    OMANYTE = { { map = "MT_MOON_B2F", terrain = "grass", min = 12, max = 16 } },
    KABUTO = { { map = "MT_MOON_B2F", terrain = "grass", min = 12, max = 16 } },
    -- the Old Amber's owner: rock and flying, in the last cave before the League
    AERODACTYL = { { map = "VICTORY_ROAD_3F", terrain = "grass", min = 30, max = 36 } },

    -- ---- the Fighting Dojo pair: where Kanto's fighters already train

    HITMONLEE = { { map = "VICTORY_ROAD_1F", terrain = "grass", min = 28, max = 33 } },
    HITMONCHAN = { { map = "VICTORY_ROAD_1F", terrain = "grass", min = 28, max = 33 } },

    -- ---- the Game Corner's rarest prize, and the gifts

    -- a man-made Pokemon among the man-made machines
    PORYGON = { { map = "POWER_PLANT", terrain = "grass", min = 22, max = 28 } },
    -- the gift waits on a Celadon rooftop, so the wild one waits outside it
    EEVEE = { { map = "ROUTE_7", terrain = "grass", min = 15, max = 20 } },
    -- the Silph gift is a sea Pokemon; Seafoam is the sea it would live in
    LAPRAS = { { map = "SEAFOAM_ISLANDS_B4F", terrain = "water", min = 30, max = 38 } },

    -- ---- the trade-only four, which no version puts in any grass

    -- ice, in the ice cave
    JYNX = { { map = "SEAFOAM_ISLANDS_B2F", terrain = "grass", min = 25, max = 32 } },
    -- a barrier psychic, on the road that runs to the psychic city
    MR_MIME = { { map = "ROUTE_8", terrain = "grass", min = 18, max = 24 } },
    -- long grass and slow going, on the routes below Lavender
    LICKITUNG = { { map = "ROUTE_12", terrain = "grass", min = 20, max = 26 } },
    -- a wild duck, in the tall grass it hides in
    FARFETCHD = { { map = "ROUTE_13", terrain = "grass", min = 20, max = 26 } },

    -- ---- version exclusives go here, copied from an imported Red or Blue
  },

  -- Gold's own gifts, statics and exclusives, when its lists are read
  gen2 = {},
}
