---
name: godot-quest-breathwork
description: Build and refine calming native Godot/OpenXR breathwork experiences for Meta Quest, including particle presence, reclining views, spatial audio, and headset deployment. Use for immersive meditation work where breath timing and sensory comfort matter.
---

# Godot Quest breathwork

Treat calmness as an observable design requirement: slow coherent movement, gradual transitions, clear breath direction, and spatial depth without moving the viewer. Preserve the user's chosen aesthetic and approved elements. A request to improve inhalation should not silently remaster a satisfactory exhalation.

## Presence and breathing

- **MUST:** All current and future experiences derive inhale destinations and exhale origins from the universal neck breath center in `scripts/breath_geometry.gd`. Experience-specific offsets are relative to that center in headset space. Use the companion `breath-visualization-patterns` skill when editing breath paths.

- Derive phase from audible transport. Model inhale, full hold, exhale, and empty rest explicitly; zero-duration phases should work. Keep visual timing data-driven when supporting multiple rhythms. At the end, complete the final full cycle and settle instead of previewing an extra inhale.
- Incoming particles should visibly travel from the source toward a shared neck breath center throughout the inhale. Avoid increasing their speed to meet a phase deadline. A gentle pre-cue reveal and a long, smooth terminal taper can avoid sudden onset/cutoff. Keep points visible near the shared endpoint while fading before they cross the eyes.
- Use headset-relative up/right for paths and world-space breath-center positions. Separate outgoing color, paths, lifetime, and visibility so outgoing remnants do not obscure the next inhale. Preserve accepted timing and PCM samples when only the other phase is changing.
- Make the focal object respond continuously across phase boundaries. A hard impulse that moves a subset of halo particles can look like an unexpected change of object. Small shape changes, gradual contraction/recovery, and bounded smooth noise are often more legible than an abrupt glow pulse.
- Gaze-following objects should lag gently with a dead zone. Keep the camera stationary. Test looking up and reclining; overhead elements need real depth, not only a horizon composition.
- Spatial clusters should gather, drift, unravel, and relocate only while invisible. Keep internal density coherent. Occasional close visits should preserve a near-face exclusion region. Distinct quiet sounds should follow the corresponding world-space object.

## Native XR and mobile rendering

- Read the actual engine-version APIs. `XRHandTracker` joint transforms are absolute tracking-space poses: scale their translation by world scale, apply the XR reference frame, then the origin transform once. Validate joint flags and finite positions. Keep the last valid pose only during a brief dissolve; never render invalid joints at the origin.
- Upload tracked poses at render frequency rather than a reduced physics tick rate. Optical hand gestures may emulate controller buttons; avoid turning an ordinary held pinch into an accidental session exit.
- Godot 4.6 converts OpenXR joints to humanoid axes before exposing `XRHandTracker` poses: palm **+Z** faces out of the palm. Do not apply raw OpenXR palm-axis assumptions. Gesture integration tests should exercise converted joint bases, both hands, reclining, brief tracking gaps, and stationary hands during head motion. Bound reacquisition jumps and measure a sweep in its starting head frame.
- Enable hand tracking in both the OpenXR project settings and vendor export options. Verify the resulting manifest instead of assuming the editor toggle is sufficient.
- Prefer finite meshes, MultiMeshes, or GPU particles over expensive full-screen volumetric effects on standalone Quest. Establish point/triangle/overdraw budgets per experience, including the shared effects.
- Persistent particles should initialize once and use uniform visibility. `amount_ratio` alone cannot reliably reveal dormant particles with long lifetimes. Keep simulation time continuous across phase transitions.
- Pass particle built-ins as arguments into shader helper functions. Use explicit Godot types for uniform arrays; pass `Projection(Transform3D)` for `mat4` uniforms when appropriate.
- Opaque water must write depth if transparent breath particles pass in front of it. Accidentally assigning water `ALPHA` can move it into the transparent pass and hide near-face particles.
- Check both world-scale and screen-space point size. Dense additive clouds can become solid white shapes. Explicit per-eye view/projection billboarding can make particle sizing easier to verify when matrix overrides behave unexpectedly.

## Audio and verification

Read [session-lessons.md](references/session-lessons.md) for the practical review rubric, audio pipeline and deployment traps before a substantial refinement or headset release.

Validate the changed behavior with actual renders, audio measurements, and device evidence. A desktop screenshot proves appearance in that viewport; it does not prove stereo comfort. A fixed-timestep review's logged FPS does not prove headset performance. Report those distinctions plainly.
