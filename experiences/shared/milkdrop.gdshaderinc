// MilkDrop's warp engine, promoted from the screen plane into the space around the
// listener. In the original (milkdropfs.cpp) every warp-mesh vertex carried a
// precomputed rad/ang, the built-in zoom was an exponential in rad, and four slowly
// drifting sinusoids supplied the swirl. Those three parts survive the move to 3D;
// what changes is that a room has an elevation angle, and that rotation must avoid
// the view axis because sustained roll reads as self-motion in a headset.

// MilkDrop kept one angle. Azimuth stays `ang`; elevation is the new coordinate.
vec3 md_polar(vec3 p) {
    float rad = length(p);
    float ang = atan(p.z, p.x);
    float elev = asin(clamp(p.y / max(rad, 0.0001), -1.0, 1.0));
    return vec3(rad, ang, elev);
}

// fZoom2 = powf(fZoom, powf(fZoomExp, rad*2-1)). The exponent passes through 1 at
// rad 0.5, so a zoom that pulls inward far out pushes outward close in: points
// settle onto a standing surface instead of collapsing into the centre.
// MilkDrop's rad was bounded by the edge of the screen. A room has no such edge, and
// an unbounded rad drives the inner power superexponentially, which snaps every
// distant point onto the origin — so both the exponent and the factor are clamped.
float md_zoom(float rad, float zoom, float zoomexp) {
    float exponent = pow(zoomexp, clamp(rad, 0.0, 1.5) * 2.0 - 1.0);
    return clamp(pow(zoom, exponent), 0.80, 1.25);
}

// The four drifting frequencies, carried over verbatim from the original warp block.
vec4 md_warp_freq(float t) {
    return vec4(11.68 + 4.0 * cos(1.413 * t + 10.0),
                8.77 + 3.0 * cos(1.113 * t + 7.0),
                10.54 + 3.0 * cos(1.233 * t + 3.0),
                11.49 + 4.0 * cos(0.933 * t + 5.0));
}

// MilkDrop displaced (u,v) with four sinusoids of screen position. A third axis needs
// two further terms, otherwise the swirl stays trapped in a plane.
vec3 md_warp(vec3 p, float t, float warp, float scale) {
    vec4 f = md_warp_freq(t * 0.1);
    float k = 1.0 / max(scale, 0.001);
    vec3 d;
    d.x = sin(t * 0.333 + k * (p.y * f.x - p.z * f.w)) + cos(t * 0.753 - k * (p.z * f.y - p.x * f.z));
    d.y = cos(t * 0.375 - k * (p.z * f.z + p.x * f.y)) + sin(t * 0.825 + k * (p.x * f.x + p.y * f.w));
    d.z = sin(t * 0.481 + k * (p.x * f.w - p.y * f.x)) + cos(t * 0.657 - k * (p.y * f.z + p.z * f.y));
    return p + d * warp * 0.0035;
}

// Yaw only. The original rotated about the view axis; that term is the one parameter
// of the engine that does not survive the move to a headset.
vec3 md_spin(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec3(p.x * c - p.z * s, p.y, p.x * s + p.z * c);
}

// The angular symmetry fold most presets applied to `ang` before using it.
float md_fold(float ang, float sides) {
    float segment = 6.283185 / sides;
    return abs(mod(ang, segment) - segment * 0.5);
}

// One application of the complete warp map.
// params: x = zoom, y = zoomexp, z = warp strength, w = yaw per iteration.
vec3 md_step(vec3 p, float t, vec4 params, float scale) {
    p *= md_zoom(length(p), params.x, params.y);
    p = md_warp(p, t, params.z, scale);
    return md_spin(p, params.w);
}

// MilkDrop resampled the previous frame, so structure accumulated without bound. A
// fixed-depth composition of the same map produces the identical streaked, swirled
// structure while staying stateless — which keeps the field identical whenever the
// session is seeked, and keeps it independent of frame rate.
//
// The walk length must be a compile-time constant: a loop bounded by a per-instance
// value silently runs a fixed number of times here, which collapses every sample of a
// streamline onto one point. So the walk always runs to MD_TRAIL_STEPS and the segment
// belonging to this instance is picked out along the way. A layer drawing trails must
// allocate exactly MD_TRAIL_STEPS instances per streamline.
const int MD_TRAIL_STEPS = 24;

