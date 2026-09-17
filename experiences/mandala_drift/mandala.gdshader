shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float wedges = 12.0;
// Gates along the corridor, and the distance between them.
uniform float tiles = 6.0;
uniform float gate_spacing = 7.2;
// Metres per second the corridor streams past the listener.
uniform float travel_speed = 1.05;
// Radius of one gate, which is also the warp's world scale.
uniform float field_scale = 5.6;

const float SIDES = 6.0;
const float COPIES = 12.0; // six rotations, each with its mirror: the dihedral group

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

    // Lines are grouped so that every wedge seed appears once per symmetry copy, and
    // every (copy, wedge) pair appears once per gate along the corridor.
    float copy = mod(line, COPIES);
    float rest = floor(line / COPIES);
    float tile = mod(rest, tiles);
    float wedge = floor(rest / tiles);
    float sector = floor(copy * 0.5);
    float mirror = mod(copy, 2.0) < 0.5 ? 1.0 : -1.0;

    // The corridor is a row of gates at fixed depths that wraps as it streams past, so
    // the architecture never runs out. Each gate keeps its own vertical symmetry axis.
    float corridor = tiles * gate_spacing;
    float travel = elapsed * travel_speed;
    float gate_z = mod(tile * gate_spacing + travel, corridor) - corridor * 0.5;
    float wrap_fade = 1.0 - smoothstep(corridor * 0.30, corridor * 0.49, abs(gate_z));

    // The seed azimuth is folded into a single wedge; the copies then rebuild the full
    // circle. Folding the seed rather than the trail keeps the symmetry exact even
    // though the warp map itself has none.
    float u = (wedge + 0.5) / wedges;
    float thickness = fract(wedge * 0.7548776);
    float raw_az = wedge * 2.399963 + elapsed * 0.02;
    float phi = md_fold(raw_az, SIDES);

    // Weighted toward the upper hemisphere so each gate closes into a vault overhead
    // instead of an even shell.
    float y = mix(1.0, -0.30, pow(u, 0.80));
    float ring = sqrt(max(0.0, 1.0 - y * y));
    vec3 seed = vec3(cos(phi) * ring, y, sin(phi) * ring) * (0.72 + 0.46 * thickness);

    // Inhale tightens the fold and speeds the turn; exhale lets the mandala settle.
    float draw = breath_fill;
    float zoom = 0.994 - 0.008 * draw;
    float zoomexp = 1.14 + 0.24 * draw;
    float warp = 2.8 + 2.0 * draw;
    float yaw = 0.018 + 0.014 * draw;
    vec4 params = vec4(zoom, zoomexp, warp, yaw);

    // The warp phase is anchored to the gate's depth in the world rather than to the
    // gate alone, so the vault standing at a given place in the corridor always carries
    // the same figure: advancing through the corridor reveals new tracery instead of
    // repeating one shape. A translated seed cannot be used here because the symmetry
    // copies are applied after the walk, and only a walk about the gate's own axis
    // survives them intact.
    float t = elapsed * 0.22 + gate_z * 0.075;
    vec3 a;
    vec3 b;
    md_trail(seed, t, params, 2.6, int(walk), a, b);

    // Mirror and rotation are applied to the finished streamline, so all twelve copies
    // are the same curve and the symmetry survives the asymmetric warp. The gate is then
    // translated along the corridor axis, which leaves that symmetry exact because the
    // axis passes through the gate's own centre.
    a.z *= mirror;
    b.z *= mirror;
    float turn = sector * 6.283185 / SIDES + elapsed * 0.012;
    a = md_spin(a, turn);
    b = md_spin(b, turn);

    vec3 origin = world_center + vec3(0.0, 1.2, gate_z);
    vec3 pa = origin + a * field_scale;
    vec3 pb = origin + b * field_scale;

    // Consecutive halos sum where segments overlap, and any overlap at all therefore
    // prints a regular ladder of bright rungs along every strand. The segments already
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
    float core_width = (0.036 + 0.026 * thickness) * (1.0 - 0.35 * flow_age);
    // A fixed world width collapses to a one-pixel hairline once a gate is far down the
    // corridor, which is what makes the field read as drawn lines. Holding a minimum
    // angular width instead keeps the distant vaults as soft threads of light.
    float depth = max(0.35, -vpos.z);
    core_width = max(core_width, depth * 0.0060);
    // The quad carries the halo as well as the core, so it is several core widths wide;
    // a quad fitted to the core clips the halo away and the tracery is a wire again.
    half_width_v = core_width;
    float quad_width = core_width * 4.8;
    vpos.xy += perp * across * quad_width * 2.0;
    offset_v = across * quad_width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    tint = mandala_tint(clamp(0.08 + age * 0.55 + fract(wedge * 0.6180339) * 0.35, 0.0, 1.0));
    // Sampled at this fragment's own place along the strand rather than at the segment's
    // start: a shade held constant over a whole segment steps at every join, which prints
    // a faint ladder of rungs down the strand.
    float distance_m = distance(mix(pa, pb, along), head_position);
    // Distant gates lean further on the halo, so the far end of the corridor blurs into
    // haze rather than sharpening into wires.
    halo_strength = mix(0.30, 0.58, clamp(distance_m / (corridor * 0.5), 0.0, 1.0));
    base_alpha = visibility * wrap_fade * md_depth_fade(distance_m, 2.2, corridor * 0.5)
        * (0.32 + 0.22 * draw);
}

void fragment() {
    // A narrow core inside a wide halo, so the tracery reads as light in a material
    // rather than as a stroke. The halo is still well above zero where the quad ends, so
    // it is tapered to nothing at the edge; without this every strand is outlined by the
    // rectangle that carries it.
    float profile = md_glow(offset_v, half_width_v, halo_strength, 1.5);
    profile *= 1.0 - smoothstep(0.28, 0.5, abs(across_v));
    // A gentle knee rather than a sharp one: `facing` is constant over a segment, so a
    // steep fade steps between neighbours and is itself a ladder.
    profile *= smoothstep(0.12, 0.70, facing);
    profile *= 1.0 - smoothstep(0.48, 0.82, span_v);
    profile *= 1.0 - smoothstep(-1.10, -0.20, ahead);
    float trail = (1.0 - flow_age * 0.80) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
