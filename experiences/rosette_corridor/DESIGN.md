# Rosette Corridor — the video echo as real depth

Six translucent shells stand around the listener at geometric radii, 4.4 m outward by a
factor of 1.46 each time. Every shell paints the same rosette field, but shell *i* evaluates
it 1.6 seconds further into the past, so the stack holds about ten seconds of the world's
own history at increasing distance.

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

Motif scale across shells is the second such parameter. Holding the motif's world size
constant — frequency proportional to radius, which is what `echo_zoom` literally implies —
makes the outer shells explode into unreadable fine noise, because a sphere's area grows as
the square of its radius. A mild ramp of `1 + 0.32·index` keeps the recession legible without
the outer shells filling in.

The fragment shader takes only two `md_step` iterations. These are full-coverage spheres and
there are six of them, so the per-fragment cost is paid six times over.

## Verification

Desktop Mobile Vulkan renders under llvmpipe confirm the layering, the gaps and the breath
response. They cannot show the parallax between shells, which is the effect's main
justification and needs a headset; nor do they establish a sustained standalone frame rate,
which for six full-coverage transparent spheres is the obvious risk.
