# Version 2.9 verification — counts, breath and beats on one clock

Authored and verified on macOS with Godot 4.6.3. Audio checks ran on Godot's headless dummy audio driver, which uses the same mixer as the Quest. Nothing was installed on the Quest 3, so headset listening, the device's audio output latency and comfort are unverified.

The full `tools/verify.sh` run passed: all eleven Godot suites and 14 Python contracts, in 454 s.

## Shared clock

**Cause.** The breath cue started each tick from the frame loop. `play()` takes effect at the next mix step. Godot's Android OpenSL driver mixes 1,024 frames at a time (about 21 ms) and reports no output latency, so each tick landed up to one mix buffer after its second, by a different amount each time. The score and the breath guide were also started, paused and resumed one call apart, without the audio server lock.

**Fix.** The ticks are now a looping track generated per breath pattern. `MeditationDirector` starts, pauses and resumes the score, the breath guide and the tick track inside `AudioServer.lock()`.

**`tests/test_breath_cue.gd`** (part of `verify.sh`) checks:
- **Tick tracks, four patterns:** each loops exactly one cycle. Every tick's attack sits at the same sample offset from its second as in the tick sample itself. The louder ticks (4:1) fall exactly on phase boundaries.
- **All nine worlds:**
  - The breath guide and the ticks stay within 3.5 ms of the score after starting from 0 s and from 97.25 s, and after four pause/resume cycles each. They measured 0.0 ms.
  - The tick track stops before the settle.
- **Negative control:** players started a frame apart without the lock measured −85 ms.

**`python tools/check_cue_alignment.py`** captured each world's score, breath guide and ticks from Godot's own mixer, on separate buses, for 24 s from 64 s into the session, through a 0.8 s pause. It then matched the tick sample, the delivered score and the breath loop inside the captures.

| World | Ticks | Tick spacing error | Score offset at each tick (matches) | Breath guide offset (matches) | Louder ticks on phase boundaries |
|---|---:|---:|---:|---:|---|
| Aurora Lake | 22 | 0.0 ms | 0.0 ms (20) | 0.04 ms (19) | yes |
| Prismatic Sanctuary | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (12) | yes |
| Fractal Garden | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (20) | yes |
| Tidal Origami | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (19) | yes |
| Cloud Atelier | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (19) | yes |
| Neural Constellation | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (20) | yes |
| Circuit Garden | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (20) | yes |
| Pilgrim Tides | 22 | 0.0 ms | 0.0 ms (20) | 0.0 ms (17) | yes |
| Visionary Temple | 23 | 0.0 ms | 0.0 ms (21) | 0.0 ms (14) | yes |

- **Sensitivity:** shifting the captured ticks by 5 ms was reported as 5.0 ms.
- **Stale import caught:** a first run matched no score audio for Aurora Lake. Godot was still playing its imported copy of the previous score, so the tool now reimports before capturing.
- **Capture fixes:** two early runs paused a few milliseconds after a tick and counted its resumed tail as a tick. The capture now pauses halfway through a second on the audio clock, and the analysis finds the pause from the recorded silence.
- **Consequence:** `python -m audio.beat_grid` puts every beat of every score on a whole second, and these captures put every tick and breath phase on a whole second of the score. Counts, breath phases and beats therefore line up in all nine worlds.

## Lyria scores

**Probes**
- **Lyria 3.5:** 60-second clips prompted for "exactly 60 BPM" held a steady beat grid. The Aurora clip measured 60.00 BPM with 3.3 ms beat residual. A 178-second take kept its beat phase at 105 ms in all eleven 16-second windows.
- **ElevenLabs Music v2.5:** held 60 BPM for two of three styles; the Tidal clip had no steady grid.
- **Lyria 3.5 limits:** asking for 4 minutes 10 seconds returned 178 s. A prompt containing a song title was blocked.

**Takes**
- Eighteen takes were generated, two per movement.
- Sixteen were steady: period error −32 to +58 ppm, beat wander 2.3–11.6 ms.
- Two were rejected: Tidal *deeper water* take 2 (+848 ppm, 177 ms wander) and Tidal *stillness* take 1 (12.2 ms wander).

