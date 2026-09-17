shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float lines = 700.0;
// Metres per second the air streams past the listener.
uniform float travel_speed = 1.45;
uniform float span = 30.0;
uniform float height = 12.0;
uniform float field_scale = 11.0;

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;
varying float along_v;
varying float softness;

// Warm sand through pale gold. Nothing here goes above a soft amber, so the field
// stays bright but never hot.
vec3 pollen_tint(float x) {
    vec3 dusk = vec3(0.34, 0.22, 0.11);
    vec3 sand = vec3(0.70, 0.50, 0.25);
    vec3 gold = vec3(1.00, 0.85, 0.55);
    return x < 0.5 ? mix(dusk, sand, x * 2.0) : mix(sand, gold, (x - 0.5) * 2.0);
}

void vertex() {
    float id = float(INSTANCE_ID);
    float line = floor(id / float(MD_TRAIL_STEPS));
    float walk = mod(id, float(MD_TRAIL_STEPS));
    float age = walk / float(MD_TRAIL_STEPS);
    float grain = fract(line * 0.7548776);

    // A deep slab of air streaming past rather than a shell: the motes nearest the head
    // sweep across the view while the far ones barely move, and that parallax is the
    // whole reading of forward motion in a field with no lines to trace it.
    float wrap_fade;
    // Negative travel carries the air toward the listener, which is the optic flow of
    // moving forward through it.
    vec3 seed_world = md_drift_seed(line, span, height, -elapsed * travel_speed, wrap_fade);

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
    // World position rather than a fixed shell coordinate, so the turbulence belongs to
    // the air: drifting onward brings new weather instead of redeforming one volume.
    md_trail(seed_world / field_scale, t, params, 3.0, int(walk), a, b);

    vec3 origin = world_center + vec3(0.0, 1.4, 0.0);
    vec3 pa = origin + a * field_scale;
    vec3 pb = origin + b * field_scale;

    // Each segment covers only part of its span, so the streamline is drawn as a short
    // dash with air on either side instead of a continuous filament.
    float along = UV.x * 0.30 + 0.12;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    float width = (0.165 + 0.120 * grain) * (1.0 - 0.30 * age);
    // Far motes would otherwise shrink below a pixel and sparkle; a floor on the angular
    // size holds them as faint specks of pollen instead.
    float view_depth = max(0.35, -vpos.z);
    width = max(width, view_depth * 0.0055);
    vpos.xy += perp * across * width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    across_v = across;
    along_v = UV.x;
    // Only a few segments behind a slowly advancing head are drawn, so each streamline
    // shows as a short comet of motes rather than the whole dotted curve at once.
    float head = fract(fract(line * 0.4501) + elapsed * 0.028) * float(MD_TRAIL_STEPS);
    float rel = head - walk;
    rel += rel < 0.0 ? float(MD_TRAIL_STEPS) : 0.0;
    float mote_life = exp(-rel * 0.62) * step(rel, 5.0);
    flow_age = age;
    tint = pollen_tint(clamp(0.45 + grain * 0.35 + fract(line * 0.6180339) * 0.25, 0.0, 1.0));
    float distance_m = distance(pa, head_position);
    // Distant motes are blurred rather than merely dimmed, so the far air reads as haze.
    softness = mix(3.4, 1.5, clamp(distance_m / span, 0.0, 1.0));
    // A third of the motes carry most of the light; the rest sit near the threshold, so
    // the field never fills in the way the filament worlds do.
    float sparse = mix(0.38, 1.0, pow(fract(line * 0.2360679), 1.4));
    base_alpha = visibility * wrap_fade * md_depth_fade(distance_m, 1.5, span)
        * sparse * mote_life * (2.1 + 0.7 * draw);
}

void fragment() {
    // A soft radial falloff on both axes. A linear ramp against a large alpha clips
    // flat across most of the quad, which turns every mote into a hard bright bar.
    vec2 offset = vec2(along_v - 0.5, across_v) * 2.0;
    float profile = exp(-dot(offset, offset) * softness);
    ALBEDO = tint;
    ALPHA = profile * base_alpha;
}
