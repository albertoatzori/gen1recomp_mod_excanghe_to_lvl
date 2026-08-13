# Wild Encounter Rate

Thins the wild grass out. Half the encounters, a quarter, or none at all.

Works on Red/Blue/Yellow and on Gold.

## Options

| option | default | meaning |
|---|---|---|
| `WILD ENCOUNTERS` | HALF | NORMAL, HALF, QUARTER, or OFF |

Read **at the moment of the step**, so a new choice applies immediately — no
restart, no reload.

## What it does

`encounter.roll` is the seam the engine raises before it picks a wild
Pokemon, on both games. Its contract is: return `nil` to suppress the
encounter, return a table to force one, or call `next()` for the vanilla
pick. This mod only ever does the first or the last — it never decides
*which* Pokemon appears, so encounter tables, level ranges and rarity slots
are exactly as the cartridge has them.

The die is thrown *before* `next()`, so a suppressed step costs no vanilla
draw at all rather than rolling an encounter and throwing it away. It uses
the engine's own RNG rather than a private one, so a seeded run stays
reproducible.

## What it deliberately leaves alone

- **Fishing.** That comes through a different seam (`encounter.fishing`), so
  even `OFF` still lets you fish. A cave with no encounters is quiet; a game
  with no encounters at all is broken.
- **Scripted and static encounters** — the Ghost, Snorlax, the legendaries.
  Those are not wild rolls and never reach this hook.
- **Repel**, which filters *after* the roll and so behaves normally.

## Good to know

At `OFF` you can still walk into a trainer, and the grass still animates —
nothing about the map changes, you simply stop being interrupted.

Because a suppressed step skips the vanilla draw, a run with this mod on will
not reproduce the same encounter sequence as one without it, even from the
same seed. That is the cost of not rolling at all, and it is the right side
of the trade: rolling and discarding would burn the table just as fast.
