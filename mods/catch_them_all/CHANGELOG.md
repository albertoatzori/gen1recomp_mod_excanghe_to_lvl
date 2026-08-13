# Changelog

All notable changes to this mod are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
