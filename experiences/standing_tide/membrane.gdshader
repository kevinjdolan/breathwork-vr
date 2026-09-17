shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float lines = 700.0;
// Metres per second the water streams past the listener.
uniform float travel_speed = 0.95;
uniform float span = 22.0;
uniform float height = 10.0;
uniform float field_scale = 15.0;

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;
varying float shell_v;
varying float softness;

// Deep sea blue to pale teal; the bright end stays slightly green so the membrane
// reads as water rather than sky.
vec3 tide_tint(float x) {
    vec3 deep = vec3(0.05, 0.16, 0.40);
    vec3 mid = vec3(0.08, 0.42, 0.62);
    vec3 foam = vec3(0.52, 0.86, 0.84);
    return x < 0.55 ? mix(deep, mid, x / 0.55) : mix(mid, foam, (x - 0.55) / 0.45);
}

void vertex() {
    float id = float(INSTANCE_ID);
    float line = floor(id / float(MD_TRAIL_STEPS));
    float walk = mod(id, float(MD_TRAIL_STEPS));
    float age = walk / float(MD_TRAIL_STEPS);
    float depth_rank = fract(line * 0.7548776);

    // Seeds fill a slab of water that streams past rather than a shell hung around the
    // listener, so the membrane is something drifted through instead of sat inside. The
    // slab is wide enough that seeds start well inside and well outside the standing
    // surface, which is what makes the convergence onto it visible.
    float wrap_fade;
    // Negative travel carries the water toward the listener, which is the optic flow of
    // moving forward through it.
    vec3 seed_world = md_drift_seed(line, span, height, -elapsed * travel_speed, wrap_fade);

    // The crossover the whole world is built on: zoom removes a fraction of the radius,
    // so its inward pull grows as (1 - factor) * rad, while the warp displaces by a
    // roughly fixed length no matter where a point sits. Inside the radius where those
    // two balance the warp wins and points spread outward; outside it the zoom wins and
    // pulls them back. Everything piles onto that balance radius, and moving `zoom`
    // with the breath moves the radius, so the membrane swells and relaxes.
    float draw = breath_fill;
    float zoom = 0.9775 + 0.0060 * draw;
    float zoomexp = 1.60 - 0.10 * draw;
    float warp = 4.0 + 0.9 * draw;
    float yaw = 0.008 + 0.006 * draw;
    vec4 params = vec4(zoom, zoomexp, warp, yaw);

    float t = elapsed * 0.26;
    vec3 a;
    vec3 b;
    // Feeding the warp world position rather than a fixed shell coordinate anchors the
    // membrane to the water itself, so drifting through reveals new surface.
    md_trail(seed_world / field_scale, t, params, 2.4, int(walk), a, b);

    vec3 origin = world_center + vec3(0.0, 1.5, 0.0);
    vec3 pa = origin + a * field_scale;
    vec3 pb = origin + b * field_scale;

    float along = UV.x * 1.12 - 0.06;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    float width = (0.078 + 0.055 * depth_rank) * (1.0 - 0.30 * age);
    // A fixed world width collapses to a one-pixel hairline at distance, which is what
    // makes the membrane read as drawn lines; a minimum angular width keeps the far
    // water as soft threads instead.
    float view_depth = max(0.35, -vpos.z);
    width = max(width, view_depth * 0.0105);
    vpos.xy += perp * across * width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    flow_age = (walk + along) / float(MD_TRAIL_STEPS);
    // Strands that have settled onto the surface are lit; the ones still travelling
    // toward it stay dim, which makes the membrane itself the bright object.
    float settled = 1.0 - smoothstep(0.06, 0.42, abs(length(a) - 0.95));
    shell_v = settled;
    tint = tide_tint(clamp(0.10 + settled * 0.55 + fract(line * 0.6180339) * 0.25, 0.0, 1.0));
    float distance_m = distance(pa, head_position);
    // Distant water is widened more than it is bright, so it settles into haze rather
    // than sharpening into wires.
    softness = mix(11.0, 3.2, clamp(distance_m / span, 0.0, 1.0));
    base_alpha = visibility * wrap_fade * md_depth_fade(distance_m, 1.6, span)
        * (0.34 + 0.30 * draw) * (0.30 + 0.85 * settled);
}

void fragment() {
    // A smooth falloff across the strand instead of a clipped edge, so the filament
    // glows rather than reading as a hard line.
    float profile = exp(-across_v * across_v * softness);
    float trail = (1.0 - flow_age * 0.65) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
