# Validation

## Hardware status

Version 0.1.1 was reported working on norns inside Shoal by the maintainer. This is an initial user test, not a comprehensive compatibility or performance benchmark. Version 0.1.2 changes only two encoder increments; that change has passed local checks but has not yet been confirmed on hardware.

## Local checks

- 12 Lua 5.3 integration checks using actual upstream n.b. and norns parameter implementations, with hardware, OSC transport and clock mocked. Passed again for 0.1.2.
- Direct checks of increment/decrement and endpoint clamping for filter hold and filter slew in 0.1.2.
- SuperCollider 3.13.0 class compilation and SynthDef construction, with and without optional plugin classes.
- Stereo offline audio rendering at 48 kHz using both the stock and original UGens: nonzero audio, finite samples, no server errors, silence after freeing the audio group.
- Eight backend controller checks with a recording transport and simulated server: pending notes, bend, sub reassignment, motion, release-tail limits, resource cleanup, preservation of host groups and cancellation of pending startup.
- Injected syntax errors and exceptions in the deferred backend: class-library startup completed, the loader caught the failures, and an unrelated SynthDef could still compile.

The SuperCollider checks were performed on macOS Apple Silicon for 0.1.1. Its audio files are unchanged in 0.1.2. The controller/fault-injection harnesses and rendered audio were development checks and are not included in this repository.

These checks do not establish realtime CPU load, all host-script combinations, or reliability on every norns software/hardware configuration. The initial 0.1.0 startup failure was not reproduced exactly and its root cause remains unknown.

## Included tests

From this repository's root, with Lua 5.3 and local source checkouts:

```sh
lua tests/player_test.lua /path/to/norns /path/to/nb
```

For SuperCollider, include this repository's `lib` directory in your sclang class-library configuration, then run `tests/sc_smoke.scd`. It checks backend loading, SynthDef construction, pre-initialization note handling and repeated cleanup. It exits with a nonzero status on failure. This is a developer test, not a script to launch from the norns menu.

Optionally set `NB_SYNTHY_TEST_OUT` to an existing output directory to write an offline OSC score (`smoke.osc`) for rendering with `scsynth -N`.

## Reference revisions

- Synthy: `43b92d4d64ddf141b618bbbff0f476c37d74234f`
- n.b.: `400e0b3889d44b0f4f989e27e9a34f1ae732e376`
- norns: `6302a0d4dcb85ab3b701a4d7268863092b693caf`
