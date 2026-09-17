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
// Seconds for one full circuit of the four characters.
uniform float movement_period = 168.0;

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;
varying float offset_v;
varying float half_width_v;
varying float halo_strength;
varying float facing;
varying float span_v;
varying float ahead;

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

    // Four characters the spiral travels between: a wide slow drift, a tight fast wind,
    // an opening release, and a near-still glide. Without this the warp holds one shape
    // for the whole session and the motion reads as vibration rather than as gesture.
    float draw = breath_fill;
    vec4 params = md_movement(
        vec4(0.993, 1.10, 5.0, 0.020),
        vec4(0.986, 1.34, 11.0, 0.072),
        vec4(0.997, 1.22, 9.0, 0.038),
        vec4(0.991, 1.14, 6.5, 0.012),
        elapsed, movement_period);
    // Inhale winds the spiral inward and tightens each turn; exhale lets it open.
    params += vec4(-0.010 * draw, 0.28 * draw, 5.0 * draw, 0.030 * draw);

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
    // Consecutive halos sum where segments overlap, and a generous overlap therefore
    // prints a regular ladder of bright rungs along every strand. The core is continuous
    // on its own, so the overlap only needs to cover the seam.
    float along = UV.x * 1.04 - 0.02;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    // A ribbon has no meaningful width seen end-on: its length collapses in projection
    // while its width does not, and it reads as a flat rectangular sheet. Comparing the
    // projected length against the true one detects exactly that case.
    facing = length(dir)/max(distance(v_a, v_b), 0.00001);
    // A step far longer than the usual one means the map jumped rather than flowed, and
    // drawing that as a ribbon paints a metres-wide sheet across the view.
    span_v = distance(pa, pb);
    // A segment straddling the camera plane projects with a sign flip and paints a huge
    // sheet across the edge of the view, so it is faded out before it reaches the plane.
    ahead = max(v_a.z, v_b.z);
    // Wider than a hairline: a soft strand that thins as it ages reads as light in air
    // rather than as a drawn stroke.
    float core_width = (0.060 + 0.050 * thickness) * (1.0 - 0.40 * age);
    // A fixed world width collapses to a one-pixel hairline once a strand is far away,
    // which is what makes the field read as drawn lines. Holding a minimum angular
    // width instead keeps distant strands as soft threads of light.
    float depth = max(0.35, -vpos.z);
    core_width = max(core_width, depth * 0.0075);
    // The quad carries the halo as well as the core, so it is several core widths wide;
    // a quad fitted to the core clips the halo away and the strand is a wire again.
    half_width_v = core_width;
    float quad_width = core_width * 4.8;
    vpos.xy += perp * across * quad_width * 2.0;
    offset_v = across * quad_width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    flow_age = (walk + along) / float(MD_TRAIL_STEPS);
    tint = meditation_palette(clamp(0.05 + age * 0.45 + fract(line * 0.6180339) * 0.45, 0.0, 1.0));
    float distance_m = distance(pa, head_position);
    // Distant strands lean further on the halo, so they read as haze rather than wire.
    halo_strength = mix(0.30, 0.60, clamp(distance_m / span, 0.0, 1.0));
    base_alpha = visibility * wrap_fade * md_depth_fade(distance_m, 1.6, span)
        * (0.40 + 0.26 * draw);
}

void fragment() {
    // A narrow core inside a wide halo, so the filament reads as light in a material
    // rather than as a stroke. The halo is still well above zero where the quad ends, so
    // it is tapered to nothing at the edge; without this every strand is outlined by the
    // rectangle that carries it.
    float profile = md_glow(offset_v, half_width_v, halo_strength, 1.5);
    profile *= 1.0 - smoothstep(0.28, 0.5, abs(across_v));
    profile *= smoothstep(0.26, 0.62, facing);
    profile *= 1.0 - smoothstep(1.1, 1.9, span_v);
    profile *= 1.0 - smoothstep(-1.10, -0.20, ahead);
    float trail = (1.0 - flow_age * 0.85) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
