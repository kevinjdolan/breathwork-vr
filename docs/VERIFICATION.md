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
