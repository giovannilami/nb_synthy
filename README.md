# nb_synthy

[Synthy](https://github.com/schollz/synthy) by **Zack Scholl / infinitedigits**, adapted as a [Nota Bene (n.b.)](https://github.com/sixolet/nb) voice for **monome norns**.

Use Synthy's sound from an n.b.-compatible sequencer without running the original Synthy script. This is an independent adaptation, not an official release by Synthy's author.

**Version 0.1.2 — beta.** Version 0.1.1 has been reported working on norns. Version 0.1.2 only refines two encoder increments and has passed local Lua checks.

## Sound

- Two saw oscillators per note with stereo movement.
- A pulse sub-oscillator one octave down, following the lowest held note.
- ADSR envelope, autonomous or manual filter, flanger and reverb.
- Synthy's six-joint motion calculations drive the original squishy detuning and tremolo, without drawing the character.
- Eight held notes, with oldest-note stealing; up to sixteen live note synths including release tails.

The sound and motion calculations derive from Zack's original work. The adaptation supplies the n.b. player interface, headless control, voice lifecycle management and deferred audio loading.

## Requirements

- A norns installation with mod support.
- A script that supports n.b. for normal use; the included test script can also play the voice directly.
- The original Synthy script does not need to be installed. The host script supplies its n.b. library.

The original `SawDPW` and `MoogLadder` classes are used when available. If either class is unavailable, the backend uses the corresponding stock `Saw` or `MoogFF` alternative and logs `compatibility sound`. **The fallback changes the timbre.**

## Installation

Run this command in maiden:

```lua
;install https://github.com/giovannilami/nb_synthy
```

1. Open **SYSTEM > MODS**, select **nb_synthy**, and turn E3 to enable it (`+`).
2. Choose **SYSTEM > RESTART**.
3. Load an n.b.-compatible script and select **synthy** as its voice.
4. Open the **synthy** parameter group to adjust the sound.

Alternatively, download the repository ZIP, extract it, rename the extracted folder to **nb_synthy**, and copy it into `/home/we/dust/code/` using SFTP or the shared `code` folder. Then enable the mod and restart as above.

Check that the layout is:

```text
code/nb_synthy/
  lib/mod.lua
  lib/NB_Synthy.sc
  lib/synthy.scd
  nb_synthy_test.lua
```

Do not nest a second `nb_synthy` folder inside the first one. Keep only one copy of this mod inside `dust`: renamed backups there can still expose duplicate SuperCollider classes. Keep backups outside `dust`.

## First notes

Load **nb_synthy / nb_synthy_test** from the script menu:

| Control | Action |
| --- | --- |
| Hold K2 | Play a four-note chord; releasing K2 releases the notes |
| K3 | Stop all notes; reverb tails may remain |
| E2 | Set the root of the next chord |
| E3 | Set velocity |

The default attack is **1 second** and release is **5 seconds**. Hold a chord long enough to hear it. For short sequencer notes, try an attack of **0.01–0.05 seconds**.

## Parameters

| Parameter | What it does |
| --- | --- |
| level | Voice output level |
| sub | Lowest-note sub-oscillator level |
| attack / decay / sustain / release | Note envelope |
| pitch slew | Smooth pitch changes on a held note, including pitch bend; it does not glide between newly triggered notes |
| filter cutoff | Filter frequency, 20 Hz–20 kHz |
| filter mode | `autonomous` for Synthy's filter movement; `manual` for a fixed cutoff |
| filter hold | Manual takeover time after a cutoff change in autonomous mode, before the gradual return to autonomous movement; E3 increment: 0.1 s |
| filter slew | Smooth filter changes; E3 increment: 0.01 s |
| flanger / reverb | Effect amounts |
| squishy detuning / squishy tremolo | Depth of the motion-driven modulations |
| all notes off | Stop notes and cancel scheduled note-offs |

## Differences from the original Synthy

The character display, chord-progression sequencer and standalone controller handling are omitted. The host script supplies notes and interaction. Motion continues at 15 Hz using elapsed time; its phases begin when the voice is activated, so this is not a sample-identical replay of the original script.

The mod does not set `engine.name` or replace the host's screen, encoder, MIDI or `osc.event` handlers. Audio definitions are loaded when the voice is activated. A small SuperCollider loader catches backend-loading errors; it does not guarantee protection against every possible system or audio failure.

## n.b. behavior and limits

- Supports `note_on`, `note_off`, `play_note`, `stop_all`, `pitch_bend`, `set_slew` and `modulate`, plus activation, cleanup and parameter registration.
- `modulate(0…1)` controls filter cutoff across 20 Hz–20 kHz. Repeating a value renews manual takeover in autonomous mode.
- Fractional note values are supported. Full n.b. note identifiers are retained, with pitch derived modulo 128.
- Multiple selectors using `synthy` share one instrument, its parameters, polyphony and lowest-note sub. They are not separate timbral instances.
- Retriggering the same note identifier replaces that note. Independent overlapping notes at the same pitch need distinct n.b. identifiers from the host.
- Sustain-pedal behavior must be handled by the host through note-off timing.
- CPU usage and coexistence with other engines/mods need further hardware testing.

## Testing and bug reports

Local validation includes 12 Lua integration checks using upstream n.b. and norns parameter code, SuperCollider 3.13.0 compilation, and offline stereo rendering with both original and stock UGens. Hardware, scheduling and transport are simulated in the Lua tests; offline audio tests do not establish realtime performance on norns.

See [TESTING.md](TESTING.md) for the validation scope and [CHANGELOG.md](CHANGELOG.md) for version history.

For a bug report, include the norns model/software version, host script and mod version, steps to reproduce, other enabled mods, and relevant maiden/SuperCollider errors. Remove unrelated personal information from logs.

**Voice missing:** check the folder name, mod enablement and restart. The host needs an n.b. voice selector, not just a normal engine selector.

**Voice selected but silent:** try the test script with a long held chord and check maiden for `[nb_synthy]` messages or errors mentioning `NB_SynthyLoader`, `nb_synthy_osc` or `nb_synthy_fx`.

**Audio system fail:** an early 0.1.0 build was reported to cause this on startup; the exact cause was not established. The loader was reworked in 0.1.1, subsequently reported working in Shoal. If it recurs, save the full relevant SuperCollider error, remove `nb_synthy` from `dust/code` and restart. Disabling the mod alone may not exclude its `.sc` files from class compilation.

To uninstall, disable the mod, remove its folder and restart.

## Credits, provenance and license

- **Original synthesizer and motion model:** Zack Scholl / infinitedigits, [schollz/synthy](https://github.com/schollz/synthy). Derived from commit [`43b92d4`](https://github.com/schollz/synthy/tree/43b92d4d64ddf141b618bbbff0f476c37d74234f).
- **Nota Bene:** [sixolet/nb](https://github.com/sixolet/nb).
- **n.b. adaptation:** maintained here by [Giovanni Lami](https://github.com/giovannilami).

Distributed under the [MIT license](LICENSE). The original copyright notice and license are preserved. This repository is independently maintained and does not imply endorsement by the original author.
