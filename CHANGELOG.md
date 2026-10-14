# Changelog

## 0.1.2 — 2026-10-14

- Refine E3 increments for filter hold to 0.1 seconds and filter slew to 0.01 seconds.
- Preserve parameter ranges, defaults and the 0.1.1 audio backend.

## 0.1.1 — 2026-10-14

- Move the audio backend to a deferred `.scd` file with a small SuperCollider loader and error handling.
- Resolve optional oscillator/filter classes at activation, with stock UGen fallbacks.
- Validate compilation and offline audio locally, with and without the original plugin classes.
- Subsequently reported working on norns inside Shoal.

## 0.1.0 — early test build

- Initial n.b. adaptation.
- Reported to cause `audio system fail` at startup on a tester's norns. The specific cause was not established. Superseded; do not install this build.
