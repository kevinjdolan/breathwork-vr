# Visionary Temple — version 2.6

Eight minutes of slow forward travel through a painted tunnel that passes through four visionary passages: a lattice of staring eyes, a flame-and-feather mandala, nested kaleidoscope ring cells, and a painted temple hall with fluted columns, starry arches, a blue-green diamond floor and a rosette dome. The tracked camera never moves; the environment slides backward at 0.55 m/s after a five-second eased start. The journey axis anchors to the initial gaze and follows later gaze changes with the same cascaded 3.2-second filters as Prismatic Sanctuary, settling in about sixteen seconds. Unlike the Prismatic tunnel, the journey basis keeps the temple floor toward the ground while the gaze is less than about 80 degrees from horizontal, so a turned head does not roll the hall; a fully reclined start keeps the head axes so the hall rises above the viewer.

## Passages

| Seconds | Passage | Inspiration in the supplied clips | Tile mapping |
|---:|---|---|---|
| 0–120 | Eye lattice | A radial tunnel of nested eyes woven by golden sacred-geometry lines with ruby and sapphire nodes | 5 repeats around, 7.0 m per tile |
| 120–240 | Flame mandala | Orange licking flame petals, violet peacock-eye feathers, dotted mushrooms and small eyes turning slowly | 4 repeats, 8.0 m, slow clockwise turn |
| 240–360 | Kaleidoscope rings | Nested salmon/green/cyan ring cells in gold octagon frames over acid chevrons, turning the other way | 4 repeats, 8.8 m |
| 360–480 | Painted temple | Fluted orange columns, pointed starry arches, a blue-green diamond floor and an orange rosette dome with eyes | one repeat around, 6.0 m bays |

Each passage dissolves into the next over its final 24 seconds. The dissolve is ridge-guided: the next passage first appears along its raised ornament, so eyes become petals before the ground changes. The tunnel cross-section eases from a circle to a superelliptical hall with a flat floor during the temple passage. All ornament is original procedural art baked by `tools/bake_visionary_tiles.py` into four RGBA tiles whose alpha channel stores relief height; no reference frames are bundled. The vertex shader reads the height at a coarse mip level so eyes, petals, rings and columns are actual sculpted relief, and the fragment shader samples two anisotropic mipmapped tiles per pixel. Ornament rides a material coordinate that advances with the travel, so the painted surface moves as one body.

## Breath language

The rhythm is a long-release box: 4 s in, 4 s full hold, 6 s out, 2 s empty rest, thirty complete cycles. Each inhale selects a visible drifting sigil with a predicted six-second sightline; that sigil glows gold and two golden plasma arcs lead from it to the tracked nose, forming 1.5 s before the cue and tapering into the hold. The tunnel contracts 35% over the inhale and holds. During the full hold the walls brighten with a restrained 60 BPM heartbeat and the destination light's four rays grow over 500 ms. Sixteen violet-to-cyan petal paths leave the mouth over the exhale (front over 2.2 s) and clear by 14.3 s, before the next lead-in at 14.5 s. The white destination core stays visible in every phase; only its rays collapse at the exhale and stay absent through the rest.

Ninety-six drifting sigils use a four-sprite sheet (eye, flame lotus, ring cell, temple rosette). Each sigil's sprite is chosen from the passage that will be current when it reaches the viewer, so it never changes while visible, and sigils arriving after a passage boundary already carry the new motif. A vast faint sigil turns slowly around the destination light and crossfades with the passages. 3,072 additive sparks add parallax inside the walls. Three tinted haze veils and a far glow color follow the passage palette. The Aurora Lake breath streams, orb and blue outflow are hidden; particle hands remain.

## Budgets and integration

One connected 256×128 tube (65,536 triangles) replaces Prismatic's particle vault. Sigils, sparks, haze, destination light and mandala are single-quad MultiMeshes (about 7,000 triangles). The golden plasma and violet outflow tubes reuse the 96-segment hexagonal tube (about 41,000 triangles instanced). There is no volumetric raymarching and no per-frame mesh rebuild. The tunnel requests native 72 Hz on Quest like Prismatic Sanctuary. The layer exposes `focal_position()` and `reset_journey()`; the director hides the shared orb and outflow for both tunnel journeys.

## Score

`audio/generate_visionary_journey.py` renders one deterministic 480-second arrangement at 60 BPM: one beat is exactly 48,000 samples and sixteen beats are one breath cycle, so every chord change lands on an inhale. A tanpura-like D drone with wandering buzzing partials underlies the whole session. A soft sub heartbeat rests during the empty pause and softens through the hold. Sixteenth-note plucked arpeggios rise with the inhale, thin through the exhale and mostly fall silent in the rest. Slow detuned pads swell gently with each inhale; high glass shimmer blooms during each full hold. The four passages move from D Aeolian through a brighter Dorian color to a warm D major resolution in the temple, with the same 24-second crossfades as the visuals. A synthetic hall impulse response, a 34 Hz high-pass, 7 kHz low-pass, eight-second fades and two-pass loudness normalization to about −20 LUFS complete the master. No sampled or generated backing recording is used.

## Review notes

Desktop Mobile-renderer captures (software Vulkan) checked every passage, both dissolves, all four breath phases and 80-degree reclined views. Review found oversized ornament in the first pass; tile scales were reduced and vertex relief softened from 0.75 m to 0.42 m to remove jagged silhouettes on the largest eyes. The images establish composition and shader correctness only; they do not establish stereo comfort or sustained Quest frame rate. The temple passage is bright and saturated by design and the whole world is scaled to 86% of the baked palette; headset feedback should decide whether that is comfortable for eight minutes.