**Joins**
- The first assembly (all three scores) had three joins that sagged 3–8 LU below the quieter side or rose about 7 LU in two seconds. Two outgoing movements ended softly as the next began softly. That assembly was replaced.
- The final assembly places joins where both takes are at full level. It rides the gain through each join by at most +5.0/−2.9 dB.

| Score | Takes used | Joins | Deepest dip / largest 2 s step (EBU R128 short-term, delivered file) | librosa tempo | Fold period | Beat peak (tick 35 ms) | Peak ratio | Tracked beats ≤ 50 ms | Beats with an onset (strong) |
|---|---|---|---|---:|---:|---:|---:|---:|---:|
| Aurora Lake | 2, 1, 1 (+24, +15, +6 ppm) | 152–168, 308–324 s | 0.4 / 1.8 LU | 60.09 | 1.0000 | 25 ms | 10.7 | 98% | 100% (93%) |
| Tidal Origami | 2, 1, 2 (+22, −21, −32 ppm) | 152–168, 308–324 s | 0.2 / 1.7 LU | 60.09 | 0.9997 | 25 ms | 7.9 | 100% | 100% (96%) |
| Pilgrim Tides | 2, 1, 1 (0, +18, −23 ppm) | 160–176, 308–324 s | 0.5 / 2.0 LU | 60.09 | 1.0001 | 25 ms | 8.3 | 98% | 90% (56%) |

**Checks**
- **Beat grid:** every 16-second window and all six windows around each score's joins keep the beat within 20 ms of the tick measurement. `tests/test_suite_audio.py` checks the provenance and measures every join of each delivery.
- **Automated audition:** Gemini 3.8 Flash reviewed the three deliveries.
  - Aurora Lake and Pilgrim Tides: an audible pulse, steady tempo, seamless joins, and no voices, drum kit, harsh attacks or startling changes.
  - Tidal Origami: seamless joins and a calm character, but it described fluid plucks rather than a distinct pulse on every beat. The onset measurement contradicts this: every beat carries an onset at the tick. Automated audition does not settle it; it needs a listen in the headset.

**Not verified:** listening in the headset, and the Quest's delay between the visible count and the heard tick.

## Previous release records

# Version 2.7 and 2.8 verification — sculpted Visionary Temple and tick-aligned scores

Authored and verified on macOS with Godot 4.6.3 (Mobile renderer on Metal/MoltenVK). A Quest 3 was connected, but these versions were not installed or measured on it: headset comfort, stereo depth and frame timing remain unverified. Everything below is desktop evidence.

The full `tools/verify.sh` run passed. It covered editor import, both session tiers, hands, natural audio end, the nine-world suite, the session menu, breath cue, palm wave, wave tracking, and the Prismatic and Visionary contracts. It also ran 13 Python contracts in 276 s, including tick alignment of all nine scores and the painting, relief, matcap and provenance hashes.

**Visionary Temple (2.7)**

- `tests/test_visionary.gd` checks these, and passes:
  - **Passages and dissolves:** eight one-minute passages, with 30-second dissolves over the final half of each minute. Neighbouring passages never turn the same way. At every swap the outgoing shell is fully open and the arriving shell is at rest.
  - **Shell clearance:** each arriving shell clears the dissolving one by more than 10 cm, using a CPU mirror of every cross-section.
  - **Tube:** 140,800 triangles per shell, with near and far conveyor rings joined by one static ring. Relief textures match their paintings.
  - **Relics:**
    - 25 modelled types and 384 relics, each mesh 48–1,168 triangles, solid with normals.
    - Six cross-section paths and three along-tunnel motions.
    - Every relic stays inside its breathing shell, clear of the central sightline, and invisible outside its drawing window.
    - At most 130 relics are drawn (measured worst case 105, about 78,000 triangles), and at most 63 are in view.
    - The relic shader's motion constants match `relics.gd`.
  - **Inhale source:** a visible relic with a six-second sightline in every sampled breath cycle.
