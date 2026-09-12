# Fractal Garden — version 2.4

A six-fold particle iris opens on inhale and closes on exhale. Recursive crystal constellations float in front of a complete, sculpted spherical vault. Four actual 240-iteration Mandelbrot escape-time/orbit-trap fields crossfade over two-minute passages; the palette and geometry evolve continuously. The vault writes opaque depth so it cannot cover nearby transparent particles. Fine-detail contrast is derivative-filtered and the numeric textures have mipmaps.

All focal paths use tracked head up/right/forward vectors and the tracked mouth target. The focal sculpture inherits the slow gaze-following position; it works upright or reclined. Each world adds 3,072 focal particles, 1,536 directed breath particles and 12,288 surrounding particles in 48 compact clusters. Clusters gather, drift, unravel and relocate only while invisible, with staggered 24–30-second lifecycles. Foreground particles shrink gently near the face. No instructional text appears inside the world.

The authored [6, 0, 6, 0] inhale/hold/exhale/rest pattern and exact 480-second duration remain unchanged. Near, middle and overhead desktop renders have been reviewed; these do not establish stereo comfort or sustained headset performance. The original Aurora Lake is unchanged.

## Earlier design record (superseded where different)

# Fractal Garden

An eight-minute conservatory of living mathematics: nine fern forms use the actual four-map Barnsley iterated function system, curled into three-dimensional laminae. Seven recursive binary trees form the understory. Sage, mint, amber, and pale chartreuse replace neon geometry. Dark forest background: linear Godot `Color(0.006, 0.018, 0.012)`.

The breath is 6 seconds in and 6 seconds out, without holds: forty complete cycles in 480 seconds. Shared breath particles, mouth target, tracked particle hands, and breathing orb remain the personal anchor. The garden responds with a modest 2.5% expansion and 22% point swelling across the inhale, reversing continuously across the exhale. No internal phase timer, reset, camera motion, or abrupt change of mode is used.

## Spatial composition and motion

Six large upright ferns occupy 4.3, 6.5, and 8.7 meter depth bands. Three canopy ferns lean inward above the viewer from radii 3.8, 4.9, and 6.0 meters, distributed around the zenith. Five compact tetrahedral Sierpinski seedpods provide nearby parallax: two below and beside the breathing lane, and three overhead at distinct heights. Each seedpod uses a true midpoint IFS, with soft self-similar cavities. It gathers, opens into local curved strands, then gently reforms over asynchronous 50–63-second cycles. A bounded 13-centimeter drift gives them motion without approaching the face. Their leaves occupy real curved surfaces rather than a flat screen. Asynchronous, roughly 146-second growth waves unfurl each leaf from base to tip and then softly let it dissolve, always retaining a faint scaffold. Slower world-space sway and faint luminosity changes prevent static star-field behavior. The center is deliberately quiet so the mouth-directed breathing stream remains legible.

## Music direction

Lyria prompt: "Quiet organic ambient chamber music in a moonlit mathematical fern conservatory. Warm felt piano fragments, long bowed marimba resonances, soft bamboo air, very gentle viola harmonics, mossy low drone. Unhurried twelve-second harmonic breathing, six seconds gathering and six seconds releasing, without a pronounced beat. Sparse, rich, intimate and restful. Soft attacks, long rounded releases, no percussion hits, bells, vocals, rising tension, climax or startling high frequencies. Emerald and amber nocturnal garden atmosphere; stable dynamics, room for audible breathing. Seamlessly evolving texture suitable for an eight-minute meditation."

Spatial cue suggestion for the host audio layer: quiet breathy wood-resonance voices placed among different fern tips, rare and rounded, never simultaneously accenting every fern or masking the inhale. This layer does not generate or own audio.

## Rendering and integration

Instantiate `layer.gd` at world identity, call `update_experience(state)` each render frame. It accepts the shared dictionary and uses `elapsed`, `intensity`, `breath_fill`, and `head_position`. Visibility follows the host's fade. No WorldEnvironment is installed: the host supplies the dark forest background and hides the original environment.

Budget: 5,860 softly billboarded points in one MultiMesh, 441 five-sided recursive branch segments in one MultiMesh. All geometry is built once. Rendering uses two inexpensive shaders; no raymarch, simulation, shadow maps, dynamic allocation per point, or shader texture lookup. Point scale is local to each instance; branch transforms preserve their full orientation. Target renderer: Godot 4.6 mobile Vulkan.

## Review and refinements

The first actual GPU render exposed two problems that a code review missed: the ferns faced sideways, and nonuniform global scaling compressed the branch directions into vertical streaks. Both were corrected. The next review showed insufficient change beyond swaying; asynchronous growth and dissolution were added, with five closer fractal seedpods to improve presence. A second independent review identified faint leaf definition and a largely empty lower hemisphere. Fern point sizes increased from 16–34 mm to 22–43 mm and alpha from 0.42–0.68 to 0.59–0.82, while keeping the same warm palette and soft dot falloff. The canopy was redistributed around the zenith and seedpods now occupy lower peripheral and overhead space. No full-screen glow, snow, or central clutter was introduced. A 78-degree upward camera verifies actual overhead forms rather than assuming seated composition works while lying down.

Four final screenshots inspect inhale/exhale at both seated and reclined orientations. The mobile Vulkan render log contains no shader or script errors. This is desktop GPU validation, not a claim of Quest frame timing or subjective comfort. The mathematical silhouettes remain readable and the breathing anchor has clear space; the restrained contrast is intentional, but headset review should confirm small leaf points retain definition through Quest optics. If the experience reads too static, increase slow unfurl depth before increasing speed or introducing bursts. If the inhale reads harsh, adjust the shared stream/audio envelopes rather than speeding the garden toward the user. Avoid sudden palette swaps, large global rotations, hard lifetime resets, or bright synchronized cue attacks.
