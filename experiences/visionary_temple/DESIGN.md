# Visionary Temple — version 2.7

Eight minutes of slow forward travel through a sculpted, painted tunnel that passes through eight visionary passages, one per minute. The tracked camera never moves; the environment slides backward at 0.55 m/s after a five-second eased start. The journey axis anchors to the initial gaze and follows later gaze changes with the same cascaded 3.2-second filters as Prismatic Sanctuary, settling in about sixteen seconds. Unlike the Prismatic tunnel, the journey basis keeps the temple floor toward the ground while the gaze is less than about 80 degrees from horizontal, so a turned head does not roll the hall; a fully reclined start keeps the head axes so the hall rises above the viewer.

## Passages

| Minute | Passage | Painting | Cross-section | Tile mapping |
|---:|---|---|---|---|
| 0 | Eye lattice | Procedural: nested eyes woven by golden sacred-geometry lines with ruby and sapphire nodes | circle | 5 around, 7.0 m, still |
| 1 | Indra's Net | gpt-image-2: carved golden cords in a diamond lattice with moonstone, ruby and emerald jewels over a nebula void | soft hexagon | 6 around, 5.9 m, turning −0.007 turn/s |
| 2 | Flame mandala | Procedural: orange flame petals, violet peacock-eye feathers, dotted mushrooms and small eyes | circle | 4 around, 8.0 m, turning +0.011 turn/s |
| 3 | Peacock Vault | gpt-image-2: overlapping peacock feathers laid like roof tiles | six-lobed fan vault | 6 around, 5.9 m, still |
| 4 | Kaleidoscope rings | Procedural: nested ring cells in gold octagon frames over acid chevrons | circle | 4 around, 8.8 m, turning −0.009 turn/s |
| 5 | Lotus Garden | gpt-image-2: layered lotus blossoms and gold-veined pads on lapis water | tall ellipse | 5 around, 7.0 m, still |
| 6 | Crystal Geode | gpt-image-2: amethyst, quartz and citrine mandalas; each mandala centred on one of eight facets | octagon | 4 around, 8.8 m, turning +0.008 turn/s |
| 7 | Painted temple | Procedural: fluted columns, starry pointed arches, a blue-green diamond floor and a rosette dome | flat-floored superelliptical hall | one repeat around, 6.0 m bays |

The four new passages each bridge their neighbours: the net carries the eyes' gold geometry and jewels toward the flames; the peacock's concentric eye-spots lead from the flame mandala's feathers into the rings; the lotus garden softens the rings into blossoms; the crystal geode is the jewelled antechamber of the temple. Neighbouring passages never turn the same way, so every dissolve shows two motions at once.

## Contour-following relief

Every passage has a relief map baked from a Nano Banana Pro (`gemini-3-pro-image`) height map of its own painting, including the four procedural passages, whose earlier flat plateaus are replaced by domed eyes, rounded flames, grooved ring cells and a ribbed arcade. For the four procedural passages the answers were checked against the exact procedural heights: each is pixel-aligned (edge correlation peaks at zero offset; height correlation 0.61–0.94). gpt-image-2 was also tried and rejected for relief: it renders a lit sculpture that does not line up with the painting. `art/visionary_passages.py` wraps each map periodically, stretches and lightly smooths it, and packs a 1024-texel RGBA relief: height, square-root companded slopes per texel along both axes, and an equalised erosion order that follows broad height with gentle low-frequency variation.

The wall is a real displaced mesh, not a parallax effect. The vertex shader reads height at the mip level that matches the local vertex spacing and pushes the wall inward by 0.45–0.75 m depending on the passage. The fragment shader rebuilds the surface normal from the slopes and lights the relief with a soft headlamp plus a warm rim from the destination light ahead, so contours read even where the mesh cannot follow them.

The tube has 320 vertices around, a 20 m near section with 12.5 cm ring spacing and a 45 m far section with 75 cm spacing, joined by one static ring at 14 m. Vertices ride the travelling and turning surface for one ring or column step and then hand over to their neighbour (a conveyor in both depth and angle), so relief never swims across the grid. Relief sampling blends to coarser mips over the 4 m before the join so both sections agree on the shared ring.

## Dissolves

