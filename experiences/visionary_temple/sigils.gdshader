shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, fog_disabled;
// Floating painted sigils drift through the tunnel and serve as inhale sources.
uniform mat4 journey_frame;
uniform sampler2D sprite_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 head_position;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float source_index = -1.0;
uniform float beam_visibility = 0.0;
uniform float hold_glow = 0.0;
const float SPEED = 0.55;
const float PASSAGE = 120.0;
const float TAU_V = 6.283185307;
varying vec2 sprite_uv;
varying float visibility;
varying vec3 tint;

void vertex() {
    float index = INSTANCE_CUSTOM.x;
    float seed = fract(index * 0.6180339) * TAU_V;
    float depth = mod(fract(index * 0.75487766) * 64.0 + travel, 64.0) - 56.0;
    float z_seed = fract(index * 0.56984);
    float w = fract(index * 0.438579);
    float near_lane = step(z_seed, 0.27);
    float radius = mix(2.3 + z_seed * 1.4, 1.15 + w * 0.35, near_lane);
    float size = mix(0.55 + w * 0.55, 0.26 + w * 0.12, near_lane);
    size *= 1.0 - breath_fill * 0.35;
    float shell = 3.05 * (1.0 - breath_fill * 0.35);
    float extent = size * 0.55;
    radius = max(mix(1.3, 1.05, near_lane), radius * (1.0 - breath_fill * 0.35));
    radius = max(radius, abs(depth) * 0.035 + size * 0.6);
    radius = min(radius, shell - extent - 0.16);
    float angle = seed + 0.07 * sin(elapsed * 0.061 + index);
    vec3 center = vec3(cos(angle) * radius, sin(angle) * radius, depth);
    center.xy += vec2(sin(elapsed * 0.17 + seed), cos(elapsed * 0.12 + seed * 2.0)) * 0.10;
    center.z += 0.12 * sin(elapsed * 0.10 + seed);
    // The sprite is fixed per lifetime: whichever passage is current when it reaches the viewer.
    float arrival = elapsed + (-depth) / SPEED;
    float sprite = clamp(floor(arrival / PASSAGE), 0.0, 3.0);
    float spin = elapsed * (0.05 + 0.04 * w) * (step(0.5, z_seed) * 2.0 - 1.0) + seed;
    vec2 local = VERTEX.xy * size;
    local = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * local;
    vec3 world = (journey_frame * vec4(center, 1.0)).xyz;
    vec3 view = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
    POSITION = PROJECTION_MATRIX * vec4(view + vec3(local, 0.0), 1.0);
    vec2 corner = vec2(mod(sprite, 2.0), floor(sprite / 2.0));
    sprite_uv = (UV + corner) * 0.5;
    visibility = smoothstep(-56.0, -46.0, depth) * (1.0 - smoothstep(4.0, 7.0, depth)) * smoothstep(0.45, 0.80, distance(world, head_position)) * intensity;
    visibility *= 1.0 - smoothstep(18.0, 40.0, -depth);
    float chosen = abs(index - source_index) < 0.5 ? beam_visibility : 0.0;
    float breathing = 0.92 + 0.08 * sin(elapsed * 0.9 + seed) + hold_glow * 0.12;
    tint = mix(vec3(1.0), vec3(1.0, 0.86, 0.45) * 1.35, chosen * 0.8) * breathing;
}

void fragment() {
    vec4 sample = texture(sprite_sheet, sprite_uv);
    float alpha = sample.a * visibility;
    if (alpha < 0.02) discard;
    ALBEDO = sample.rgb * tint;
    ALPHA = alpha;
}