- **Height maps:** Nano Banana Pro matched the four procedural passages' exact heights with zero-offset edge alignment (height correlation 0.61–0.94). gpt-image-2's answer was rejected: edge correlation 0.09.
- **Seam repair:** the worst wrap-edge ratios fell from 2.2–4.3 to 0.8–1.8.
- **Desktop review:** 18 renders (every passage, three dissolves at several depths, reclined views) plus a three-angle gallery of all 25 relic types. Review led to a thinner, fading dissolve rim (the white rim scribbled on thin cords), lower flame relief, feather cutouts, fuller lotus petals and per-relic culling (the first cut drew up to 255 relics).
- **Full preview:** `tools/render_previews.py --only visionary_temple --full` rendered 14,400 frames at 1440×900 and 30 FPS with the score and breath audio of the time. Mean audio −22.2 dB, peak −4.5 dB; stills at every passage were inspected. A 1280×800 HEVC copy (220 MB) was made for sharing. Both stay under `build/previews`. The preview predates the 2.8 scores.

**Scores (2.8)**

`python -m audio.beat_grid` measured every delivery with librosa. The reference is the breath tick sample on whole seconds, measured the same way: 35 ms.

| Score | librosa tempo | Fold period | Beat peak (ms) | Peak ratio | Tracked beats ≤ 50 ms | Prominent onsets on grid | Transitions checked |
|---|---:|---:|---:|---:|---:|---:|---:|
| Aurora Lake | 60.09 | 1.0000 | 25 | 7.1 | 95% | 86% | 3 |
| Prismatic Sanctuary | 60.09 | 0.9999 | 35 | 3.1 | 98% | 32% | 4 |
| Fractal Garden | 60.09 | 1.0000 | 25 | 10.2 | 100% | 100% | — |
| Tidal Origami | 60.09 | 1.0000 | 25 | 13.0 | 100% | 100% | 3 |
| Cloud Atelier | 60.09 | 1.0000 | 25 | 8.3 | 100% | 52% | — |
| Neural Constellation | 60.09 | 1.0000 | 25 | 14.7 | 100% | 98% | — |
| Circuit Garden | 60.09 | 1.0000 | 35 | 11.5 | 100% | 100% | — |
| Pilgrim Tides | 60.09 | 1.0000 | 35 | 9.5 | 99% | 87% | 3 |
| Visionary Temple | 60.09 | 1.0001 | 35 | 6.0 | 94% | 97% | 7 |

- **Grid:** every 16-second window with a clear beat, and 24 seconds around every movement change, dissolve and session join, keeps its strongest onset on the tick grid. The only exception is Visionary's geode-to-temple dissolve, whose strongest onset is the sixteenth after the tick.
- **On-grid share:** this is a diagnostic only. Prismatic and Cloud Atelier score lower because slowly beating pads and noise swells produce many weak detections. Their beat peaks and tracked beats are firmly on the ticks.
- **Analyzer lessons:**
  - A median across mel bands erased sine plucks.
  - A circular mean is cancelled by sixteenth-note arpeggios.
  - Harmonic-percussive separation removed the synthesized pulses.
  - The final analyzer avoids all three.
- **Lyria RealTime:** it ignored `bpm` in measurement.
  - A drum-led take requested at 60 BPM repeated every 0.824 s (72.8 BPM) even after `reset_context`.
  - A take requested at 90 BPM settled near 128 BPM.
  - A full-length take ended with service error 1011 at ten minutes of wall time, so each bed is two 264-second sessions, all six recorded completely.
- **Lyria pulses:** mastering chose the gentlest pulse level that locks: Aurora 0.22 (12.8 dB under the bed), Tidal 0.18 (18.1 dB) and Pilgrim 0.20 (9.4 dB). The pulse roots stay within each bed's measured scale (D major, A major, F major).
- **Levels:** no level jump at any movement change or session join. Pilgrim Tides has one 7.4 dB phrase entry at 379 s inside the bed, preceded by a 1.5-second quiet breath.
- **Not verified:** the scores and pulse balance have not been listened to in the headset.

## Previous release records

# Version 2.6 verification — Visionary Temple

This ninth world was authored and verified in a Linux container with Godot 4.6.3 (official Linux build), Xvfb and Mesa's software Vulkan driver (llvmpipe) using the Mobile rendering method. No Meta Quest, Android SDK or physical headset was available in this session, so there is no APK, no installation and no device frame-timing sample for this release. Everything below is desktop evidence.