Each passage owns its minute; its final 30 seconds dissolve into the next (the temple, last, never dissolves). Two shells share the tube:

- The current passage stays in front. During a dissolve it switches to an alpha-tested variant that discards its surface in erosion order, ground first and raised ornament last, so the painting opens along its own contours. A thin warm rim brightens the dissolving edge and fades before the final fragments go. The shell is fully open 60% of the way through.
- The next passage appears behind it on a second shell, 55% wider and half as bright, turning its own way. Once the front shell has opened it settles to its resting size and brightness over the rest of the dissolve. At the minute the front shell takes over the new passage with identical geometry and colour, and the back shell hides.

Tests mirror the cross-section functions and check that every arriving shell, minus its full relief, stays at least 10 cm outside the outgoing shell until that shell has opened. The distant mandala, haze, sparks and glow colours crossfade with a smoothed dissolve progress. Sigils switch motif for anything that arrives after 45 seconds into a minute.

## Breath language

The rhythm is a long-release box: 4 s in, 4 s full hold, 6 s out, 2 s empty rest, thirty complete cycles. Each inhale selects a visible drifting sigil with a predicted six-second sightline; that sigil glows gold and two golden plasma arcs lead from it to the shared neck breath center, forming 1.5 s before the cue and tapering into the hold. The tunnel and its relief contract 35% over the inhale and hold. During the full hold the walls brighten with a restrained 60 BPM heartbeat and the destination light's four rays grow over 500 ms. Sixteen violet-to-cyan petal paths leave the shared neck breath center over the exhale (front over 2.2 s) and clear by 14.3 s, before the next lead-in at 14.5 s. The white destination core stays visible in every phase; only its rays collapse at the exhale and stay absent through the rest.

Drifting through the tunnel are 384 modelled 3D relics of 25 types, 48 per passage, drawn as one MultiMesh per type:

| Passage | Relics |
|---|---|
| Eye lattice | eye orbs in gold settings, brilliant-cut rubies and sapphires, icosahedral gold lattices with gem nodes |
| Indra's Net | brilliant jewels in pronged filigree rings, pearl clusters, gold torus knots |
| Flame mandala | twisting three-lobed flame drops, dotted mushrooms, flame lotuses |
| Peacock Vault | curved, twisted feathers cut out of the painted eye-spot, opal eggs, teardrop gems |
| Kaleidoscope rings | armillary spheres, ring-cell medallions, nested tori |
| Lotus Garden | layered lotus flowers, closed buds, seed pods |
| Crystal Geode | crystal clusters, double-terminated quartz points, step-cut gems |
| Painted temple | star tetrahedra with gilded edges, temple bells, stupas, rosette medallions |

Every relic is a real indexed mesh (48–1,168 triangles) with outward normals, so it can tumble freely. Most tumble about two slowly changing axes; the rest spin about their own axis while rocking like hanging ornaments. A 4 × 4 atlas of Nano Banana Pro material-capture spheres gives surfaces gold, rose gold, pearl, ruby, sapphire, emerald, amethyst, citrine, moonstone, opal, jade, turquoise, lapis, obsidian, rose quartz and rock-crystal looks from one texture fetch indexed by the view-space normal. Each relic picks its own materials. Medallions, eye orbs and feathers also carry the eight-sprite sigil sheet (the four procedural sprites and four gpt-image-2 sprites).

Relics reach the viewer spread across their passage's minute (from 15 seconds before it). Across the tunnel each follows one of six paths: an orbit, a breathing spiral, a figure of eight, a chord that sweeps side to side while keeping clear of the central sightline, a slow circle that rises and falls, or a meander. Along the tunnel, most approach at 0.49–0.73 m/s, growing in from the far glow about 40 m ahead, and surge gently back and forth. About one in eight lingers ahead, fading in 70 seconds before it arrives and approaching at little more than 0.1 m/s. About one in eight overtakes, drifting past the viewer from behind and receding before it fades. Relics stay within 3.4 m of the axis (scaled with the breath), at least 1.05 m from the sightline, and dissolve through a screen-space dither as they pass the face. The motion is closed-form and mirrored in `relics.gd`, so an inhale still chooses a relic that stays in the forward view for six seconds. That relic glows gold and anchors the two plasma arcs. Each relic occupies an instance slot only inside a conservative drawing window; the layer rewrites a type's slots only when that set changes, so at most 105 relics (about 78,000 triangles) run the vertex shader and at most 63 are in view at once. Tests check that every relic is invisible outside its window. `relic_gallery.gd` renders every type from three angles for review.

