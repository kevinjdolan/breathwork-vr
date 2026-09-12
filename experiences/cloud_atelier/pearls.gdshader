shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying float dissolve;
varying float near_fade;
void vertex() {
    vec3 center = MODEL_MATRIX[3].xyz;
    float phase = INSTANCE_CUSTOM.x * 23.0;
    float cycle = 0.5 + 0.5 * sin(elapsed * 0.14 + phase);
    dissolve = smoothstep(0.1, 0.55, cycle);
    float gather = 0.13 * (1.0 - dissolve);
    center += vec3(sin(phase + INSTANCE_CUSTOM.y * 6.283), cos(phase + INSTANCE_CUSTOM.y * 6.283), sin(phase * 1.7)) * gather;
    center += vec3(sin(INSTANCE_CUSTOM.y * 12.566 + elapsed * 0.13), cos(INSTANCE_CUSTOM.y * 18.849 + elapsed * 0.09), sin(INSTANCE_CUSTOM.y * 6.283 - elapsed * 0.10)) * 0.045;
    center.x += 0.22 * sin(elapsed * 0.10 + phase);
    center.z += 0.20 * cos(elapsed * 0.073 + phase);
    center.y += 0.20 * sin(elapsed * 0.085 + phase) + 0.12 * breath_fill;
    near_fade = smoothstep(0.8, 1.5, distance(center, head_position));
    float size = length(MODEL_MATRIX[0].xyz);
    vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
    POSITION = PROJECTION_MATRIX * vec4(view_center + vec3(VERTEX.xy * size, 0.0), 1.0);
}
void fragment() {
    vec2 q = UV * 2.0 - 1.0;
    float light = exp(-dot(q, q) * 4.2) * (1.0 - smoothstep(0.6, 1.0, length(q)));
    ALBEDO = COLOR.rgb;
    ALPHA = light * COLOR.a * dissolve * near_fade * visibility;
}