- The full `tools/verify.sh` run passed: editor import, both Quest-tier session contracts, tracked hands, session completion, the nine-world suite (now including journey routing, hidden orb/outflow, the 72 Hz cadence and wordless focal light for both tunnel worlds), the paused-menu integration, palm wave, Prismatic contracts, the new Visionary contracts and 12 independent Python tests (220 seconds). Python compilation and `git diff --check` passed. This repository has no configured code formatter.
- `tests/test_visionary.gd` checks the eased 0.55 m/s travel, the 500 ms ray growth at the hold and collapse at the exhale with no rays through the two-second rest, a partition-of-unity passage schedule with 24-second dissolves ending exactly on each two-minute boundary and no dissolve after the temple, floor-down journey roll for turned heads and gaze-axis preservation when reclined, a 65,536-triangle connected 64 m tube, four baked tiles and the sigil sheet, sixteen-second gaze settling, a visible source sigil with a six-second sightline in every sampled cycle, sigils contained inside the contracting tunnel and clear of the central sightline, source locking through the cue, and tile routing in the third passage.
- Twenty-five software-Vulkan Mobile renders were inspected: ten layer-only captures (each passage seated and 80-degree reclined, plus one dissolve) and fifteen integrated session captures covering inhale, hold, exhale and rest, both dissolves and reclined views in every passage. The first pass showed oversized ornament and jagged relief on the largest eyes; tile scales and vertex displacement were reduced and re-rendered. The nine-card selector renders with the ninth card centered on its own row and the desktop pointer test passes. Shader and script logs were clean on the real renderer.
- The new score measures 480.000 s, stereo 48 kHz Vorbis, −20.0 LUFS integrated with a −5.6 dBTP true peak. Its onset autocorrelation peaks at exactly 1.0 s (60 BPM), and the averaged sixteen-second cycle envelope falls 6.6 dB through the empty rest relative to the exhale onset, confirming the breath-shaped arrangement. A first master had about 70% of its energy below 80 Hz; the drone and sub were reduced against the plucks, pads and shimmer and the score was regenerated (about 25% below 80 Hz afterwards). These are measurements, not a listening test in the headset.
- Provenance for the score is in `audio/visionary_journey_provenance.json` and the eight-track `audio/suite_provenance.json`; the lossless master stays local under `audio/masters/suite`. The breath guide `breath_visionary_temple.wav` is a sample-exact 16-second 4/4/6/2 loop with silent holds, generated by the existing suite synthesizer without touching the other guides.
- `tests/test_session.gd` now waits 0.3 s after freeing the scene before quitting; under this container's dummy audio driver the mixer otherwise sometimes still held the lake's water and mote streams at exit and the verifier's error scan failed a passing run.
- A one-minute preview of the new world was rendered with the existing preview pipeline through the software Vulkan renderer (`tools/render_previews.py --only visionary_temple`, which now honours `GODOT_BIN`): 1,800 frames at 1440×900 and 30 FPS with the runtime score and breath guide, mean −22.6 dB and peak −6.5 dB, recorded in `PREVIEW_MANIFEST.json` as the ninth entry. It looks from seated level toward an 80-degree upward view like the other eight previews. The eight earlier movies were not re-rendered.
- Not done in this release: an Android export, and any headset comfort or sustained-performance check. The painted walls are bright and saturated by design; whether that stays comfortable for eight minutes in stereo needs a worn-headset review.

## Previous release records

# Version 2.5 verification

The Prismatic wall is now 98,304 layered cloud grains plus 32,768 detached filaments. Forward and side GPU renders were inspected at 34, 112, 260 and 400 seconds. The final cloud uses a mipmapped cached grain sprite, retaining density while avoiding procedural per-fragment noise. The existing green/rainbow breath streams, star, music and other seven experiences remain intact.

The complete `tools/verify.sh` run passed, including all engine contracts and 10 independent Python tests (131.974 seconds). Prismatic contracts also passed on the real Mobile Vulkan renderer, including custom-data addresses for all three cloud strata. The dummy headless backend does not retain instance buffers, so only that readback assertion requires the real renderer. Python compilation and `git diff --check` passed.

