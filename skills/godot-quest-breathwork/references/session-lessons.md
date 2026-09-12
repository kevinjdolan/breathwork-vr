# Practical review and release lessons

## Review from the viewer's position

Inspect the approach to each phase boundary, not just the most attractive midpoint. Ask:

- Can I identify what is approaching me, what is leaving, and where each flow begins and ends?
- Does the source seem to give something to the breath, then recover, without jumping in size or brightness?
- Do the final incoming particles slow/fade naturally, or rush, vanish early, or hit my face as bright discs?
- Does a hold feel quiet? Does an optional empty rest remain different from an inhale?
- Are shapes genuinely three-dimensional, with near/mid/far elements and overhead coverage while reclining?
- Do visual clusters have a life cycle and spatially matched sounds, or sit like decorative dots?
- Is variation gradual and irregular rather than an obvious repeating beat? Does a high-contrast scene remain gentle without flashing?
- Are source sounds masked by the music, overly hissy, or too transient? Have several quiet cues combined into an unexpectedly busy mix?

Use the user's positive feedback as a regression contract. Preserve accepted exhale samples with hashes if editing only the inhale. Keep feedback tied to observed renders/audio; do not claim that imagining an experience is equivalent to wearing the headset.

## Audio production

Lyria can produce effective atmospheric textures but may return a rushing noise bed, rhythmic droplets, or an unwanted musical instrument even when the prompt asks for water. Validate the audible result rather than the prompt or filename. Preserve rejected masters and distinguish an atmospheric water-and-pad texture from literal field-recorded water.

For generated catalogs, author IDs, prompts, destinations and duration requirements first. Stage deliveries and retain original audio, non-secret interaction metadata and hashes outside runtime resource globs. Read keys from the environment. Resume from validated artifacts instead of repeating successful paid generations.

Master spatial sources in mono so the engine provides positional cues. Use rounded attacks and releases, inspect true peaks as well as sample peaks, and examine the aggregate mix. Match loop boundaries with a real overlap/crossfade; exact sample count alone is not a seamless loop. Probe model duration rather than assuming the requested duration was returned. Retain original masters if gently stretching a slightly short texture.

In Godot WAV import settings, `edit/loop_mode=2` imports Forward looping; the runtime enum `AudioStreamWAV.LOOP_FORWARD` is `1`. The importer's numeric setting and runtime enum are different. Check normalization/compression/trim flags, reimport changed assets, and verify the actual loaded stream lengths and loop modes.

## Reliable captures and tests

On macOS, an occluded Godot window may throttle drawing. Waiting for `frame_post_draw` while queuing captures can produce stale or repeated images with newer metadata. For a deterministic desktop review, explicitly call `RenderingServer.force_draw(false, 0.0)` before reading the viewport. Check successive images actually differ. Frame filenames may differ by one due to floating-point timing; select captures using recorded timestamps.

Godot may return exit code zero after script or shader compilation failures. A verification wrapper should also fail on `SCRIPT ERROR`, `SHADER ERROR`, and relevant engine `ERROR` lines. Headless runs do not validate a real Mobile GPU shader path; render on the real renderer as well.

Useful behavior checks include phase boundaries, silent hold samples, continuous lead-in visibility, last-cycle handling, gaze lag/catch-up, translated and rotated headset targets, invalid-joint loss/reacquisition, source-to-cluster position correspondence, and fade/end transport. Avoid brittle tests that only compare source strings to the implementation.

## Quest packaging

Keep SDKs, private keystores, credentials, APKs, large QA captures, and generation masters out of public Git history. Publish source and runtime assets with their required third-party notices.

Use the engine's matching Android template and toolchain. The Godot Android Gradle directory points to the parent of its generated `build` directory. Do not pass `--xr-mode off` when exporting the XR APK, even though it is appropriate for desktop/headless checks.

Verify the APK signature, package version, hand-tracking manifest and launcher alias. Launch the exported alias if the underlying Godot activity is not exported. Select one physical Quest explicitly; never let a connected emulator be selected accidentally. USB file access and USB debugging authorization are different.

An ADB-daemon warning after a successful export does not itself prove the APK failed. Check the artifact and reconnect ADB. Conversely, installation success does not prove XR startup: inspect app logs and any controller-required launch dialog. Record real device frame timing separately from synthetic desktop FPS, including warmup and peak scene load.