A vast faint sigil turns slowly around the destination light and crossfades with the passages. 3,072 additive sparks add parallax inside the walls. Three tinted haze veils and a far glow color follow the passage palette. The Aurora Lake breath streams, orb and blue outflow are hidden; particle hands remain.

## Budgets and integration

Each shell draws 140,800 triangles from one shared tube; both shells draw only during the 30-second dissolves (281,600 triangles). Relics draw at most 105 instances and about 78,000 triangles at the busiest moment; sparks, haze, destination light and mandala are single-quad MultiMeshes (about 6,800 triangles). The golden plasma and violet outflow tubes reuse the 96-segment hexagonal tube (about 41,000 triangles instanced). The settled front shell is opaque without discard; the arriving shell draws first in the transparent pass so depth rejects it wherever the front shell remains. There is no volumetric raymarching and no per-frame mesh rebuild. Paintings are lossless mipmapped textures (1024 or 2048 texels); reliefs are 1024 texels on the short side and never auto-compressed, because their channels are data. The tunnel requests native 72 Hz on Quest like Prismatic Sanctuary. The layer exposes `focal_position()` and `reset_journey()`; the director hides the shared orb and outflow for both tunnel journeys.

## Score

`audio/generate_visionary_journey.py` renders one deterministic 480-second arrangement at 60 BPM: one beat is exactly 48,000 samples and sixteen beats are one breath cycle, so every beat lands on a whole second with the breath ticks and every chord change lands on an inhale. A tanpura-like D drone with wandering buzzing partials underlies the whole session. A soft sub heartbeat plays on every tick, softening through the hold and the empty pause. Sixteenth-note plucked arpeggios rise with the inhale, thin through the exhale and mostly fall silent in the rest; plucks on the beat carry the accent. Slow detuned pads swell gently with each inhale; high glass shimmer blooms on sixteenth notes during each full hold. Version 2.7 regenerates the score in eight one-minute harmonic passages that match the tunnel, from D Aeolian through Dorian and major colours to a warm D major temple, each dissolving into the next over the final 30 seconds of its minute exactly as the tunnel does. A synthetic hall impulse response, a 34 Hz high-pass, 7 kHz low-pass, eight-second fades and two-pass loudness normalization to about −20 LUFS complete the master. No sampled or generated backing recording is used. `python -m audio.beat_grid visionary_temple` confirms with librosa that the delivery reads 60 BPM, folds at 1.000 s, peaks with the breath tick and keeps its onsets on the tick grid through all seven dissolves.

## Art provenance

`python -m art.visionary_passages` records every stage: gpt-image-2 candidates (compared with Nano Banana Pro and with neighbour-tile style references), wrap-seam repair by offsetting each painting half a tile and repainting a feathered central cross (Nano Banana Pro for peacock, lotus and geode; gpt-image-2 under a mask for the net), Nano Banana Pro height maps, relief baking and sprite composition. `art/visionary_passages_provenance.json` lists the prompts, models, seam measurements and output hashes; untouched API masters stay local under `art/masters/`, which Git and Godot ignore.

## Review notes

Version 2.6 desktop review found oversized ornament in its first pass and reduced tile scales. Version 2.7 desktop Mobile-renderer captures checked every passage, three dissolves at several depths and reclined views. The first dissolve rim was a flat bright white that left white scribbles along thin cords and blobs on the final islands; it is now a thin, fading brightening of the painting's own colours. Flame relief was reduced from 0.60 m to 0.50 m after its tongues looked spiky close up. The images establish composition and shader correctness only; they do not establish stereo comfort or sustained Quest frame rate, which matter more now that dissolves draw two dense shells. The temple passage is bright and saturated by design and the whole world is scaled to 86% of the painted palette.

Both endpoints follow `BreathGeometry.from_state(state)` and explicit zero local offsets. This uses the current headset-relative neck reference, independent of the tunnel's delayed, floor-aligned journey basis. The `breath-visualization-patterns` skill makes this shared reference a MUST for every current and future experience.
