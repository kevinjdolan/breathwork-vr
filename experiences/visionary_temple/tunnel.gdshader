shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// A painted tunnel: baked visionary tiles dissolve into one another between passages.
uniform mat4 journey_frame;
uniform sampler2D tile_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 map_a = vec4(4.0, 8.8, 0.0, 0.0); // angular repeats, depth length, swapped axes, rotation rate
uniform vec4 map_b = vec4(4.0, 8.8, 0.0, 0.0);
uniform vec4 phase_weights = vec4(1.0, 0.0, 0.0, 0.0);
uniform float passage_mix = 0.0;
uniform vec3 glow_color = vec3(1.0, 0.93, 0.78);
uniform vec3 head_position;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float hold_glow = 0.0;
uniform float intensity = 1.0;
const float TAU_V = 6.283185307;
const float SEGMENT = 0.5;
const float RADIUS = 5.6;
const float CONTRACTION = 0.35;
varying vec2 uv_a;
varying vec2 uv_b;
varying float depth_v;
varying float ridge_light;

vec2 tile_uv(float angle, float m, vec4 map) {
    float turn = angle / TAU_V + map.w * elapsed;
    vec2 uv = vec2(turn * map.x, m / map.y);
    return map.z > 0.5 ? vec2(-m / map.y, turn * map.x) : uv;
}

void vertex() {
    float angle = UV.x * TAU_V;
    float slot = VERTEX.z;
    float k = floor(travel / SEGMENT);
    float f = travel - k * SEGMENT;
    float depth = slot + f;
    float m = slot - k * SEGMENT;
    uv_a = tile_uv(angle, m, map_a);
    uv_b = tile_uv(angle, m, map_b);
    float h = mix(textureLod(tile_a, uv_a, 4.0).a, textureLod(tile_b, uv_b, 4.0).a, passage_mix);
    float ca = cos(angle);
    float sa = sin(angle);
    // The cross-section eases from a circle to a broad hall with a flat floor.
    float hall = phase_weights.w;
    float n = mix(2.0, 5.0, hall);
    float vertical = mix(1.0, 0.80, hall);
    float profile = pow(pow(abs(ca), n) + pow(abs(sa) / vertical, n), -1.0 / n);
    float radius = RADIUS * profile;
    // Gentle passage-specific relief keeps the wall a sculpted surface, not a screen.
    radius += phase_weights.x * 0.22 * cos(angle * 12.0 + m * 0.71);
    radius += phase_weights.y * 0.28 * pow(0.5 + 0.5 * cos(angle * 12.0 - m * 0.36), 2.0);
    radius += phase_weights.z * 0.20 * cos(angle * 8.0) * cos(m * 0.785);
    radius += hall * 0.16 * pow(0.5 + 0.5 * cos(m * 0.785), 8.0) * step(0.15, abs(sa));
    radius += 0.10 * sin(m * 0.23 + angle * 3.0 + elapsed * 0.03);
    radius -= (h - 0.15) * 0.42;
    radius *= 1.0 - breath_fill * CONTRACTION;
    vec3 local = vec3(ca * radius, sa * radius, depth);
    vec3 world = (journey_frame * vec4(local, 1.0)).xyz;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
    depth_v = depth;
    ridge_light = h;
}

void fragment() {
    vec4 a = texture(tile_a, uv_a);
    vec4 b = texture(tile_b, uv_b);
    // Ridge-guided dissolve: the next passage first appears along its raised ornament.
    float w = smoothstep(0.0, 1.0, mix(-0.6, 1.6, passage_mix) + (b.a - a.a) * 0.5);
    vec3 color = mix(a.rgb, b.rgb, w);
    float h = mix(a.a, b.a, w);
    float heartbeat = 1.0 + hold_glow * (0.16 + 0.05 * sin(elapsed * TAU_V));
    color *= (0.58 + 0.62 * h) * heartbeat;
    color *= 1.0 + breath_fill * 0.10;
    float toward_light = smoothstep(20.0, 46.0, -depth_v);
    color = mix(color, glow_color, toward_light * toward_light);
    color *= 1.0 - smoothstep(4.0, 7.5, depth_v);
    ALBEDO = color * intensity * 0.86;
}
