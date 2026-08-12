# Trade Evolutions By Level

Pokemon that can *only* evolve by trading evolve at level 36 instead, so a
solo playthrough can finish those lines without a second player.

On Red/Blue/Yellow that is KADABRA -> ALAKAZAM, MACHOKE -> MACHAMP,
GRAVELER -> GOLEM and HAUNTER -> GENGAR. On Gold/Silver it also covers
ONIX -> STEELIX, SCYTHER -> SCIZOR, SEADRA -> KINGDRA and
PORYGON -> PORYGON2, whose held-item requirement (Metal Coat, Dragon Scale,
Up-Grade) is dropped along with the cable — the level is the whole
requirement now.

A species that already has another way to evolve is left exactly as it was.
POLIWHIRL still needs its Water Stone for POLIWRATH and SLOWPOKE still
reaches SLOWBRO at level 37; only their trade routes stay trade routes,
because adding a second level-up row there would quietly steal the vanilla
evolution.

## Try it

```sh
python3 tools/modkit.py validate mods/trade_evolutions_by_level
luajit mods/trade_evolutions_by_level/tests/trade_evolutions_by_level_test.lua
love .        # the mod is on by default once it is in mods/
```

Catch a HAUNTER (or trade-evolve line of your choice), level it to 36, and
it evolves at the end of that battle like any other level evolution — Rare
Candy works too.

## Options

Both are read when the mod loads, so a change takes effect on the next boot.

| option | default | meaning |
|---|---|---|
| `EVOLVE AT` | 36 | the level the converted evolutions fire at (2–100) |
| `TRADING STILL EVOLVES` | on | keep the original trade route alongside the new level one; turn it off to make the cable stop evolving these lines |

The two routes never collide: a level row can only fire on a level-up and a
trade row can only fire on a trade.

## Good to know

**It fires on a level-up, not on reaching the level.** Gen 1 only offers an
evolution to a mon that gained a level in the battle that just ended
(`EvolveAfterBattle`), so a HAUNTER you caught at level 40 waits until it
levels to 41 — or until a Rare Candy does it. That is how every level
evolution behaves in the original, not something this mod adds.

**The sweep runs once per battle, not once per level.** If a Pokemon crosses
36 *inside* a battle and keeps going — routine with an exp multiplier — you
see "grew to level 36!", "37!", "38!" one after another and it evolves when
the battle ends, as a 38. It looks like 36 and 37 were ignored; they were
not. The threshold decided *that* it evolves, and the battle decided *when*
the game got a chance to say so. Vanilla does the same with a BULBASAUR that
crosses 16 mid-fight.

**A B press during the animation stops it**, exactly as it does for any other
level evolution, and prints "Huh? ... stopped evolving!". The next offer then
waits for the next level-up. A real trade evolution cannot be refused; this
one can, because it is now a level evolution.

**On Gold an Everstone still stops it**, and using an evolution stone on a
converted species does not trip the new level row either: both gates are
the engine's own and the rewritten rows go through them unchanged.

**Link play sees the change.** `evolutions` is part of the link fingerprint
(both generations), so a peer running this mod does not match a vanilla
peer — the same as any other mod that touches species data.

## How it works

`main.lua` walks the merged species view and rewrites the evolution list of
every species whose rows are *all* trade rows. Red's `TRADE` rows become
`LEVEL`, Gold's `EVOLVE_TRADE` become `EVOLVE_LEVEL`, and the target species
(`species` on Red, `into` on Gold) rides along untouched. It is data only —
no hook is wrapped and no engine module is required — so the new rows flow
through the ordinary after-battle evolution check, the Rare Candy path and
the evolution movie.

Because the walk is over the merged view rather than a hard-coded list, a
species added by another mod that evolves only by trade is converted too.

## Layout

- `manifest.json` — identity, version range, load order
- `main.lua` — the entry chunk; receives the `mod` object
- `tests/` — headless loader suite asserting the rewrite (excluded from `pack`)
