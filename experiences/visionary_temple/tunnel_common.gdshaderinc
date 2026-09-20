// A painted tunnel shell whose cross-section and relief follow one passage's painting.
// Vertices ride the travelling, turning surface for one grid step and then hand over to their
// neighbour, so the displaced contours never swim across the mesh.
uniform mat4 journey_frame;
uniform sampler2D surface : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// R: height, G/B: square-root companded height slope per texel along u/v, A: erosion order (background first).
uniform sampler2D relief : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 map = vec4(4.0, 8.8, 0.0, 0.0); // angular repeats, depth length, swapped axes, turns per second
uniform vec4 shape = vec4(2.0, 1.0, 1.0, 0.0); // superellipse exponent, width, height, polygon sides
uniform vec4 shape_detail = vec4(0.0, 0.0, 0.0, 0.5); // polygon blend, lobes per turn, lobe depth, relief meters
uniform float shell_scale = 1.0;
uniform float brightness = 1.0;
uniform vec3 glow_color = vec3(1.0, 0.93, 0.78);
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float hold_glow = 0.0;
uniform float intensity = 1.0;
const float TAU_V = 6.283185307;
const float RADIUS = 5.6;
const float CONTRACTION = 0.35;
const float AROUND = 320.0;
const float BOUNDARY = -14.0;
const float SLOPE_RANGE = 0.5;
varying vec2 uv_v;
varying vec3 local_v;
varying vec3 normal_v;
varying vec3 around_v;
varying float arc_v;
varying float amplitude_v;

vec2 passage_uv(float turn, float m) {
    return map.z > 0.5 ? vec2(-m / map.y, turn * map.x) : vec2(turn * map.x, m / map.y);
}

float profile(float angle, float turn) {
    float c = abs(cos(angle)) / shape.y;
    float s = abs(sin(angle)) / shape.z;
    float n = shape.x;
    float r = pow(pow(c, n) + pow(s, n), -1.0 / n);
    if (shape.w > 2.5) {
        // Facets ride the painting so their corners stay on the same ornament.
        float sector = TAU_V / shape.w;
        float folded = mod(turn * TAU_V, sector) - 0.5 * sector;
        r *= mix(1.0, cos(0.5 * sector) / cos(folded), shape_detail.x);
    }
    return r * (1.0 + shape_detail.z * cos(shape_detail.y * turn * TAU_V));
}

vec3 wall_point(float angle, float turn, float depth, float squeeze) {
    float r = RADIUS * shell_scale * profile(angle, turn) * squeeze;
    return vec3(cos(angle) * r, sin(angle) * r, depth);
}

void vertex() {
    float segment = UV2.x;
    float slot = VERTEX.z;
    float k = floor(travel / segment);
    float depth = UV2.y > 0.5 ? slot : slot + travel - k * segment;
    float m = depth - travel;
    float steps = map.w * elapsed * AROUND;
    float shift = steps - floor(steps);
    float turn_world = UV.x - shift / AROUND;
    float turn = UV.x + floor(steps) / AROUND;
    float angle = turn_world * TAU_V;
    uv_v = passage_uv(turn, m);
    // Sample relief no finer than the local vertex spacing; the far section blends toward coarse levels.
    vec2 texels = vec2(textureSize(relief, 0));
    float around_texels = (map.z > 0.5 ? texels.y : texels.x) * map.x / AROUND;
    float near_depth = (map.z > 0.5 ? texels.x : texels.y) * 0.125 / map.y;
    float far_depth = (map.z > 0.5 ? texels.x : texels.y) * 0.75 / map.y;
    float near_lod = log2(max(around_texels, near_depth)) - 0.5;
    float far_lod = log2(max(around_texels, far_depth)) - 0.5;
    float lod = max(0.0, mix(near_lod, far_lod, smoothstep(BOUNDARY + 4.0, BOUNDARY, depth)));
    float h = textureLod(relief, uv_v, lod).r;
    float squeeze = 1.0 - breath_fill * CONTRACTION;
    float step_angle = TAU_V / AROUND;
    vec3 base = wall_point(angle, turn, depth, squeeze);
    vec3 ahead = wall_point(angle + step_angle, turn + 1.0 / AROUND, depth, squeeze);
    vec3 behind = wall_point(angle - step_angle, turn - 1.0 / AROUND, depth, squeeze);
    vec3 tangent = ahead - behind;
    arc_v = length(tangent) / (2.0 * step_angle);
    around_v = tangent / max(length(tangent), 1e-5);
    // The inward normal of the undisplaced wall: perpendicular to the cross-section tangent.
    normal_v = normalize(vec3(-around_v.y, around_v.x, 0.0));
    if (dot(normal_v, base) > 0.0) normal_v = -normal_v;
    amplitude_v = shape_detail.w * squeeze;
    local_v = base + normal_v * h * amplitude_v;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4((journey_frame * vec4(local_v, 1.0)).xyz, 1.0);
}

// Paints the shell from its relief sample; `edge_glow` brightens the painting along a dissolving edge.
vec3 shade_wall(vec4 carved, float edge_glow) {
    vec4 paint = texture(surface, uv_v);
    float h = carved.r;
    vec2 companded = carved.gb * 2.0 - 1.0;
    vec2 slope = sign(companded) * companded * companded * SLOPE_RANGE * vec2(textureSize(relief, 0));
    float around_m = arc_v * TAU_V / map.x;
    float h_around = (map.z > 0.5 ? slope.y : slope.x) / around_m;
    float h_depth = map.z > 0.5 ? -slope.x / map.y : slope.y / map.y;
    vec3 n = normalize(normal_v - amplitude_v * (h_around * around_v + h_depth * vec3(0.0, 0.0, 1.0)));
    vec3 to_eye = normalize(-local_v);
    // Relief reads through a soft headlamp and a golden rim from the destination light ahead.
    float lift = dot(n, to_eye) - dot(normal_v, to_eye);
    float lit = clamp(0.86 + 1.1 * lift, 0.55, 1.25);
    float rim = pow(max(dot(n, vec3(0.0, 0.0, -1.0)), 0.0), 3.0);
    vec3 color = paint.rgb * (0.64 + 0.48 * h) * lit;
    color += glow_color * rim * 0.22 * (0.4 + 0.6 * h);
    float heartbeat = 1.0 + hold_glow * (0.16 + 0.05 * sin(elapsed * TAU_V));
    color *= heartbeat * (1.0 + breath_fill * 0.10);
    color = mix(color, color * 1.45 + glow_color * 0.30, edge_glow);
    float toward_light = smoothstep(20.0, 46.0, -local_v.z);
    color = mix(color * brightness, glow_color, toward_light * toward_light);
    color *= 1.0 - smoothstep(4.0, 7.5, local_v.z);
    return color * intensity * 0.86;
}
