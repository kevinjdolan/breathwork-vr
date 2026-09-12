# Prismatic Sanctuary

An eight-minute sanctuary of high-contrast chromatic geometry, inspired by the intricate geometry associated with psychedelic art. The viewer remains still in a dark, spacious cathedral of cyan, copper, and violet. It is a calm visual aesthetic; there are no flashes, rapid kaleidoscope cuts, simulated intoxication, or forced travel.

## Breath and sound

The catalog should select a 4-second inhale, 4-second full pause, 4-second exhale, and 4-second empty pause: thirty complete box-breath cycles in 480 seconds. The layer reads continuous `breath_fill` from the shared clock, contracts its rosettes by 6.5% as the central orb gives away its breath, and opens on the exhale. Both pauses remain visually alive through slow, irregular unfolding. No phase-change trigger switches particle topology or color.

Music direction: quiet electroacoustic crystal harmonics, spacious bowed glass, very soft low synthesizer warmth, suspended consonant chords, tiny rounded mallet resonances with long tails, no melodic urgency. Eight-minute unhurried arc from sparse to gently luminous and back. No voices, drums, harsh attacks, white-noise hiss, startling stereo jumps, or prominent high treble. Each four-second box phase should feel spacious, not mechanically counted. A separate subtle glass resonance may originate at a nearby lantern; do not pan the entire music bed with the user's gaze.

## Visual structure

Seven large, folded rosettes occupy real positions around and above the viewer. Each has three depth-separated planes and a seeded nine-to-twelve-lobed silhouette. Eighteen small faceted icosahedral lanterns create a near/middle layer at approximately 3.0–6.6 meters. Their open face panels alternate saturated cyan, copper, and violet; triangular windows reveal a smaller, recessed inner crystal. Face panels deform and twist gently with breath. Two deliberately placed front lanterns flank the central breathing corridor. Rosettes also have folded colored kite panels, giving their linework a dimensional supporting surface. A 2,800-point diamond dust field reaches farther into the room. The zenith has its own rosette and several nearby lanterns, so reclining retains a complete composition.

Lanterns drift about 16 centimeters in all directions on independent, slow frequencies. Geometric rotation is small and slow, with no accumulating frame-rate error. Breath deformation uses smoothstep. The particle field is persistent and continuously moving; it does not restart at breath boundaries. The shared central particle orb, mouth-directed inhale, separated exhale, and tracked particle hands remain the user's embodied focal points.

## Review and refinements

The first actual Mobile Vulkan render looked too thin and distant: rosettes alone did not establish sufficient presence. The second pass added the near, solid-depth lanterns with inner triangles and individualized rosette shapes. Independent parent review still found the composition too much like thin line art; the third pass replaced dark lantern faces with luminous, open chromatic panels and recessed interiors, enlarged their apparent size, introduced folded rosette facets, and added continuous breath elongation/twist. The resulting seated view has large peripheral geometry and an uncluttered central breathing corridor; the reclined view has a full overhead arrangement rather than an empty sky.

The review harness renders an expanded exhale state, contracted full-hold state, an 80-degree reclined view, and a gaze turned directly toward a near lantern. Its viewport capture explicitly forces a draw, avoiding stale macOS occluded-window captures. The final render log has no GDScript or shader errors. These are desktop Vulkan views, not a claim of headset comfort or standalone Quest frame-rate verification. Thin distant lines still need headset inspection for aliasing and perceived brightness. Review again with the shared orb, audio, and full fade/timeline integration enabled; the standalone harness only validates this environmental layer.

## Integration

Recommended shared background color: `Color(0.0015, 0.0018, 0.007)`, a nearly black indigo. This layer also supplies an enclosing unlit indigo shell with a very faint, slowly changing chromatic atmosphere.

Instantiate `layer.gd` beneath an identity world node. Call `update_experience(state)` every rendered frame; it uses `elapsed`, `intensity`, and `breath_fill`. Other contract keys are accepted and left for the shared embodied effects. Hide the original water, auroras, ambient motes, and fractal field, and leave the shared central particle orb, breath paths, and tracked hands active. The layer contains no audio playback, session clock, locomotion, physics, external textures, or asset downloads.

Run the independent review with:

```sh
.tools/Godot.app/Contents/MacOS/Godot --xr-mode off --path . --always-on-top --fixed-fps 60 --script experiences/prismatic_sanctuary/review.gd
```

Images and logs go to `verification/prismatic_sanctuary/`. There are 2,800 GPU points, 25 small geometry instances, and one enclosing background mesh. No volumetric raymarching or runtime geometry rebuild occurs.
