shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float lines = 700.0;

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;
varying float along_v;

// Warm sand through pale gold. Nothing here goes above a soft amber, so the field
// stays bright but never hot.
vec3 pollen_tint(float x) {
    vec3 dusk = vec3(0.26, 0.17, 0.10);
    vec3 sand = vec3(0.60, 0.44, 0.24);
    vec3 gold = vec3(0.94, 0.82, 0.58);
    return x < 0.5 ? mix(dusk, sand, x * 2.0) : mix(sand, gold, (x - 0.5) * 2.0);
}

void vertex() {
    float id = float(INSTANCE_ID);
    float line = floor(id / float(MD_TRAIL_STEPS));
    float walk = mod(id, float(MD_TRAIL_STEPS));
    float age = walk / float(MD_TRAIL_STEPS);

    // A thick, loosely filled volume rather than a shell: with almost no zoom there is
    // nothing pulling the motes onto a surface, so the depth spread is what gives the
    // field its open air.
    float u = (line + 0.5) / lines;
    float grain = fract(line * 0.7548776);
    float y = 1.0 - 2.0 * u;
    float ring = sqrt(max(0.0, 1.0 - y * y));
    float az = line * 2.399963 + elapsed * 0.010;
    float r0 = mix(0.45, 2.10, fract(line * 0.3819660));
    vec3 seed = vec3(cos(az) * ring, y, sin(az) * ring) * r0;

    // Warp-dominant: zoom and yaw are nearly switched off, so the only motion is the
    // four drifting sinusoids. A long wavelength makes neighbouring motes move almost
    // together, which reads as one slow body of air instead of individual particles.
    float draw = breath_fill;
    float zoom = 0.9985 + 0.0010 * draw;
    float zoomexp = 1.02;
    float warp = 8.0 + 2.5 * draw;
    float yaw = 0.0035 + 0.0025 * draw;
    vec4 params = vec4(zoom, zoomexp, warp, yaw);

    float t = elapsed * 0.16;
    vec3 a;
    vec3 b;
    md_trail(seed, t, params, 3.0, int(walk), a, b);

    vec3 origin = world_center + vec3(0.0, 1.4, 0.0);
    vec3 pa = origin + a * 7.4;
    vec3 pb = origin + b * 7.4;

    // Each segment covers only part of its span, so the streamline is drawn as a short
    // dash with air on either side instead of a continuous filament.
    float along = UV.x * 0.30 + 0.12;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    float width = (0.155 + 0.105 * grain) * (1.0 - 0.30 * age);
    vpos.xy += perp * across * width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    along_v = UV.x;
    // Only a few segments behind a slowly advancing head are drawn, so each streamline
    // shows as a short comet of motes rather than the whole dotted curve at once.
    float head = fract(fract(line * 0.4501) + elapsed * 0.028) * float(MD_TRAIL_STEPS);
    float rel = head - walk;
    rel += rel < 0.0 ? float(MD_TRAIL_STEPS) : 0.0;
    float mote_life = exp(-rel * 0.85) * step(rel, 3.0);
    flow_age = age;
    tint = pollen_tint(clamp(0.45 + grain * 0.35 + fract(line * 0.6180339) * 0.25, 0.0, 1.0));
    float near_fade = smoothstep(1.2, 3.0, distance(pa, head_position));
    // A third of the motes carry most of the light; the rest sit near the threshold, so
    // the field never fills in the way the filament worlds do.
    float sparse = mix(0.45, 1.0, pow(fract(line * 0.2360679), 1.4));
    base_alpha = visibility * near_fade * sparse * mote_life * (0.62 + 0.28 * draw);
}

void fragment() {
    // A soft radial falloff on both axes. A linear ramp against a large alpha clips
    // flat across most of the quad, which turns every mote into a hard bright bar.
    vec2 offset = vec2(along_v - 0.5, across_v) * 2.0;
    float profile = exp(-dot(offset, offset) * 3.1);
    ALBEDO = tint;
    ALPHA = profile * base_alpha;
}