void md_trail(vec3 seed, float t, vec4 params, float scale, int index, out vec3 a, out vec3 b) {
    vec3 p = seed;
    a = seed;
    b = md_step(seed, t, params, scale);
    for (int i = 0; i < MD_TRAIL_STEPS; i++) {
        vec3 next = md_step(p, t, params, scale);
        if (i == index) {
            a = p;
            b = next;
        }
        p = next;
    }
}

// echo_zoom redrew the previous frame at a larger scale every frame, which is what
// produced the endless tunnel. Shells make that recursion literal: shell i sits at
// this radius and shows the field as it stood i delays ago.
float md_echo_radius(float base, float ratio, float index) {
    return base * pow(ratio, index);
}

// Seeding a thin shell around the listener gives a surface to watch; seeding a slab of
// space that streams past gives somewhere to be. The depth wraps so the corridor never
// ends, and the returned fade hides that seam by reaching zero at the far plane, where
// the strands are already faint.
//
// The warp is fed world position rather than a fixed shell coordinate, so the structure
// is a property of the space: moving through it reveals new shapes instead of watching
// one surface deform, which is what makes the motion read as travel.
vec3 md_drift_seed(float line, float span, float height, float travel, out float fade) {
    float a = fract(line * 0.7548776);
    float b = fract(line * 0.6180339);
    float c = fract(line * 0.4501381);
    float z = mod(b * 2.0 * span - travel, 2.0 * span) - span;
    vec3 seed = vec3((a - 0.5) * 2.0 * span, (c - 0.5) * 2.0 * height, z);
    fade = 1.0 - smoothstep(span * 0.55, span * 0.96, length(seed.xz));
    return seed;
}

// Aerial perspective: distant strands sit in more air and read as further away, which
// is most of what sells depth once the field has real extent.
float md_depth_fade(float distance_m, float near_m, float far_m) {
    float near_fade = smoothstep(near_m, near_m * 2.4, distance_m);
    return near_fade * (1.0 - 0.72 * smoothstep(near_m * 2.0, far_m, distance_m));
}

// A single hard profile reads as a drawn stroke. A narrow core sitting inside a much
// wider halo reads as light in a material, which is the difference between a wire and a
// filament. The core is deliberately held below full strength: a core that clips to
// white is exactly the hard line this buys its way out of, so most of the presence comes
// from the halo instead.
//
// `offset` is the distance from the strand's axis, `half_width` the core's radius, and
// `halo_scale` the halo's falloff in units of that radius, all in the same units.
//
// The halo must decay to nothing well inside the quad that carries it. A halo as wide as
// the quad does not read as a glow at all: it is a near-uniform wash that fills the
// rectangle edge to edge, and every strand becomes a visible flat card. As a rule the
// quad wants to be at least three times `halo_scale` wide.
float md_glow(float offset, float half_width, float halo_strength, float halo_scale) {
    float core = 1.0 - smoothstep(half_width * 0.25, half_width, abs(offset));
    float halo = exp(-abs(offset) / (half_width * halo_scale));
    return core * 0.78 + halo * halo_strength;
}

// A world whose warp parameters never change holds one character for the whole session,
// and constant character with constant motion is what reads as vibration rather than as
// gesture. MilkDrop answered this twice over: a preset's q variables let it evolve, and
// the visualiser switched presets outright.
//
// This is the same idea in one function. A world authors four characters and circulates
// through them, easing rather than ramping between, so the field gathers, opens and
// settles instead of idling. The breath still modulates on top of whatever comes back.
vec4 md_movement(vec4 first, vec4 second, vec4 third, vec4 fourth, float elapsed, float period) {
    float t = fract(elapsed / max(period, 1.0)) * 4.0;
    int index = int(t);
    float blend = t - float(index);
    // Eased at both ends, so a change of character arrives and departs rather than
    // sliding at a constant rate, which would be one more thing moving steadily.
    blend = blend * blend * (3.0 - 2.0 * blend);
    vec4 from_set = index == 0 ? first : (index == 1 ? second : (index == 2 ? third : fourth));
    vec4 to_set = index == 0 ? second : (index == 1 ? third : (index == 2 ? fourth : first));
    return mix(from_set, to_set, blend);
}
