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
| `AREAS EACH` | 2 AREAS | how many encounter slots one species is given, across the world |
| `INCLUDE LEGENDARIES` | off | let Mewtwo, Mew, the birds and the Gen 2 legendaries be placed too |

These shape the merged encounter tables, so unlike this repo's other mods they
take effect **on the next boot**, not immediately.

## How it decides what is missing

Two of the three ways a Pokémon reaches your party are data, and the mod reads
them:

- **the wild**, from the encounter tables — one entry per map, each with
  grass/water sub-tables of `{species, level}` slots;
- **evolution**, from each species' own evolution rows — anything that evolves
  from something reachable is itself reachable, however long the chain.

The third is a **script**, and that is the problem: `give_pokemon`,
`static_battle` and `trade` are calls *inside map script functions*
(`src/script/Commands.lua`), not rows in a table. Lua cannot look inside a
compiled function body, so no amount of cleverness at load time will find
them.

## How it adds them

A slot's **position** in the list is its probability — `src/world/Encounter.lua`
walks the buckets and takes `slots[i]` — and the mod-facing schema lets a table
carry only `rate` and `slots`; `buckets` is engine-side. So the list cannot
simply grow: an eleventh slot in a ten-bucket table would never be rolled. A
species therefore **takes** a slot rather than being appended.

Which slot is the whole point. Wild tables repeat species across their slots
and across maps, so the mod counts every occurrence in the dataset first and
**will only ever overwrite a slot whose species still has another one left**.
A mod that exists to make Pokémon obtainable must not make one unobtainable on
the way. If no slot can be spared, it takes none and says so.

The rarest slots go first, so the encounters an area is known for stay put. The
newcomer inherits the level of the slot it took, so nothing turns up forty
levels above its neighbours. Placement is a stable hash of the species id, so
the same dataset always produces the same world — which is what makes a
surprise reportable rather than a shrug.

## Seeing what it did

The placement is derived from your own encounter tables, so only your game
knows the answer. The mod therefore reports it two ways:

- **In the log**, one line per placement:
  `VULPIX -- Route 4 (grass), level 8, in place of ZUBAT`. Visible if you
  launch from a terminal.
- **In a file**, for everyone else. On the first save event of a playthrough
  the mod writes the whole table into its own storage, under
  `mod_storage/<version>/<playthrough>/catch_them_all/report.lua` inside the
  game's save folder:
  - Windows `%APPDATA%\LOVE\pokemon-love2d\`
  - macOS `~/Library/Application Support/LOVE/pokemon-love2d/`
  - Linux `~/.local/share/love/pokemon-love2d/`

  Each row carries `species`, `place`, `terrain`, `level` and `instead_of`.

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
