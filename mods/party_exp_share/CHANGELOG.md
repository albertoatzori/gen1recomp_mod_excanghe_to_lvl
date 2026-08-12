# Changelog

All notable changes to this mod are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-12

### Added

- Every non-fainted party member gains experience after a battle, through the
  `battle.exp_award` seam on both Red and Gold. The fighters keep their exact
  vanilla share; `BENCH GETS` decides the rest of the party's cut.
- `EXP MESSAGES` keeps the gain boxes to the fighters, since six party members
  otherwise mean six boxes per battle. Level-ups always announce.
