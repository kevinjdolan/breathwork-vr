shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float wedges = 52.0;

const float SIDES = 6.0;
const float COPIES = 12.0; // six rotations, each with its mirror: the dihedral group

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;

// Violet through magenta, kept low in saturation at the dim end so the dome reads as
// architecture rather than neon.
vec3 mandala_tint(float x) {
    vec3 deep = vec3(0.18, 0.10, 0.36);
    vec3 mid = vec3(0.48, 0.18, 0.60);
    vec3 hot = vec3(0.82, 0.42, 0.70);
    return x < 0.5 ? mix(deep, mid, x * 2.0) : mix(mid, hot, (x - 0.5) * 2.0);
}

void vertex() {
    float id = float(INSTANCE_ID);
    float line = floor(id / float(MD_TRAIL_STEPS));
    float walk = mod(id, float(MD_TRAIL_STEPS));
    float age = walk / float(MD_TRAIL_STEPS);

    // Lines are grouped so that every wedge seed appears once per symmetry copy.
    float copy = mod(line, COPIES);
    float wedge = floor(line / COPIES);
    float sector = floor(copy * 0.5);
    float mirror = mod(copy, 2.0) < 0.5 ? 1.0 : -1.0;

    // The seed azimuth is folded into a single wedge; the copies then rebuild the full
    // circle. Folding the seed rather than the trail keeps the symmetry exact even
    // though the warp map itself has none.
    float u = (wedge + 0.5) / wedges;
    float thickness = fract(wedge * 0.7548776);
    float raw_az = wedge * 2.399963 + elapsed * 0.02;
    float phi = md_fold(raw_az, SIDES);

    // Weighted toward the upper hemisphere so the structure closes into a dome
    // overhead instead of an even shell.
    float y = mix(1.0, -0.30, pow(u, 0.80));
    float ring = sqrt(max(0.0, 1.0 - y * y));
    vec3 seed = vec3(cos(phi) * ring, y, sin(phi) * ring) * (0.72 + 0.46 * thickness);

    // Inhale tightens the fold and speeds the turn; exhale lets the mandala settle.
    float draw = breath_fill;
    float zoom = 0.994 - 0.008 * draw;
    float zoomexp = 1.14 + 0.24 * draw;
    float warp = 5.0 + 3.5 * draw;
    float yaw = 0.022 + 0.018 * draw;
    vec4 params = vec4(zoom, zoomexp, warp, yaw);

    float t = elapsed * 0.22;
    vec3 a;
    vec3 b;
    md_trail(seed, t, params, 2.6, int(walk), a, b);

    // Mirror and rotation are applied to the finished streamline, so all twelve copies
    // are the same curve and the symmetry survives the asymmetric warp.
    a.z *= mirror;
    b.z *= mirror;
    float turn = sector * 6.283185 / SIDES + elapsed * 0.012;
    a = md_spin(a, turn);
    b = md_spin(b, turn);

    vec3 origin = world_center + vec3(0.0, 1.2, 0.0);
    vec3 pa = origin + a * 8.6;
    vec3 pb = origin + b * 8.6;

    float along = UV.x * 1.12 - 0.06;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    float width = (0.026 + 0.020 * thickness) * (1.0 - 0.35 * age);
    vpos.xy += perp * across * width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    flow_age = (walk + along) / float(MD_TRAIL_STEPS);
    tint = mandala_tint(clamp(0.08 + age * 0.55 + fract(wedge * 0.6180339) * 0.35, 0.0, 1.0));
    float near_fade = smoothstep(1.2, 3.0, distance(pa, head_position));
    base_alpha = visibility * near_fade * (0.24 + 0.18 * draw);
}

void fragment() {
    float profile = 1.0 - smoothstep(0.10, 0.5, abs(across_v));
    float trail = (1.0 - flow_age * 0.80) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
