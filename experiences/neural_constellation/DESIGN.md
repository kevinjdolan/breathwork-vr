# Neural Constellation — version 2.4

A twelve-arm dendritic particle crown gathers and radiates breath signals. Forty-eight somas carry eight branching arms each, denser nearest-neighbor axons and doubled path signals. A surrounding ecology of smaller dendritic clusters carries traveling light packets. Rounded electronic resonances answer across the stereo field.

All focal paths use tracked head up/right/forward vectors and the tracked mouth target. The focal sculpture inherits the slow gaze-following position; it works upright or reclined. Each world adds 3,072 focal particles, 1,536 directed breath particles and 12,288 surrounding particles in 48 compact clusters. Clusters gather, drift, unravel and relocate only while invisible, with staggered 24–30-second lifecycles. Foreground particles shrink gently near the face. No instructional text appears inside the world.

The authored [5, 0, 7, 0] inhale/hold/exhale/rest pattern and exact 480-second duration remain unchanged. Near, middle and overhead desktop renders have been reviewed; these do not establish stereo comfort or sustained headset performance. The original Aurora Lake is unchanged.

## Earlier design record (superseded where different)

# Neural Constellation

Eight minutes inside a living canopy of neurons. Twenty-seven particle somas send curved dendrites into a softly connected web. The visual language is organic and intimate: slate indigo, muted teal, lavender, copper, and occasional warm synapse centers. The open space at the mouth belongs to the shared breathing particles.

## Breath and music

Use 5 seconds in, 7 seconds out, without holds. Broad bands of synaptic activity propagate over the connections once per supplied breathing cycle. Their phase is derived from `inhale_t` / `exhale_t`; light intensity and soma size gently expand with `breath_fill`. No phase transition starts a hard burst. Individual soma grains gather and loosen over much longer overlapping rhythms, with small continuous drift.

Music prompt: Instrumental eight-minute ambient meditation in a living constellation of neurons. Warm electric-piano resonance stretched into overlapping clouds, low velvet analog sine chords, very sparse rounded glass harmonics, subtle organic resonant textures. An intimate, thoughtful, tender character, with unhurried harmonic changes and no beat. Opening spacious and welcoming, middle gently more connected and luminous, final minute returning to quiet. No voices, choir, speech, drums, ticks, sharp attacks, bright fizz, dramatic rises, or rhythmic ostinato. Soft sustained transients, long smooth decays, calm energy throughout.

Suggested background: `Color(0.007, 0.009, 0.023)`. The layer supplies no WorldEnvironment; integration should use a dark solid background and retain shared orb, incoming/outgoing particles, and hands.

## Spatial construction and budget

The somas inhabit a three-dimensional shell approximately 3.3–8.9 metres from the initial breathing space. Elevations span below eye level through near zenith, so reclining reveals a dense canopy rather than an empty sky. Curved axons connect neighboring neurons; smaller dendrites bifurcate around every soma. There is no camera motion. Geometry within 1.3–2.2 metres of the head fades visually to protect the face space.

Two MultiMesh draw nodes contain low-sided cylindrical fibers and round soft particle quads. All motion runs in two simple vertex shaders. No real-time lights, shadows, physics, raymarching, texture fetches, or CPU transform uploads per frame. Measured construction contains 5,400 synapse/signal particles and 5,016 four-sided fiber segments, across two draw nodes; the particle count remains below the 6,000-particle budget. Opaque fiber brightness fades to the near-black background; point particles use additive alpha.

## Review and refinement

1. Initial seated render: soma points were too small and dispersed. The web read as thin wires with almost invisible neurons. Tightened the core radius, increased each core from 72 to 108 grains, and increased grain size while keeping broad, soft alpha. This makes the neuron center feel inhabited without inserting solid balls.
2. Initial signal logic used an independent time oscillator. Replaced it with a continuous angle derived from the supplied breathing phases, so the activity is meaningfully associated with breathing and wraps without a flash.
3. Reclined render: the upward canopy contains several layers of curved connections and individually visible neurons. Near and far fibers cross with real depth. The view remains spacious enough for the shared breathing orb.
4. Residual risk: long thin fibers may alias on headset displays even though desktop mobile Vulkan renders are clean. Their brightness is intentionally restrained. Actual stereo comfort and sustained Quest performance require device review; screenshots do not establish those outcomes.

## Verification artifacts

`review.gd` is a standalone deterministic GPU review scene. It renders end-exhale and full-inhale states seated and at 78 degrees reclined, using `RenderingServer.force_draw` before captures. Images and logs are under `verification/neural_constellation/` (ignored from Git). Review backgrounds match the recommended integration color. The review deliberately isolates this layer; it does not claim to test shared orb, breath audio, menu, or headset tracking.

## Independent review revision

The integrating reviewer found seated fibers too hair-thin and somas insufficiently present. Main inter-neuron axons are now 11 mm rather than 7 mm; the finest dendrites retain their original width. Three existing nodes were repositioned into near left/right/overhead peripheral space, with 180 grains per near soma redistributed from distant nodes. Total particles decreased to 5,400. Their three-lobed forms rotate and deform slowly, with muted teal/lavender/copper cores. Long asynchronous formation cycles now spread grains outward while their brightness fades almost away, then gather them back smoothly; seeds and positions never jump. Seated gathered/dissolving captures additionally check this change. The breathing orb center remains an open region between the closer nodes.
