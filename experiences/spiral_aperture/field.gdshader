shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float lines = 700.0;
// Metres per second the field streams past the listener.
uniform float travel_speed = 1.15;
uniform float span = 26.0;
uniform float height = 13.0;
uniform float field_scale = 13.0;

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;
varying float softness;

void vertex() {
    // Each instance is one segment of one streamline. MilkDrop's decay trail was earlier
    // frames fading in place; drawing the trail as connected geometry shows a point's
    // whole history at once and keeps the field free of frame-to-frame state.
    float id = float(INSTANCE_ID);
    float line = floor(id / float(MD_TRAIL_STEPS));
    float walk = mod(id, float(MD_TRAIL_STEPS));
    float age = walk / float(MD_TRAIL_STEPS);
    float thickness = fract(line * 0.2360679);

    vec3 origin = world_center + vec3(0.0, 1.5, 0.0);
    float wrap_fade;
    vec3 seed_world = md_drift_seed(line, span, height, elapsed * travel_speed, wrap_fade);

    // Inhale winds the spiral inward and tightens each turn; exhale lets it open.
    float draw = breath_fill;
    float zoom = 0.990 - 0.010 * draw;
    float zoomexp = 1.20 + 0.28 * draw;
    float warp = 8.0 + 5.0 * draw;
    float yaw = 0.045 + 0.030 * draw;
    vec4 params = vec4(zoom, zoomexp, warp, yaw);

    float t = elapsed * 0.30;
    vec3 a;
    vec3 b;
    md_trail(seed_world / field_scale, t, params, 2.5, int(walk), a, b);

    vec3 pa = origin + a * field_scale;
    vec3 pb = origin + b * field_scale;

    // The strand's length is interpolated in world space so consecutive segments meet
    // exactly, while its width is taken perpendicular in view space. Rolling the quad
    // about the segment instead would collapse it wherever a strand turns toward the
    // viewer. UV is used rather than VERTEX because it is 0..1 by definition.
    float along = UV.x * 1.12 - 0.06;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    // Wider than a hairline: a soft strand that thins as it ages reads as light in air
    // rather than as a drawn stroke.
    float width = (0.060 + 0.050 * thickness) * (1.0 - 0.40 * age);
    // A fixed world width collapses to a one-pixel hairline once a strand is far away,
    // which is what makes the field read as drawn lines. Holding a minimum angular
    // width instead keeps distant strands as soft threads of light.
    float depth = max(0.35, -vpos.z);
    width = max(width, depth * 0.0075);
    vpos.xy += perp * across * width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    flow_age = (walk + along) / float(MD_TRAIL_STEPS);
    tint = meditation_palette(clamp(0.05 + age * 0.45 + fract(line * 0.6180339) * 0.45, 0.0, 1.0));
    float distance_m = distance(pa, head_position);
    // Distant strands are widened more than they are bright, so they blur into haze
    // rather than sharpening into wires.
    softness = mix(13.0, 4.5, clamp(distance_m / span, 0.0, 1.0));
    base_alpha = visibility * wrap_fade * md_depth_fade(distance_m, 1.6, span)
        * (0.42 + 0.30 * draw);
}

void fragment() {
    // A smooth falloff across the strand instead of a clipped edge, so the filament
    // glows rather than reading as a hard line.
    float profile = exp(-across_v * across_v * softness);
    float trail = (1.0 - flow_age * 0.85) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
