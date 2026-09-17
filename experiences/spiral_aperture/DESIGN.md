# Spiral Aperture — advected warp field

A still seed shell surrounds the listener at roughly nine metres. Every frame that shell is
carried through MilkDrop's warp map — the radial zoom whose strength is an exponential in
`rad`, four slowly drifting sinusoids of position, and a yaw — and the path each seed takes
is drawn as a continuous filament. Seven hundred streamlines, each sampled twenty-four
times, give about seventeen thousand ribbon segments.

The trail is the point. MilkDrop's decay left earlier frames fading in place, which is what
produced its smoke; drawing that history as geometry shows a point's whole past at once,
carries no frame-to-frame state, and so renders identically wherever the session is seeked.

Inhalation lowers `zoom` below one and raises the yaw, winding the filaments inward and
tightening each turn; exhalation lets the spiral open again. Colour runs along each strand
from its head to its tail, so age reads as hue as well as brightness.

## Why the numbers are what they are

The warp's spatial wavelength has to be long compared with the distance covered in one
step, or the displacement direction decorrelates between samples and the "streamline"
becomes a random walk of disconnected dashes. Measured over forty seeds, a warp scale near
2.5 holds the turn between consecutive segments to about twelve degrees while still moving
0.3 m per step; below 1.0 the mean turn exceeds thirty degrees and the field shatters, and
above about six the warp degenerates into a bulk translation that slides the whole field to
one side.

`md_zoom` is clamped in the shared module. MilkDrop's `rad` was bounded by the edge of the
screen, but a room has no such edge, and the unbounded inner power collapses every distant
point onto the origin within a few steps.

Ribbon geometry is built with its length interpolated in world space, so consecutive
segments share an endpoint exactly, and its width taken perpendicular in view space. Rolling
each quad about its own axis instead collapses it to nothing wherever a strand turns toward
the viewer, which breaks every filament into dashes.

The walk length is a compile-time constant. A loop bounded by a per-instance value silently
runs a fixed number of times in this shader path, which puts every sample of a streamline at
the same place; `md_trail` therefore always walks `MD_TRAIL_STEPS` and picks out the segment
belonging to the instance. The layer's per-streamline instance count must match it.

## Verification

Desktop Mobile Vulkan renders under llvmpipe confirm the composition and the breath
response. They do not establish stereo comfort or a sustained frame rate on a standalone
headset; the segment count and the additive overdraw both still need a device measurement.
