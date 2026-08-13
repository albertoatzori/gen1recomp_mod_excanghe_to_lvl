-- Species you can obtain WITHOUT ever meeting them in the wild.
--
-- =====================================================================
-- THIS FILE IS THE ONE PIECE THAT CANNOT BE COMPUTED, AND IT SHIPS EMPTY.
-- Until it is filled, the mod refuses to add anything and says so in the
-- log.  That is deliberate: see "Why this file exists" below.
-- =====================================================================
--
-- Why this file exists
-- --------------------
-- The mod works out what is missing by reading the encounter tables, which
-- ARE data, and following the evolution chains, which are data too.  What it
-- cannot read is the third way a Pokemon reaches your party: a script.
-- Starters, fossils, the Game Corner prizes, Snorlax, the birds, Mewtwo, the
-- in-game trades -- every one of those is a `give_pokemon`, `static_battle`
-- or `trade` call inside a map script FUNCTION (src/script/Commands.lua),
-- not a row in a table.  Lua cannot look inside a compiled function body, so
-- no amount of cleverness at load time will find them.
--
-- Left to guess, the mod would decide that CHARMANDER, SNORLAX and MEWTWO
-- are missing from your game and drop all three into the first patch of
-- grass.  So instead it asks to be told, once.
--
-- How to fill it
-- --------------
-- Every id below is a species that is obtainable by script in ANY Gen 1
-- version (or any Gen 2 one, in the gen2 list).  A union across versions is
-- the right shape: a species that is wild in your version is already found
-- through the encounter tables, so listing it here can only ever make the
-- mod MORE conservative, never wrong in the dangerous direction.
--
-- The authoritative source is your own imported game: its encounter tables,
-- read together with the ported map scripts, say exactly which species
-- arrive by gift, by static battle or by trade.
--
-- Ids that do not exist in the running dataset are ignored, so an over-long
-- list is harmless.

return {
  -- Gen 1: Red, Blue, Yellow
  gen1 = {},

  -- Gen 2: Gold
  gen2 = {},
}
