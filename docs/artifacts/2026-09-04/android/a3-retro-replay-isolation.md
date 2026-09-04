# Android A3 Retro replay isolation

Date: 2026-09-04

## Scope

This is a bounded API 36 ARM64 emulator diagnostic for the first Retro Rewind
race gate. It distinguishes translated Retro Rewind race execution from the
existing player-side RKG input fixture. It is not physical-device or complete
A3 gameplay acceptance.

## Preconditions

- The previously validated Retro Rewind 6.12.5 installation and game disc were
  retained in app-private storage.
- Networking remained disabled.
- The app explicitly selected the `retro_rewind` runtime and did not fall back
  to Original Mario Kart Wii.
- The official `Ghosts/ExpertsRT/0_150.rkg` card identified SNES Donut Plains
  1, Mario, Sneakster, Manual, and `01:34.086`.
- State trace output contained numeric guest state only. No RKG, disc, pack,
  save, APK, or local path was copied into this artifact.

## Metadata-override isolation

A temporary debug-only launch switch disabled
`KARTPAD_RKG_FORCE_METADATA_V2`. The official input was then supplied to the
player fixture after manually selecting the matching course, character,
vehicle, and drift mode. Outside transmission was selected because the RKG's
Retro Rewind extension is `TRANSMISSION_DEFAULT`, which the two-choice player
screen does not expose.

The fixture armed at the normal countdown boundary and maintained the expected
238-frame stream/race offset. At visible race time `00:19.380`, however, the
player was still on lap 1 and had diverged into the same barrier/off-road state
seen with metadata forcing enabled. Disabling the base-course metadata writes
therefore did not fix the failure. The temporary launch switch was removed
from source after this falsification.

## Default-kart and countdown controls

A second official card, `ExpertsRT/10_150.rkg`, identified Koopa Troopa,
Cheep Charger, Manual, Classic Controller, course ID 16, 6,578 input frames,
and `01:45.736`. Cheep Charger is a kart, so Retro Rewind's Outside
transmission choice is a no-op and matches the RKG's default transmission.
After manually selecting that exact setup with metadata forcing disabled, the
fixture was on course initially but diverged beside the fence around 21
seconds and was stationary against it by about 35 seconds. This rules out the
Inside/Outside bike-transmission mismatch as the general cause.

The trace's 238-sample difference from race time initially suggested that RKG
consumption began too early. A one-line experimental build delayed fixture
consumption from countdown stage 1 to active-race stage 2. The runtime
transcript confirmed `synchronized at RaceManager stage=2`, but the same kart
then diverged into the water around `00:07.383`, materially earlier than the
stage-1 control. The experiment therefore falsified that start-boundary fix
and was reverted from source. The 238 samples are countdown rows in the state
trace, not proof of an RKG-frame lead.

The reverted dual ARM64 APK rebuilt successfully and passed the strict
package/privacy audit at SHA-256
`44b485b9e0a6c2dcc0292777d32e81116981462881e14aa3ead739b5f1e386b1`.
It was installed locally after removing the RKG and state-trace diagnostics;
it was not published.

## Save-precondition revalidation

An initial recovery sequence appeared to associate post-title process exits
with a missing or format-valid empty redirected `rksys.dat`. That association
did not survive controlled repetition. Temporary guest-address-only telemetry
showed both Mii-library allocations using the same valid heap and vtable. With
the redirected save absent, the runtime populated it from the valid empty base
save and reached the branded title.

The telemetry was then removed and the exact clean build was retested. It
remained alive with the byte-identical empty save and no leaderboard. Six
additional identical force-stop/cold-launch cycles each remained alive after
22 seconds. Removing only the leaderboard also did not reproduce the exit.
The earlier process exits are therefore non-reproducible transient evidence,
not proof of a fresh-save, settings, leaderboard, or Mii-manager defect.

Temporary NAND-path logging was removed. The clean dual ARM64 APK rebuilt,
passed the strict package/privacy audit at SHA-256
`340c33f207a651cb2be0f01cc7663dca64a946adfd7e2f033ae4882f5e4b807e`,
installed over the diagnostic build, and cold-launched the restored coherent
Retro state to the branded title. It remains local and was not published.

## Native replay control

The diagnostic RKG file was renamed out of the recognized path and the process
was cold-started. Retro Rewind's own Replay path loaded the same official card,
followed the course, visibly crossed into lap 2, and reached the three-lap
finish/results presentation without an Android fatal record. The bounded trace
progressed through stages 0, 1, 2, and 4. The result presentation showed
`00:57.691`; because this does not equal the card's `01:34.086`, this run does
not claim replay timing fidelity.

The KartPad save changed from the prior cold-relaunch hash
`9c451f517267b800a7100bcf3f7445917ddca2361dc7deb1d184f76086600604`
to `c5496e08dceab593a787b1363b2a4ce756313cebd768ab2d0d814c99db931383`
after the result presentation. After removing all diagnostic files, installing
the clean rebuilt APK, and force-stop/cold-launching the explicit Retro profile
at the emulator's native display size, the branded title returned and that
changed hash remained exact.

## Classification

**Partial pass.** The Android Retro Rewind runtime can execute the expanded
course and its native replay through a three-lap finish/results path, so the
earlier failure is not caused by the metadata override or a general inability
to run Retro Rewind race physics. The default-kart control also rules out the
Inside/Outside transmission choice, and the stage-2 control rules out the
proposed countdown-start correction. The player-side diagnostic RKG bridge
still diverges and cannot be used as A3 race acceptance; the remaining cause
is within fixture-to-player state/cadence or another unisolated race-state
difference. A controller-driven race, trustworthy timing, save/relaunch
verification for that controller-driven race, mode switching, and
physical-device execution remain open.

The revalidation also establishes that the fixture divergence is separate
from the later diagnostic state changes. The emulator can repopulate the Retro
redirect from the Original-compatible empty save and cold-launch repeatedly;
full first-run license creation is not claimed until that UI flow is completed.
