shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float lines = 750.0;

varying vec3 tint;
varying float base_alpha;
varying float flow_age;
varying float across_v;

void vertex() {
    // Each instance is one segment of one streamline, spanning from its own sample to
    // the next. MilkDrop's decay trail was earlier frames fading in place; drawing the
    // trail as connected geometry shows a point's whole history at once, leaves no gap
    // between samples, and keeps the field free of any frame-to-frame state.
    float id = float(INSTANCE_ID);
    float line = floor(id / float(MD_TRAIL_STEPS));
    float walk = mod(id, float(MD_TRAIL_STEPS));
    float age = walk / float(MD_TRAIL_STEPS);

    // Seeds cover a shell all around the listener, so the flow fills the view in every
    // direction rather than sitting out in front the way a screen would.
    float u = (line + 0.5) / lines;
    float thickness = fract(line * 0.7548776);
    float y = 1.0 - 2.0 * u;
    float ring = sqrt(max(0.0, 1.0 - y * y));
    float az = line * 2.399963 + elapsed * 0.045;
    vec3 seed = vec3(cos(az) * ring, y, sin(az) * ring) * (0.80 + 0.40 * thickness);

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
    md_trail(seed, t, params, 2.5, int(walk), a, b);

    vec3 origin = world_center + vec3(0.0, 1.5, 0.0);
    vec3 pa = origin + a * 9.2;
    vec3 pb = origin + b * 9.2;

    // The strand's length is interpolated in world space so consecutive segments meet
    // exactly, while its width is taken perpendicular in view space. Rolling the quad
    // about the segment instead would collapse it wherever a strand turns toward the
    // viewer. UV is used rather than VERTEX because it is 0..1 by definition, which
    // makes the span from one sample to the next exact.
    float along = UV.x * 1.12 - 0.06;
    float across = UV.y - 0.5;
    vec3 vpos = (VIEW_MATRIX * vec4(mix(pa, pb, along), 1.0)).xyz;
    vec3 v_a = (VIEW_MATRIX * vec4(pa, 1.0)).xyz;
    vec3 v_b = (VIEW_MATRIX * vec4(pb, 1.0)).xyz;
    vec2 dir = v_b.xy - v_a.xy;
    vec2 perp = length(dir) > 0.00001 ? normalize(vec2(-dir.y, dir.x)) : vec2(0.0, 1.0);
    float width = (0.032 + 0.026 * thickness) * (1.0 - 0.40 * age);
    vpos.xy += perp * across * width * 2.0;
    POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);

    // Fading along the streak is the decay term, drawn as distance instead of time.
    // The age is carried across the quad so a strand dims smoothly rather than in
    // visible steps at every segment join.
    across_v = across;
    flow_age = (walk + along) / float(MD_TRAIL_STEPS);
    tint = meditation_palette(clamp(0.05 + age * 0.45 + fract(line * 0.6180339) * 0.45, 0.0, 1.0));
    float near_fade = smoothstep(1.2, 3.0, distance(pa, head_position));
    base_alpha = visibility * near_fade * (0.26 + 0.20 * draw);
}

void fragment() {
    // Soft across the strand, continuous along it, so segments join without beading.
    float profile = 1.0 - smoothstep(0.10, 0.5, abs(across_v));
    float trail = (1.0 - flow_age * 0.85) * smoothstep(0.0, 0.10, flow_age + 0.04);
    ALBEDO = tint;
    ALPHA = profile * trail * base_alpha;
}
