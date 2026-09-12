shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying vec3 world;
void vertex() {
    VERTEX.y += 0.085 * sin(elapsed * 0.16 + VERTEX.x * 0.23 + VERTEX.z * 0.17);
    VERTEX.x += 0.06 * sin(elapsed * 0.11 + VERTEX.y * 0.31);
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    // Wide packets have smooth leading and trailing edges, never electrical flashes.
    float phase = fract(UV.x * 0.55 - elapsed * 0.085 + UV.y);
    float packet = pow(0.5 + 0.5 * cos(phase * 6.283185), 5.0);
    float release = 1.0 - breath_fill;
    float brightness = 0.18 + 0.13 * breath_fill + packet * (0.19 + 0.31 * release);
    float near_fade = smoothstep(1.3, 2.3, distance(world, head_position));
    ALBEDO = COLOR.rgb * brightness;
    ALPHA = visibility * near_fade * 0.78;
}
