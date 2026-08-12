# Changelog

All notable changes to this mod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions
match `manifest.version`.

## [1.0.0] - 2026-08-12

### Added

- `EXP MULTIPLIER` option: OFF (1x), 2x, 3x, 5x, 10x, 30x, 50x, 100x,
  defaulting to 2x. Changing it applies to the next battle, with no restart.
- Scales the payout on both Red/Blue/Yellow and Gold/Silver through the
  shared `exp.gain` hook.
- Payouts are trimmed to Red's three-byte exp field so a huge factor cannot
  wrap the total when the save is exported.
