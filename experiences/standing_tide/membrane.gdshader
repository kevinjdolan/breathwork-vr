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
varying float offset_v;
varying float half_width_v;
varying float halo_strength;
varying float facing;
varying float span_v;
varying float ahead;

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

    // Consecutive halos sum where segments overlap, and any overlap at all therefore
    // prints a regular ladder of bright rungs along every ribbon. The segments already
    // share their endpoints, so they are butted rather than lapped.
    float along = UV.x;
    float across = UV.y - 0.5;
    // Taken before the width, so the taper is continuous across a seam: an age held
    // constant over a whole segment steps at every join and prints a faint ladder.
    flow_age = (walk + along) / float(MD_TRAIL_STEPS);
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    // A ribbon has no meaningful width seen end-on: its length collapses in projection
    // while its width does not, and it reads as a flat rectangular sheet. Comparing the
    // projected length against the true one detects exactly that case.
    facing = length(dir) / max(distance(v_a, v_b), 0.00001);
    // A step far longer than the usual one means the map jumped rather than flowed, and
    // drawing that as a ribbon paints a metres-wide sheet across the view.
    span_v = distance(pa, pb);
    // A segment straddling the camera plane projects with a sign flip and paints a huge
    // sheet across the edge of the view, so it is faded out before it reaches the plane.
    ahead = max(v_a.z, v_b.z);
    // The ribbon was one soft smear across its whole width; the visible body is now a
    // defined core, and the rest of the old width becomes the halo carrying it.
    float core_width = (0.050 + 0.036 * depth_rank) * (1.0 - 0.30 * flow_age);
    // A fixed world width collapses to a one-pixel hairline at distance, which is what
    // makes the membrane read as drawn lines; a minimum angular width keeps the far
    // water as soft threads instead.
    float view_depth = max(0.35, -vpos.z);
    core_width = max(core_width, view_depth * 0.0060);
    // The quad carries the halo as well as the core, so it is several core widths wide;
    // a quad fitted to the core clips the halo away and the ribbon is a wire again.
    half_width_v = core_width;
    // A segment killed outright by the end-on fade leaves its neighbour's end cut
    // square. Narrowing it to a point as it turns instead lets the strand taper.
    float taper = mix(0.22, 1.0, smoothstep(0.12, 0.70, facing));
    float quad_width = core_width * 4.8 * taper;
    vpos.xy += perp * across * quad_width * 2.0;
    offset_v = across * quad_width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    // Strands that have settled onto the surface are lit; the ones still travelling
    // toward it stay dim, which makes the membrane itself the bright object.
    // Sampled at this fragment's own place along the ribbon rather than at the segment's
    // start: a shade held constant over a whole segment steps at every join, which prints
    // a faint ladder of rungs down the ribbon.
    float settled = 1.0 - smoothstep(0.06, 0.42, abs(length(mix(a, b, along)) - 0.95));
    shell_v = settled;
    tint = tide_tint(clamp(0.10 + settled * 0.55 + fract(line * 0.6180339) * 0.25, 0.0, 1.0));
    float distance_m = distance(mix(pa, pb, along), head_position);
    // Distant water leans further on the halo, so it settles into haze rather than
    // sharpening into wires.
    halo_strength = mix(0.28, 0.56, clamp(distance_m / span, 0.0, 1.0));
    base_alpha = visibility * wrap_fade * md_depth_fade(distance_m, 1.6, span)
        * (0.34 + 0.30 * draw) * (0.30 + 0.85 * settled);
}

void fragment() {
    // A narrow core inside a wide halo, so the ribbon reads as lit water rather than as
    // a soft smear. The halo is still well above zero where the quad ends, so it is
    // tapered to nothing at the edge; without this every ribbon is outlined by the
    // rectangle that carries it.
    float profile = md_glow(offset_v, half_width_v, halo_strength, 1.5);
    profile *= 1.0 - smoothstep(0.28, 0.5, abs(across_v));
    // A gentle knee rather than a sharp one: `facing` is constant over a segment, so a
    // steep fade steps between neighbours and is itself a ladder.
    profile *= smoothstep(0.12, 0.70, facing);
    profile *= 1.0 - smoothstep(1.28, 2.20, span_v);
    profile *= 1.0 - smoothstep(-1.10, -0.20, ahead);
    float trail = (1.0 - flow_age * 0.65) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
