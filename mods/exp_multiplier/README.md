# EXP Multiplier

Every experience payout is multiplied by a factor you pick: **2x, 3x, 5x,
10x, 30x, 50x or 100x**, plus **OFF (1x)** to park the mod without
uninstalling it. Default is 2x.

Works on Red/Blue/Yellow and on Gold/Silver — one hook serves both.

## Try it

```sh
python3 tools/modkit.py validate mods/exp_multiplier
luajit mods/exp_multiplier/tests/exp_multiplier_test.lua
love .        # the mod is on by default once it is in mods/
```

Pick the factor in the mod manager under **EXP MULTIPLIER**. The change
applies to the **very next battle** — no restart, no reload. The manager
writes the choice straight into the live loader, and the mod reads it each
time exp is paid rather than once at startup.

## What exactly gets multiplied

The share a single Pokemon is about to receive, *after* everything vanilla
already did to it:

- the split between participants
- the traded-mon x1.5
- the trainer-battle x1.5
- on Gold: the EXP.SHARE tax and the LUCKY EGG bonus

So a shared trainer kill is scaled *after* being divided and boosted, not
instead of it — the mod changes your pace, never the rules that decide who
gets what.

**Stat experience is not multiplied.** It rides a separate path from the
defeated species' base stats; scaling it would rewrite the stat spread of
every Pokemon you raise, which is a different mod from this one.

## Good to know

**Big factors mean big jumps.** At 100x a low-level Pokemon can cross a
dozen levels from a single battle. Every level is processed properly — stats
recalculate, moves are offered one at a time, evolutions trigger — it is
simply a lot of text boxes at once.

**There is a ceiling, and only the huge factors can reach it.** Red stores
exp in a three-byte field and, unlike Gold, never clamps it, so a total past
16,777,215 would silently wrap when the save is exported as a `.sav`. The
mod trims a payout to whatever room is left instead of letting that happen.
Vanilla cannot grind that far; 100x can.

**Link play still works.** The manifest declares `affects_link: false`, and
that claim holds: a cable battle awards no experience at all (`Cable rules:
no experience, no money, no items`), so this mod cannot change what a link
battle does. It also edits no species, move or item record, so the link
fingerprint is untouched.

## How it works

`main.lua` wraps the `exp.gain` hook, which `src/battle/Experience.lua`
raises on Red and `src/battle/gen2/Battle.lua` raises on Gold with the same
context keys. The wrap calls the vanilla calculation, multiplies its result,
and clamps it. That is the whole mod: no data record is patched, no engine
module is required, and with the mod off the engine runs its own numbers
untouched.

## Layout

- `manifest.json` — identity, version range, load order
- `main.lua` — the entry chunk; receives the `mod` object
- `tests/` — headless loader suite measuring real payouts (excluded from `pack`)