The original 196,608-grain prototype measured only 54.6 FPS in its first ten-second Quest sample and was rejected. The optimized cloud preserves coverage with larger stippled kernels and half as many simulated grains. It requests native 72 Hz. A fresh physical Quest 3 run measured 53.1 FPS during initial loading (801.3 ms worst frame), then **72.6 FPS with a 14.3 ms worst frame** in the next five-second window. Device script/shader logs were clean, and a live stereo capture confirms the cloud tunnel. This is a brief warmed sample, not full-session, late-passage, or moving-head comfort validation. The headset was returned to the selector.

The installed, signature-verified package is **2.5.0 / code 13**. APK bytes: 147669796; SHA-256: `3d044ef6a642c2cc5f8b6610decc7f2bf4d97137cf98544172f2a5c07eb56aef`.

Eight final MP4 previews contain 1,800 frames each at 30 FPS, 1440×900, exactly 60 seconds, H.264 video and 48 kHz stereo AAC. Each uses the actual runtime score, breath guide and applicable spatial sounds. Audio mean/peak levels and complete-file hashes are recorded in [PREVIEW_MANIFEST.json](PREVIEW_MANIFEST.json). Frames at 5, 30 and 55 seconds were inspected across all eight clips to check motion, reclining coverage and legibility. The Prismatic preview was regenerated after optimization. All clips are wordless desktop recordings, not stereo headset video. Runtime music files were not modified for this release.

## Previous release records

# Version 2.4 verification

The full `tools/verify.sh` run passed: engine import, original Quest 2/3 contracts, tracked hands, session completion, all eight experience rhythms, menu integration, palm wave, Prismatic source locking/travel, and 10 independent Python audio/asset tests (97.445 seconds). The suite additionally verifies distinct theme routing, hidden legacy cues, absence of world instruction labels, reclined head axes and mouth targets, and a bounded integrated mesh count. Python compilation and `git diff --check` passed; this repository has no configured code formatter.

Twenty-four integrated Mobile Vulkan renders cover inhale, exhale, and an 80-degree reclining view. Additional Prismatic phase captures show both traveling flows, hold growth, and the persistent white core through exhale/empty pause. A second Mandelbrot passage at 250 seconds confirms visual variation. Real renderer logs contain no script or shader errors.

Four replaced scores were measured at 480 seconds, stereo 48 kHz, approximately −20 LUFS, and true peaks below −1 dBTP after encoding. Original Aurora outbreath hashes still match. Automated full-score audits raised no harsh-attack, voice, startling-transition or ominous-tension flags. These audits are not reliable instrument identification and do not replace listening in the headset.

Integrated static mesh totals (including shared scene geometry; GPU particle counts are separate):

| World | Triangles |
|---|---:|
| Fractal Garden | 210,252 |
| Tidal Origami | 137,500 |
| Cloud Atelier | 88,816 |
| Neural Constellation | 401,644 |
| Circuit Garden | 240,532 |
| Pilgrim Tides | 294,412 |

Every revised world adds 16,896 instanced focal/flow/ecology particles. Tidal Origami also uses 7,200 GPU droplets. These counts are budgets, not timing measurements.

The signature-verified ARM64 debug package is **2.4.0 / code 12**, package `com.kevin.breathworkvr`. Installation and cold launch on the physical Quest 3 succeeded. The package includes all four Mandelbrot fields and shared theme shaders/scripts.

APK bytes: 147660131; SHA-256: `6c29da4321f5795835222060b6b3e44df8fcc9cdbe7d43649449121b2ef53f9f`.

## Physical Quest 3 smoke checks

All seven updated experiences (2–8) were cold-launched and entered successfully with clean script/shader logs. A live stereo capture also verifies the Mandelbrot environment, its particle iris, and nearby recursive crystals on the device. The final app state is the eight-experience selector.

First ten-second process samples were 81.3, 82.3, 82.8, 84.1, 83.4, 82.3 and 82.6 FPS for experiences 2–8, respectively. Each included an initial 723–831 ms loading/compilation stall. Proximity sleep stopped the unworn headset after roughly twelve seconds, so these are startup smoke samples, **not sustained performance results**. Late screenshot attempts while asleep returned empty files and are not visual evidence. Full sessions, moving-head stereo comfort, and active hand tracking under peak load still require a worn-headset review.

