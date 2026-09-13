shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Fine sparks drift with the tunnel, adding parallax inside the painted walls.
uniform mat4 journey_frame;
uniform vec3 head_position;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float hold_glow = 0.0;
uniform vec3 mote_color = vec3(1.0, 0.85, 0.45);
varying float opacity;
varying vec3 tint;
void vertex() {
    float i = INSTANCE_CUSTOM.x;
    float a = INSTANCE_CUSTOM.y * 6.283185 + elapsed * 0.006;
    float r = (1.4 + INSTANCE_CUSTOM.z * 3.2) * (1.0 - breath_fill * 0.35);
    float depth = mod(fract(i * 0.318309886) * 64.0 + travel * 1.15, 64.0) - 56.0;
    vec3 local = vec3(cos(a) * r, sin(a) * r, depth);
    local.xy += vec2(sin(elapsed * 0.21 + i), cos(elapsed * 0.17 + i * 1.7)) * 0.18;
    vec3 world = (journey_frame * vec4(local, 1.0)).xyz;
    vec3 view = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
    float size = 0.016 + 0.022 * INSTANCE_CUSTOM.w;
    POSITION = PROJECTION_MATRIX * vec4(view + vec3(VERTEX.xy * size, 0.0), 1.0);
    float twinkle = 0.55 + 0.45 * sin(elapsed * 1.3 + i * 2.1);
    opacity = smoothstep(-56.0, -44.0, depth) * (1.0 - smoothstep(4.0, 7.0, depth)) * smoothstep(0.35, 0.7, distance(world, head_position));
    opacity *= (1.0 - smoothstep(16.0, 36.0, -depth)) * intensity * twinkle * (0.55 + hold_glow * 0.35);
    tint = mix(mote_color, vec3(1.0), INSTANCE_CUSTOM.w * 0.4);
}
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    ALBEDO = tint;
    ALPHA = exp(-dot(p, p) * 4.0) * opacity;
}
