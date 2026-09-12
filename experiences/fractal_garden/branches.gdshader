shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, world_vertex_coords;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying float height;
void vertex() {
    height = VERTEX.y;
    VERTEX.xz *= 1.0 + 0.025 * breath_fill;
    VERTEX.x += 0.09 * sin(elapsed * 0.13 + height * 0.53 + VERTEX.z * 0.2);
    VERTEX.z += 0.075 * cos(elapsed * 0.11 + height * 0.47 + VERTEX.x * 0.2);
}
void fragment() {
    ALBEDO = mix(vec3(0.14, 0.26, 0.16), vec3(0.43, 0.40, 0.19), clamp(height * 0.3, 0.0, 1.0));
    ALPHA = visibility * 0.6;
}
