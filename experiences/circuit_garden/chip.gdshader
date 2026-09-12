shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
void vertex() {
    VERTEX.xy *= 1.0 + 0.07 * breath_fill;
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world.y += 0.085 * sin(elapsed * 0.16 + world.x * 0.23 + world.z * 0.17);
    world.x += 0.06 * sin(elapsed * 0.11 + world.y * 0.31);
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
    vec2 q = abs(UV - vec2(0.5));
    float edge = smoothstep(0.35, 0.44, max(q.x, q.y));
    float grid = smoothstep(0.055, 0.018, abs(fract(UV.x * 5.0) - 0.5));
    ALBEDO = COLOR.rgb * (0.08 + edge * 0.27 + grid * 0.08 + breath_fill * 0.21) * visibility;
}
