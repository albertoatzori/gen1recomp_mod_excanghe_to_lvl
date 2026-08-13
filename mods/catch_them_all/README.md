# Catch Them All

Species your version simply never offers get a home in the wild, so a Pokédex
can be finished without a second cartridge and a link cable.

Works on Red/Blue/Yellow and on Gold.

> **Gen 1 is ready; Gold is not yet.** The one list that cannot be computed is
> filled for Red/Blue/Yellow, read out of the ported map scripts. The Gen 2
> list is still empty, so on Gold the mod adds nothing and says so in the log.
> See [The declared list](#the-declared-list).

## Options

| option | default | meaning |
|---|---|---|
| `HOW OFTEN` | UNCOMMON | how likely a newcomer is, as a share of the map's own encounter rate: RARE (10%), UNCOMMON (25%), COMMON (50%) |
| `ALSO GIFTS AND TRADES` | on | place the starters, fossils, Dojo pair, trade-only four, Porygon, Eevee and Lapras in the grass too |
| `INCLUDE LEGENDARIES` | off | let Mewtwo, Mew, the birds and the Gen 2 legendaries be placed |

All three are read **at the moment of the step**, so a change applies
immediately.

## Nothing is replaced

The engine rolls first, and whatever it offers is returned untouched. The mod
only answers the steps that came back **empty** — `encounter.roll` may force
an encounter ("returns nil to suppress, a table without calling next to
force"), so a newcomer fills the silence between vanilla encounters instead of
taking someone's slot.

That matters because a slot's **position** is its probability —
`src/world/Encounter.lua` walks the buckets and takes `slots[i]` — and the
mod-facing schema exposes only `rate` and `slots`. The list cannot grow: an
eleventh slot in a ten-bucket table would never be rolled. Rewriting a table
always costs somebody their place, so this mod does not rewrite tables at all.

The price is the honest one: you meet *something* slightly more often. Every
vanilla species keeps 100% of its own encounters.

The guest chance is a share of each map's own rate, not a flat number, so a
cave that rolls rarely stays rare and a route that rolls often gets
proportionally more.

## Seeing what it did

The placement is derived from your own encounter tables, so only your game
knows the answer. The mod therefore reports it two ways:

- **In the log**, one line per placement:
  `LAPRAS -- Seafoam Islands B4F (water), levels 30-38, normally a gift`.
  Visible if you launch from a terminal.
- **In a file**, for everyone else. On the first save event of a playthrough
  the mod writes the whole table into its own storage, under
  `mod_storage/<version>/<playthrough>/catch_them_all/report.lua` inside the
  game's save folder:
  - Windows `%APPDATA%\LOVE\pokemon-love2d\`
  - macOS `~/Library/Application Support/LOVE/pokemon-love2d/`
  - Linux `~/.local/share/love/pokemon-love2d/`

  Each row carries `species`, `place`, `terrain`, `min`, `max` and
  `normally` (whether the species is a version exclusive or something a gift,
  trade or event normally hands over).

## Where they go

`homes.lua` says which map, which terrain and which levels, per species, and
it holds two different kinds of claim:

**Version exclusives** — species Yellow drops but another Gen 1 cartridge puts
in the grass. Their homes are *facts*, copied from that cartridge's own
encounter tables, so they turn up on the same route, in the same terrain, at
the same levels a player of that version would meet them.

**Nowhere-wild species** — the starters, the fossils, the Dojo pair, the
trade-only four, Porygon, Eevee, Lapras. No cartridge puts these in any grass,
so there is no fact to copy and the home is a *design choice*, with its
reasoning recorded beside it. Disagreeing with one is disagreeing with a
judgement, not finding a bug — edit the row.

Nothing is hashed or invented: a missing species with no declared home is
reported at load and left alone. A home naming a map with no wild encounters
is reported too, rather than silently never happening.

## The declared list

`obtainable.lua` names the species you can get **without** meeting them in the
wild. For Gen 1 it holds 35 of them, and none was recalled: they were read out
of `data/scripts/`, the map scripts this engine ports by hand rather than
extracting from a cartridge —

- `give_pokemon` rows and direct `Commands.give_pokemon` calls — the starters,
  Pikachu, Eevee, Lapras, the Mt. Moon Magikarp;
- `static_battle` rows — Snorlax, the three birds, Mewtwo;
- the in-game trades, whose event flags name both sides
  (`EVENT_TRADED_SPEAROW_FOR_FARFETCHD`);
- the Game Corner prize tables, the Fighting Dojo balls, the fossil revivals.

Every id was then checked against the 151 the version manifest lists. **Vulpix
is in there** because it is a Game Corner prize — precisely the sort of thing
memory gets wrong, and the reason this list was extracted instead of written
from knowledge.

The list is a union across versions, which is the safe shape: a species that is
wild in *your* version is already found through the encounter tables, so
listing it here can only make the mod more conservative, never wrong in the
dangerous direction. Ids absent from the running dataset are ignored.

**Gold's list is still empty**, so the mod fails closed there — it adds nothing
and logs why. Gen 2's gifts and statics live in its own ported scripts and can
be extracted the same way.