## Previous release records

# v2.0 verification record

The eight-experience suite was reviewed with Godot 4.6.3 using the Mobile Vulkan renderer on the development Mac. This is desktop rendering evidence, not a measurement of stereoscopic comfort or sustained Quest frame rate.

## Completed checks

- Original Quest 2/Quest 3 session-budget contracts, tracked-hand transforms and loss handling, and natural audio ending.
- All eight catalog entries, exact score lengths, guide-loop lengths, phase classification, full/empty hold values, wrapped inhale pre-cue continuity, and complete final cycles.
- A return visit to Aurora Lake after the variants, confirming its sky is restored. Mutable Environment state is now duplicated per visit.
- Actual menu selection into Neural Constellation and a completed exit back to the selector. Desktop ray-hit selection and an 80-degree reclining menu anchor also pass.
- Twenty-four integrated GPU captures: inhale, exhale, and reclining for all eight worlds. Every new environment also received its independent subsession review and the refinements recorded in `EXPERIENCES.md` and its `DESIGN.md`.
- An 18-second continuous box-breathing render sampled into 72 frames. The full hold has no incoming/outgoing particles; the empty pause has no outgoing remnants and includes gentle pre-cue gathering near its end.
- Independent PCM checks for every new breathing loop: exact frame count, silent holds, silent seams, bounded peaks, and soft onset samples. The approved original outbreath sample hashes remain unchanged.
- Seven distinct 480-second, 48 kHz stereo Lyria deliveries, checked against provenance hashes and measured loudness. Targets are approximately −20 LUFS, with true peaks below −1 dBTP after delivery encoding.
- Full-score automated audio audits using Gemini 3.8 Flash detected no voices, rhythmic percussion, harsh attacks, startling transitions, or ominous tension. These are automated assessments, not a claim of personal headset listening.

## Generation record

Twenty-one untouched Lyria movements were retained locally: 80,598,317 bytes. The seven mastered runtime scores total 52,537,014 bytes. Six complete scores and twenty movements survived a failed final Circuit Garden request; resuming generated the missing movement without replacing validated work. The completed catalog has seven scores and zero unresolved generation failures.

## Android package

The signed debug APK is version **2.0.0**, version code **7**, package `com.kevin.breathworkvr`, ARM64, Android SDK 29 minimum / 36 target. Signature verification passes. Archive inspection confirms both scenes, the runtime catalog, all seven layer scripts, and all eight music imports; review scripts and test resources are excluded.

APK size: **167,884,843 bytes**. SHA-256: `71afe4bd6b26cd887a308503e8f2856c18c634eb165f458ff8dd120dccd678bb`.

The physical Quest was disconnected at the final package check. This build has therefore not yet been installed or performance-tested on the headset. The earlier approved Aurora Lake build was tested on the Quest, but that result is not a substitute for testing this expanded suite.

## v2.0.1 Quest startup correction

Installed version **2.0.1**, code **8**, on the physical Quest 3. The first v2.0.0 installation exposed nonexistent OpenXR convenience-method calls in the native-only menu/session paths. Both now use Godot 4.6.3's `get_session_state()` and its named state constants. A regression check exercises the real engine API even with XR disabled; the complete scene/selector integration harness passes.

The corrected APK signature verifies, installation and cold launch succeeded, and a headset stereo capture shows all eight menu cards. Fresh process logs contain no script/shader errors. This verifies startup and menu rendering; it does not establish full-session comfort or sustained performance across all eight worlds.

Current APK: 167,885,383 bytes; SHA-256 `63ad3808f92e50689695e7b5e88d641e47e0c1d42059706baa2c9f705e90735f`.

## v2.1.0 session return control

Added a world-anchored Menu gaze target with a separate Continue / End session confirmation. Tests exercise brief-glance rejection, dwell reset, audio pause, quiet breath particles, focus-loss recovery while paused, cancellation, reclining orientation, and a complete fade back to the selector. Existing session, hand, natural-end, and eight-world integration contracts pass. Three Mobile Vulkan captures cover the target, seated confirmation, and reclining confirmation with clean shader/script logs.

