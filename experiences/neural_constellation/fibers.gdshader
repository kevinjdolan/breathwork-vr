shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float cycle_angle = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying vec4 attributes;
varying vec3 tint;
varying float distance_to_head;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 drift = 0.045 * vec3(sin(elapsed * 0.11 + p.y), sin(elapsed * 0.087 + p.x), cos(elapsed * 0.096 + p.y));
    p += drift;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
    attributes = INSTANCE_CUSTOM;
    tint = COLOR.rgb;
    distance_to_head = distance(p, head_position);
}
void fragment() {
    float wave = pow(0.5 + 0.5 * sin(attributes.y * 5.0 - cycle_angle + attributes.x * 6.283), 3.0);
    float level = (0.20 + 0.17 * breath_fill + 0.18 * wave) * intensity;
    ALBEDO = tint * level * smoothstep(1.3, 2.2, distance_to_head);
}
