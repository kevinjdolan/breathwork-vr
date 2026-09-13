shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A white destination core with four breath rays, sixty meters ahead.
uniform mat4 journey_frame;
uniform vec3 star_position;
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float star_radius = 1.0;
uniform vec3 glow_color = vec3(1.0, 0.95, 0.85);
varying vec3 tint;
varying float opacity;
void vertex() {
    float i = INSTANCE_CUSTOM.x;
    float a = INSTANCE_CUSTOM.y * 6.283185;
    float r = pow(INSTANCE_CUSTOM.z, 2.4) * 0.45;
    vec3 offset = vec3(cos(a) * r, sin(a) * r, 0.0);
    float size = 1.15;
    opacity = 0.85;
    if (i > 63.0) {
        float side = floor((i - 64.0) / 64.0);
        float t = mod(i - 64.0, 64.0) / 63.0;
        float length = 1.7 + breath_fill * 0.9;
        float ray_angle = side * 1.57079633 + 0.7853982 + 0.06 * sin(elapsed * 0.08);
        float bend = sin(t * 3.14159265) * (0.10 + breath_fill * 0.24);
        offset.xy = vec2(cos(ray_angle), sin(ray_angle)) * t * length + vec2(-sin(ray_angle), cos(ray_angle)) * bend;
        size = 0.30 * (1.0 - t * 0.65);
        opacity = 0.65 * (1.0 - t);
        offset *= star_radius;
        size *= star_radius;
        opacity *= step(0.001, star_radius);
    }
    // The core itself remains visible through every phase of the breath.
    if (i < 4.0) { offset = vec3(0.0); size = 6.5; opacity = 0.06; }
    vec3 world = star_position + mat3(journey_frame) * offset;
    vec3 view = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
    POSITION = PROJECTION_MATRIX * vec4(view + vec3(VERTEX.xy * size, 0.0), 1.0);
    tint = mix(vec3(1.0), glow_color, i < 4.0 ? 0.6 : 0.15);
    opacity *= intensity;
}
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    ALBEDO = tint;
    ALPHA = exp(-dot(p, p) * 4.0) * opacity;
}
