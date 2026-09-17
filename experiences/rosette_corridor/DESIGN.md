# Rosette Corridor — the video echo as real depth

Six translucent shells surround the listener, evenly spaced in log radius between 4.4 m and
the outer limit at 4.4 x 1.46^6. They do not stand still: each one climbs the exponential
ramp continuously, crossing the whole stack in thirteen seconds, and the shell that leaves
the outer limit is the one reborn at the centre. Every shell paints the same rosette field,
evaluated further into the past the further out it has travelled, so the stack still holds
about ten seconds of the world's own history at increasing distance.

This is MilkDrop's `echo_zoom` taken literally. The original redrew the previous frame
slightly enlarged every frame, and the recursion read as an endless tunnel on a flat screen.
Standing inside the recursion instead makes the depth real: the head parallaxes between
shells, and the tunnel stops being an illusion.

Inhalation draws the whole stack inward by about a tenth and brightens the motifs;
exhalation lets it settle back out.

## Why the numbers are what they are

Coverage per shell is the parameter that decides whether the stack reads as depth at all.
Six additively blended spheres each painting more than half their surface produce an opaque
wall with no perceptible layering — the first version did exactly that. Each shell now paints
roughly a tenth of its surface as discrete rosettes with real gaps between them, so six of
them stack to a little over half coverage and the openings stay open.

Motif scale is the second such parameter, and it is what carries the motion. A listener
standing at the centre of a sphere cannot see that sphere change radius, so the flow has to
be in the figure: a shell is seeded with a fine lattice which opens out by a factor of 2.55
as it travels, which is `echo_zoom` itself — the same figure redrawn larger every step.
Scaling frequency by the full radius ratio instead would shatter the outer shells into
unreadable noise, because a sphere's area grows as the square of its radius.

The fade at both ends of the journey is not optional. A shell recycled at full strength pops
visibly at the centre; fading in over the first quarter of the ramp and out over the last
fifth hides the seam, and the slow birth doubles as the thing that stops the nearest shell —
the one filling the whole field of view — from washing out everything behind it.

The fragment shader takes only two `md_step` iterations. These are full-coverage spheres and
there are six of them, so the per-fragment cost is paid six times over.

## Verification

Desktop Mobile Vulkan renders under llvmpipe confirm the layering, the gaps and the breath
response, and show the rosettes visibly growing and sweeping outward between timestamps
three, eight and thirteen seconds in. They cannot show the parallax between shells, which is the effect's main
justification and needs a headset; nor do they establish a sustained standalone frame rate,
which for six full-coverage transparent spheres is the obvious risk.
