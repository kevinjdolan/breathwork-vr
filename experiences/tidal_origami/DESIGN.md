# Tidal Origami — version 2.4

A particle lotus lifts and opens liquid petals during inhale, then drains inward on release. Fourteen rippling ribbons include twisted suspended loops and overhead crossings; six liquid lenses and 54 larger beads provide a second depth scale. 7,200 drifting droplets and curling droplet constellations surround the viewer. Existing positional water audio accompanies the aquatic score.

All focal paths use tracked head up/right/forward vectors and the tracked mouth target. The focal sculpture inherits the slow gaze-following position; it works upright or reclined. Each world adds 3,072 focal particles, 1,536 directed breath particles and 12,288 surrounding particles in 48 compact clusters. Clusters gather, drift, unravel and relocate only while invisible, with staggered 24–30-second lifecycles. Foreground particles shrink gently near the face. No instructional text appears inside the world.

The authored [6, 2, 8, 0] inhale/hold/exhale/rest pattern and exact 480-second duration remain unchanged. Near, middle and overhead desktop renders have been reviewed; these do not establish stereo comfort or sustained headset performance. The original Aurora Lake is unchanged.

## Earlier design record (superseded where different)

# Tidal Origami

An eight-minute breath meditation inside an impossible water sculpture: seven suspended, twisting streams fold into liquid arches around the viewer. Five occupy different distances and two cross the zenith. The shared breathing orb remains the near focal point, framed by quiet open space.

Breathing rhythm: six-second inhale, two-second comfortable full pause, eight-second exhale. Thirty complete sixteen-second cycles fit exactly eight minutes. The sheet arches rise and gather on the inhale, remain suspended during the pause, then gently settle and release their droplets on the exhale. Breath animation is driven continuously by the shared `breath_fill`; nothing spawns explosively at phase boundaries.

## Music prompt

Original tranquil ambient chamber-water music, no voices, no percussion, no dramatic build: bowed glass harmonics and rounded felt-piano droplets suspended in a deep warm bass bed, long shimmering tails, sparse irregular notes with generous silence, fluid rubato phrasing, restrained aquatic timbres, calm curiosity and floating stillness, softened attacks and releases, no high-frequency hiss, no splashing transients, no rhythmic arpeggiator. Evolve slowly across eight minutes, begin gently, deepen through the middle, resolve into a quiet long fade. Leave room for a gentle six-second inhale, two-second pause, eight-second exhale breathing cue.

Suitable positional accents: quiet resonant water droplets or low liquid chimes emitted infrequently at the three arch-depth rings, with staggered timing and long fades. Avoid constant wideband rushing water, which masks the breathing cue. Audio is supplied by the shared experience system; this layer does not allocate playback nodes.

## Integration

Load `res://experiences/tidal_origami/layer.gd`, instantiate as a world-identity `Node3D`, and call `update_experience(state)` every rendered frame after `_ready()`. Required state keys are `elapsed`, `intensity`, `breath_fill`, and `head_position`; the broader shared state dictionary is accepted. The shared Director owns session timing, breath streams, orb, hands, music, exit, and global fades. A dark blue/black background suits this layer; hide the old lake, aurora curtains, fractals, and ambient motes.

The layer builds its own seven finite procedural meshes, 2,800 GPU droplets, and three distant narrow basin rims. It has no dependency on resources outside its directory. Water deformation, caustic highlights, and droplet drift run in shaders. The meshes contain 16,800 triangles in total, plus the simple rim meshes. No screen texture, refraction, raymarching, reflection probes, shadows, physics updates, or per-frame mesh uploads are used. Opaque sheets deliberately retain correct depth ordering in stereo and do not rely on transparent sorting; the flowing highlights suggest translucency. Every dynamic object has a finite visibility bound covering its motion.

## Self-review and revision

The first GPU render felt too much like evenly striped fabric. Its parallel bands were visually repetitive and its reclining view left an empty central sky. The revised water uses warped cellular caustic paths, softer irregular highlights, tapered stream ends, and a darker palette. Two sheets now cross directly overhead so reclining viewers have near/mid spatial layers without needing to turn their neck.

Reviewed the full-inhale and released-exhale poses separately, then a 72-degree reclining view on Godot 4.6.3 Forward Mobile/Vulkan. Final images are `verification/tidal_origami/phase_89.png`, `phase_179.png`, and `phase_269.png`; the review harness and clean engine log are in the same directory. Shapes and droplet positions change continuously and retain negative space for the shared orb and incoming breath. No shader or script errors were reported.

What works: a substantially different water aesthetic from the original flat lake, clear crossing depth, overhead coverage, low-contrast watery internal structure, visible but restrained suspended droplets, slow irregular shape motion, and no visual acceleration at the end of the inhale.

Remaining limitation: these are desktop monoscopic renders, not an in-headset comfort or performance certification. The water is intentionally stylized rather than a physically refractive fluid, and the shared orb/breath/audio integration still needs whole-experience verification. Resist increasing the sheet brightness or droplet density significantly: the open dark center is part of its calming composition.

## Review revision: visible liquid volume

A second review found that the broad arches still read as translucent fabric and their scattered droplets were too small to establish water as a substance. Six near floating water lenses now sit beside and above the viewer, accompanied by 54 actual curved liquid beads rendered in one MultiMesh. Their visible silhouettes add liquid volume at a useful scale. On inhale, each lens thickens by about seventy percent while narrowing, rising gently and drawing its beads closer; the exhale spreads it into a thinner suspended pool and releases the beads. Low-frequency surface waves and changing caustic paths keep the pools from becoming rigid discs. The arches remain and now have slowly varying rolled edges.

The new pools are positioned at least several metres from the initial head pose and away from the central source-to-mouth path. Added cost is six modest sphere meshes and one instanced bead draw, approximately 18,000 extra triangles; the layer remains below roughly 50,000 triangles including particle quads and rims. Final captures were replaced after this revision and checked at both breath extremes and reclining. No shader/script errors. Water is still stylized opaque liquid with a refractive-looking highlight treatment, rather than actual screen-space refraction.
