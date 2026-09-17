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
uniform float shell_scale = 1.0;
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
    float t = elapsed - shell_index * shell_delay;
    float draw = breath_fill;

    // Only a light warp: the ring has to stay readable as a record, so the field is
    // perturbed rather than swirled.
    vec4 params = vec4(0.998 - 0.004 * draw, 1.10 + 0.10 * draw, 1.1 + 0.8 * draw, 0.006);
    vec3 p = md_step(local_dir, t * 0.22, params, 3.2);
    p = md_step(p, t * 0.22, params, 3.2);

    vec3 polar = md_polar(p);
    float ang = polar.y;
    // Azimuth is time, running backwards: the arc in front of the listener is the last
    // few seconds, and each shell out is one further breath phase behind.
    float u = fract((ang + 3.14159265) / 6.2831853);
    float sample_sec = phase_seconds - shell_index * shell_delay - u * ring_window;
    float wave = breath_at(sample_sec);

    // Shells stack upward as balconies; without the offset every ring would sit at the
    // same elevation and the six of them would collapse into one line.
    float base_elev = -0.50 + 0.155 * shell_index;
    float center = base_elev + (wave - 0.5) * 0.125;
    float d = polar.z - center;
    float trace = 1.0 - smoothstep(0.003, 0.013, abs(d));

    // Area under the trace, as a chart's fill: faint, so it adds body without closing
    // the gaps the stack needs to stay see-through.
    float below = step(polar.z, center) * step(center - 0.055, polar.z);
    float fill = below * (1.0 - smoothstep(0.0, 0.055, center - polar.z)) * 0.10;
    // Sparse verticals give the ring a scale to be read against.
    float ticks = below * smoothstep(0.9975, 1.0, sin(u * 6.2831853 * 24.0) * 0.5 + 0.5) * 0.9;

    float body = trace + fill + ticks;
    // Breath at this shell's own delay brightens its own ring.
    body *= 0.55 + 0.55 * wave;

    float echo = pow(0.88, shell_index);
    float alpha = body * echo * visibility * (0.42 + 0.22 * draw);

    // Pale mint at the trace, cooler aqua in the fill: clinical, unsaturated.
    vec3 mint = vec3(0.68, 0.98, 0.88);
    vec3 aqua = vec3(0.24, 0.62, 0.78);
    ALBEDO = mix(aqua, mint, clamp(trace * 1.2 + wave * 0.25, 0.0, 1.0));
    ALPHA = clamp(alpha, 0.0, 1.0);
}
