shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying float phase;
varying float near_fade;
varying float billow;
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise_value(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
    vec3 center = MODEL_MATRIX[3].xyz;
    phase = INSTANCE_CUSTOM.x * 6.283185;
    float opening = breath_fill * breath_fill * (3.0 - 2.0 * breath_fill);
    center.xz *= 1.0 + 0.09 * opening;
    center.y += opening * 0.32;
    center.x += 0.26 * sin(elapsed * 0.071 + center.y * 0.38 + phase);
    center.z += 0.21 * cos(elapsed * 0.053 + center.y * 0.43 + phase);
    center.y += 0.20 * sin(elapsed * 0.061 + center.x * 0.44);
    billow = 0.82 + 0.18 * sin(elapsed * 0.11 + phase);
    near_fade = smoothstep(1.25, 2.0, distance(center, head_position));
    float size = length(MODEL_MATRIX[0].xyz) * (1.0 + 0.10 * sin(elapsed * 0.09 + phase));
    vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
    POSITION = PROJECTION_MATRIX * vec4(view_center + vec3(VERTEX.xy * size, 0.0), 1.0);
}
void fragment() {
    vec2 q = UV * 2.0 - 1.0;
    float angle = atan(q.y, q.x);
    float edge = length(q) + 0.10 * sin(angle * 4.0 + phase) + 0.045 * sin(angle * 7.0 - elapsed * 0.08);
    float wisps = noise_value(q * 4.0 + vec2(phase, elapsed * 0.026));
    float detail = noise_value(q * 8.0 - vec2(elapsed * 0.015, phase));
    float puff = exp(-dot(q, q) * 1.6) * (1.0 - smoothstep(0.38, 1.0, edge + (wisps - 0.5) * 0.23));
    puff *= 0.57 + 0.48 * wisps + 0.13 * detail;
    float light = 0.76 + 0.24 * smoothstep(-0.7, 0.6, q.y);
    ALBEDO = COLOR.rgb * light;
    ALPHA = puff * COLOR.a * visibility * near_fade * billow;
}
