# Party EXP Share

Every Pokemon in your party gains experience from a battle, not just the ones
that fought — the modern EXP. SHARE, without the item and without a bag slot.

Works on Red/Blue/Yellow and on Gold.

## Options

| option | default | meaning |
|---|---|---|
| `BENCH GETS` | FULL | what a Pokemon that did not fight receives, as a share of a fighter's: FULL, HALF or QUARTER |
| `EXP MESSAGES` | FIGHTERS ONLY | announce every Pokemon's gain, or only the ones that fought |

Both are read **at the moment of the award**, so a new choice applies to the
very next battle — no restart.

## What it does

`battle.exp_award` is the seam the engine raises after a battle, on both
games, and it exists for precisely this. The engine's own comment at that
call site:

> the participant/EXP.ALL split, factored out so a mod can replace it
> wholesale (e.g. a flat undivided share to every non-fainted party mon)
> without re-deriving participants/alive

So this **replaces** the vanilla split rather than wrapping it — calling
through as well would pay the fighters twice.

The fighters keep their exact vanilla share: the payout still divides by the
number of participants, still carries the traded and trainer boosts. The mod
only adds the rest of the party, and `BENCH GETS` decides their cut.

Everything that follows a payout is still the engine's: the gain box, the
level-up fanfare, the stat window, the moves due at that level, and the
after-battle evolution sweep. A benched Pokemon that levels up will learn its
move and evolve exactly as one that fought.

## Good to know

**It supersedes Red's EXP.ALL.** Holding the item changes nothing while this
is on — the split it modifies is the one being replaced. You can sell it.

**Fainted Pokemon are skipped**, which is the one rule vanilla's own EXP.ALL
pass keeps.

**Level-ups always announce**, even on `FIGHTERS ONLY`. That setting only
silences the "gained N EXP. Points!" box, and it exists because six party
members mean six of those boxes after every battle. When someone levels, you
will hear about it.

**It pairs with `exp_multiplier`**: that one scales each share, this one
decides who gets one. Together they keep a whole team level instead of
racing one Pokemon ahead of it — which is the usual problem with a
multiplier on its own.
