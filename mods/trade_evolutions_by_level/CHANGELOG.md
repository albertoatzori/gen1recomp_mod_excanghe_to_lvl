# Changelog

All notable changes to this mod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions
match `manifest.version`.

## [1.0.0] - 2026-08-12

### Added

- Species that can only evolve by trading now also evolve at level 36:
  KADABRA, MACHOKE, GRAVELER and HAUNTER on Red/Blue/Yellow, plus ONIX,
  SCYTHER, SEADRA and PORYGON on Gold/Silver.
- `EVOLVE AT` option (2-100, default 36).
- `TRADING STILL EVOLVES` option (default on) to keep or drop the original
  cable route.

## [1.0.1] - 2026-08-12

### Fixed

- `EVOLVE AT` is now read when the game checks for an evolution instead of
  once at boot, so the settings screen and the running game can no longer
  hold different levels. Changing it applies to the next level-up, with no
  restart.
