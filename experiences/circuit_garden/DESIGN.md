# Circuit Garden

A suspended computer, quietly alive. Open copper, teal and blue circuit lattices curve around the viewer. Separate overhead boards turn the scene into a vaulted electronic garden when reclining. Tiny floating registers gather into concentrated clouds of square charge seeds, drift, and gently disperse.

The eight-minute session uses a four-second inhale and six-second exhale, configured by the shared catalog. Inhale charges and subtly expands component cores. Exhale releases broad, slow waves of current along the traces. Current phase remains continuous across breathing boundaries; there are no arc flashes or voltage jolts. The shared mouth-targeted breath and gaze-following orb remain the focal action.

Recommended background: `Color(0.006, 0.012, 0.018)` — almost-black midnight blue.

## Music direction

Warm, very quiet analog synthesizer meditation; soft rounded oscillators, slowly opening filters and widely spaced low marimba-like sine tones. The feeling of a vintage computer dreaming in a greenhouse. No beat, drums, clicking relays, crackling electricity, busy arpeggios, voices, sudden attacks, piercing highs or dramatic build. Different harmonic voicings slowly emerge across eight minutes, then settle into warmth. Electrical character comes from timbre, not harshness.

## Review and refinement

The first actual GPU render looked too much like repeating chips with antennae. It lacked a convincing connected circuit and felt illustrative instead of spatial. Replaced loose-ended prongs with routed, chamfered inter-component buses, varied component sizes, short pins, and selective double capacitor rings. Rotated panels slightly to soften regular repetition. Added eight compact drifting charge registers with slow appearance/dissipation, including four at high elevation, to provide nearby presence between the larger boards.

The final layer uses 12 separate panels (eight around the viewer and four overhead), 108 instanced component cores and 864 instanced square charge seeds. Circuit traces are one combined finite mesh: 119,232 vertices / 39,744 triangles, measured in the GPU review harness. No raymarch, shadows, dynamic lighting or physics. Trace/current movement and register formation use continuous shader time; breath response consumes the shared breath fill. Changes are deliberately small and gradual to avoid turning a calming electrical scene into a flashing control room.

Standalone review renders compare full inhale and end exhale, seated and at 78 degrees reclined. These establish the desktop composition and shader compilation; they do not establish headset frame rate or stereo comfort. The root session must check the shared orb, actual mouth-directed breath, music and final Quest build together.

Final review completed on Godot 4.6.3 Forward Mobile / Vulkan with four captures and no script or shader errors. See `verification/circuit_garden/render.log` for the actual mesh count.