Version **2.1.0**, code **9**, was signed, installed, and cold-launched on the physical Quest 3. Fresh startup logs are clean. Automated interaction coverage is from the desktop engine harness; this is not a claim of a manually performed headset gaze-return trial. APK: 167,892,118 bytes; SHA-256 `26b309ffebf100b817852e64536c17b3f1b8a7944f7790a048310a709fcd1769`.


## Version 2.2.0 — geometric trance and palm-wave menu

- `tools/verify.sh`: both Quest-tier session checks, tracked hands, session completion, eight-world routing, paused-menu integration, palm-wave recognition, prismatic geometry, and ten Python asset/audio tests passed. After the later visual refinements, the focused prismatic and eight-world integration checks passed again. Python compilation and `git diff --check` passed; this repository has no separately configured lint/format tool.
- The sixteen mesh families have unique vertex sets and bounded extents; the instanced objects total 64,064 triangles. Sampled object poses remain wholly inside the tunnel at empty, half-full and full breath. Visible source candidates retain a six-second predicted sightline; source selection stays locked during the green cue.
- A 90-degree gaze change has a slow onset and settles within four degrees after sixteen seconds. The focal light stays 60 meters away and changes radius at the full-hold/exhale boundaries over 500 ms, reaching zero during exhalation.
- Mobile Vulkan desktop renders cover green plasma, contracted full hold, blue outflow, extinguished center, a reclined confirmation with gaze pointer, and the sixteen-second upward tunnel turn. Review caught and fixed sparse vault particles, an undersized light, transparent objects failing to occlude the vault, excessive near-face glow, and objects intersecting the constricted shell.
- New Prismatic music is exactly 480 seconds, stereo 48 kHz, approximately −20 LUFS, with an authored 32,000-sample beat grid (90 BPM). A complete automated audio audition reported electronic instrumentation, an even gentle rhythm, and no voices, harsh attacks, startling transitions or ominous tension. All other runtime audio files are unchanged.
- Gesture tests cover both lateral directions, one-shot activation, rearming after lowering the hand, back-facing palms, distant hands, static poses and tracking jumps. An actual XRHandTracker fixture opens the confirmation and pauses both audio clocks; gaze Continue resumes and End returns to the selector. Quest 2/3 use head-directed gaze, not eye tracking. Physical gesture usability and prolonged stereo comfort require headset feedback.
- Signed Android version 2.2.0 / code 10 installed successfully on the physical Quest 3, launched successfully, and rendered the stereo selector with the updated wave instructions. Fresh process logs showed no GDScript/shader errors. The selector's approximately 72 FPS is not a measurement of the full tunnel's sustained performance.

## Version 2.3.0 — ornamental relief and cohesive music

The tunnel now uses 32,768 instanced relief tiles (65,536 triangles) plus 8,192 detached light particles (16,384 triangles). Eight forward/side Mobile Vulkan captures at 34, 112, 260 and 400 seconds verify changing patterns, visible eye and gecko motifs, and real folded geometry. A six-second reclining capture covers continuous breath-responsive motion. All shader logs are clean after correction of an initial shader-include type error. The supplied references informed original procedural geometry and ornament; no reference images are bundled.

The previous Prismatic delivery combined Lyria backing recordings with an independently authored rhythm and plucked synth line. Headset feedback found the result jarring and piano-like. Version 2.3 removes the generated backing and plucked line, retaining a single 90 BPM arrangement of kick, bass, quiet shaker and sustained synth chords. Its eight-minute duration, stereo 48 kHz format, provenance hash, loudness and peak checks pass. The old source recordings remain retained locally. Automated audio descriptions were not treated as sufficient evidence of musical cohesion after the user's contrary listening report.

`tools/verify.sh` passed all engine checks and ten Python asset/audio tests. The focused suite additionally starts Prismatic playback and confirms its selected score and breath guide run while all lake/mote spatial audio remains stopped. Python compilation and `git diff --check` pass. The signed version 2.3.0 / code 11 APK installed and cold-launched successfully on the physical Quest 3. Initial process logs show no script/shader errors; full-experience headset timing and musical comfort still require an active headset session.
