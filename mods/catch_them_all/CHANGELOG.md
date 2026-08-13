# Changelog

All notable changes to this mod are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-08-12

### Changed

- **Nothing is replaced any more.** The mod no longer rewrites encounter
  tables. `encounter.roll` may force an encounter, so the engine rolls
  first and the mod only answers the steps that came back empty. Every
  vanilla species keeps every one of its encounters; the newcomers fill the
  silence between them. The only thing that rises is how often you meet
  anything at all.
- Homes are declared in `homes.lua`, not derived from a hash. A species with
  no home is reported and left alone rather than dropped somewhere plausible.
- `HOW OFTEN` replaces `AREAS EACH`: the guest chance is a share of each
  map's own encounter rate, so a quiet cave stays quiet.
- Options are read at the moment of the step, so they apply immediately.

### Added

- `ALSO GIFTS AND TRADES` (on by default): the starters, fossils, Dojo pair,
  trade-only four, Porygon, Eevee and Lapras are placed in the grass too, so
  everything can be found by walking. Turning it off restores the narrower
  "only what no route offers" reading.
- Homes for the fifteen species no Gen 1 cartridge puts in any grass, each
  with its reasoning recorded next to it.
- A load-time warning when a home names a map with no wild encounters.

## [0.3.0] - 2026-08-12

### Added

- A placement report. The mod now records every placement it makes -- which
  species, in which area and terrain, at what level, in place of which
  Pokemon -- logs it line by line, and writes it into the playthrough's mod
  storage under `report` on the first save event. Nothing could read that
  table out of the merged data afterwards, and a packaged build shows no
  log, so there was no way to see what the mod had done.

## [0.2.0] - 2026-08-12

### Added

- The Gen 1 declared list, 35 species, extracted from the ported map scripts
  in `data/scripts/`: `give_pokemon` rows and direct calls, `static_battle`
  rows, the in-game trades (their event flags name both sides), the Game
  Corner prize tables, the Fighting Dojo balls and the fossil revivals, each
  checked against the version manifest's 151 species. The mod therefore works
  on Red, Blue and Yellow.

### Known

- Gold's list is still empty, so the mod fails closed on Gen 2.

## [0.1.0] - 2026-08-12

### Added

- The whole mechanism: the encounter-table scan, the evolution closure, the
  occurrence census, habitat routing, deterministic placement, and the rule
  that a slot may only be taken while its occupant has another one left.
- `AREAS EACH` and `INCLUDE LEGENDARIES` options.

### Known

- `obtainable.lua` ships empty, so the mod adds nothing yet and logs why.
  Gifts, static battles and in-game trades live in map script functions and
  cannot be discovered at load; that file is where they are declared. Every
  other part is built and tested.
