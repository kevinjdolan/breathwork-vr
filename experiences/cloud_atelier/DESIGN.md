# Cloud Atelier — version 2.4

A soft particle vortex expands and contracts with the breath. 1,434 cloud puffs form curling rivers, stratus banks, close whorls and nine elevated helical islands. 2,520 condensation pearls and further condensing spiral clusters drift through the complete surrounding volume. Music uses sustained airy harmonic swells with rounded edges.

All focal paths use tracked head up/right/forward vectors and the tracked mouth target. The focal sculpture inherits the slow gaze-following position; it works upright or reclined. Each world adds 3,072 focal particles, 1,536 directed breath particles and 12,288 surrounding particles in 48 compact clusters. Clusters gather, drift, unravel and relocate only while invisible, with staggered 24–30-second lifecycles. Foreground particles shrink gently near the face. No instructional text appears inside the world.

The authored [5, 0, 5, 0] inhale/hold/exhale/rest pattern and exact 480-second duration remain unchanged. Near, middle and overhead desktop renders have been reviewed; these do not establish stereo comfort or sustained headset performance. The original Aurora Lake is unchanged.

## Earlier design record (superseded where different)

# Cloud Atelier

A nocturnal conservatory made from clouds. Seven suspended cloud rivers curl into a vault around the viewer, while three irregular overlapping stratus islands make a floating horizon at different depths. Three smaller close cloud whorls sit off the breathing corridor. Small condensation pearls form slow, imperfect loops in the open air. The shared breath source stays in the central negative space.

The eight-minute experience uses a balanced five-second inhale and five-second exhale. Inhaling parts the cloud banks by up to nine percent and lifts them by 32 cm, creating the impression of making room. Exhaling lets them settle together. This is a continuous response to `breath_fill`, with no phase-triggered burst or shape replacement. Independent slow billowing and advection keep the result from looking like a mechanical breathing animation.

## Composition and sound

- Recommended background: `Color(0.060, 0.085, 0.135)` — a dark blue dusk.
- Cool blue clouds are separated from warmer mauve and peach banks. Real world-space banks sit at several radii, including elevated banks and nearby condensation shoals. The overhead vault has an open central aperture for reclining.
- Pearls gradually condense, drift, and evaporate with offset twenty-to-fifty-second visual changes. The cloud field stays well outside the face, and both materials fade near the viewer.
- Music prompt: weightless impressionist ambient; warm felt-piano single notes separated by long silences; bowed-glass harmonics and soft, rounded reed pads; pastel nocturnal cloudscape; very slow harmonic changes; no beat, percussion, voices, loud swells, or treble hiss. The music should remain spacious rather than mark every breath.

## Implementation budget

Two MultiMeshes: 894 soft cloud quads and 840 tiny condensation quads, totaling 1,734 quads / 3,468 triangles. No lights, shadows, physics, ray marching, full-screen fog, or scene-depth sampling. Cloud density uses two small procedural noise samples. Transparent overdraw still requires measurement on the headset; low vertex count alone is not proof of performance.

The public interface is `update_experience(state)`. Time, intensity, breath fill, and tracked head position come from the shared director. Shared hands, incoming/outgoing breath, focal orb, session transport, and sound belong to the application.

## Review and refinements

The first Forward Mobile GPU render looked like a blurry ceiling above a nearly empty seated view. The revision reduced the main-bank puff count, introduced wispy density detail, added a low suspended cloud stream, and separated warm and cool banks. The condensation loops gained gentle internal deformation so they do more than translate as rigid rings.

The independent parent review then identified an overly regular chain of puffs in the lower circular stream. The second revision replaced that stream with overlapping broad stratus islands, stochastic density, tapered ends, varied heights and depths, and close side whorls. Main vault banks also gained irregular thickness and density. Fresh real GPU captures show a layered cloud horizon rather than an evenly spaced circular chain, while the overhead central aperture stays open.

Four final captures were generated and inspected: inhalation and exhalation, each seated and at a 78-degree reclined angle. The overhead aperture remains open, cloud silhouettes visibly part and lift with inhalation, and the lower stream anchors the seated view. The center remains available for the shared orb and directional breath particles. The scene is intentionally soft; it is not a photorealistic volumetric cloud simulation.

Review command:

```sh
.tools/Godot.app/Contents/MacOS/Godot --xr-mode off --path . --always-on-top --max-fps 60 --script experiences/cloud_atelier/review.gd
```

Captures are written to `verification/cloud_atelier/`. Rendering used Godot 4.6.3, Vulkan Forward Mobile, Apple M5. The final log contains no script or shader errors. These desktop captures establish appearance and shader compilation; they do not establish stereo comfort, eight-minute subjective experience, or Quest frame rate. The final integrated shared-orb and audio review remains with the main application.
