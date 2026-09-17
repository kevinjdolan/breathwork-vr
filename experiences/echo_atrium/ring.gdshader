shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform float phase_seconds;
uniform vec3 head_position;
uniform float shell_index = 0.0;
uniform float shell_count = 6.0;
uniform float shell_delay = 4.0;
// Where this ring stands on its journey out: 0 newly born at the centre, 1 leaving the
// outer limit. The layer advances it every frame.
uniform float shell_s = 0.0;
// inhale, hold, exhale, rest — the same pattern the breath audio is cut to, so the
// ring is a reading of the sound the listener actually heard.
uniform vec4 rhythm = vec4(4.0, 2.0, 8.0, 2.0);
// Seconds of history laid around one turn of a ring. Three cycles per turn is what
// makes the curve read as breathing inside a headset's field of view.
uniform float ring_window = 48.0;

varying vec3 local_dir;

void vertex() {
    local_dir = normalize(VERTEX);
}

// The clock's breath_fill, reconstructed for an arbitrary past moment. Stateless, so
// the stack is identical wherever the session is seeked to.
float breath_at(float sec) {
    float period = max(rhythm.x + rhythm.y + rhythm.z + rhythm.w, 0.001);
    float p = mod(sec, period);
    if (p < rhythm.x) {
        return smoothstep(0.0, 1.0, p / max(rhythm.x, 0.001));
    }
    p -= rhythm.x;
    if (p < rhythm.y) {
        return 1.0;
    }
    p -= rhythm.y;
    if (p < rhythm.z) {
        return 1.0 - smoothstep(0.0, 1.0, p / max(rhythm.z, 0.001));
    }
    return 0.0;
}

void fragment() {
    float s = shell_s;
    // The delay stays tied to where the ring stands in the stack, so a ring that has
    // travelled further out is reading further back: the echo survives the motion.
    float t = elapsed - s * shell_count * shell_delay;
    float draw = breath_fill;

    // Only a light warp: the ring has to stay readable as a record, so the field is
    // perturbed rather than swirled.
    vec4 params = vec4(0.998 - 0.004 * draw, 1.10 + 0.10 * draw, 1.1 + 0.8 * draw, 0.006);
    vec3 p = md_step(local_dir, t * 0.22, params, 3.2);
    p = md_step(p, t * 0.22, params, 3.2);

    vec3 polar = md_polar(p);
    float ang = polar.y;
    // A ring is seeded tight and low and opens out as it climbs: less history laid
    // around each turn, a taller wave, a heavier trace. That expansion is the whole
    // sense of travel here, because a ring centred on the listener cannot show its own
    // distance any other way.
    float open = mix(0.62, 1.55, s);
    float u = fract((ang + 3.14159265) / 6.2831853);
    float sample_sec = phase_seconds - s * shell_count * shell_delay - u * ring_window / open;
    float wave = breath_at(sample_sec);

    // Rings climb past the listener as they travel, from below the horizon to above it,
    // which is the one reading of outward flow a full-coverage shell can carry.
    float center = mix(-0.66, 0.58, s) + (wave - 0.5) * mix(0.07, 0.26, s);
    float half_width = mix(0.0035, 0.0150, s);
    float d = polar.z - center;
    float core = 1.0 - smoothstep(half_width * 0.25, half_width, abs(d));
    // A halo the trace carries with it, widening as the ring opens. Without it the
    // atrium is six hairlines and no amount of motion gives it depth; with it a near
    // ring is a broad soft band and a far one a thread, which is the whole cue.
    float halo = exp(-abs(d) / (half_width * 6.0));
    // The core is held back from full strength deliberately: a trace that clips to
    // white is the hard line this world was criticised for, so most of its presence
    // comes from the halo instead.
    float trace = core * 0.78 + halo * mix(0.16, 0.46, s);

    // Area under the trace, as a chart's fill: faint, so it adds body without closing
    // the gaps the stack needs to stay see-through.
    float depth_below = mix(0.028, 0.105, s);
    float below = step(polar.z, center) * step(center - depth_below, polar.z);
    float fill = below * (1.0 - smoothstep(0.0, depth_below, center - polar.z)) * 0.10;
    // Sparse verticals give the ring a scale to be read against, and they thin out as
    // the ring opens, so its own graduations read as coming closer.
    float ticks = below * smoothstep(0.9975, 1.0, sin(u * 6.2831853 * 40.0 / open) * 0.5 + 0.5) * 0.9;

    float body = trace + fill + ticks;
    // Breath at this ring's own delay brightens its own trace.
    body *= 0.55 + 0.55 * wave;

    // Arriving out of nothing and thinning away again: without this the recycled ring
    // would snap into existence at the centre.
    float birth = smoothstep(0.0, 0.20, s);
    float death = 1.0 - smoothstep(0.78, 1.0, s);
    float echo = pow(0.86, s * (shell_count - 1.0)) * birth * death;
    float alpha = body * echo * visibility * (0.44 + 0.22 * draw);

    // Pale mint at the trace, cooler aqua in the fill: clinical, unsaturated.
    vec3 mint = vec3(0.68, 0.98, 0.88);
    vec3 aqua = vec3(0.24, 0.62, 0.78);
    ALBEDO = mix(aqua, mint, clamp(core * 1.2 + wave * 0.25, 0.0, 1.0));
    ALPHA = clamp(alpha, 0.0, 1.0);
}
