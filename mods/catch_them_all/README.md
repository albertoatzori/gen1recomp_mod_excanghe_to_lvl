# Catch Them All

Species your version simply never offers get a home in the wild, so a Pokédex
can be finished without a second cartridge and a link cable.

Works on Red/Blue/Yellow and on Gold.

> **This mod ships inert.** One piece of what it needs cannot be computed, and
> until it is supplied the mod adds nothing and says so in the log. See
> [What is still missing](#what-is-still-missing).

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

## What is still missing

`obtainable.lua` is the list of species you can get **without** meeting them in
the wild: starters, fossils, the Game Corner prizes, the in-game trades,
Snorlax, the birds, Mewtwo. It ships **empty**.

Left to guess, the mod would conclude that Charmander, Snorlax and Mewtwo are
missing from your game and drop all three into the first patch of grass. So
instead it fails closed: with an empty list it adds nothing at all and logs why.

Filling it takes one imported game. The encounter tables, read together with
the ported map scripts, say exactly which species arrive by gift, by static
battle or by trade. The list is a union across versions — a species that is
wild in *your* version is already found through the encounter tables, so
listing it can only ever make the mod more conservative, never wrong in the
dangerous direction. Ids absent from the running dataset are ignored, so an
over-long list is harmless.

Everything else — the scan, the evolution closure, the census, the placement,
the safety rule — is built and tested. This is the last twenty lines.
