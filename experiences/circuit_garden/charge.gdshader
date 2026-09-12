shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying float presence;
void vertex() {
    vec3 center = MODEL_MATRIX[3].xyz;
    float phase = elapsed * 0.034 + INSTANCE_CUSTOM.x * 6.283185;
    float gathering = 0.5 + 0.5 * sin(phase);
    presence = smoothstep(0.08, 0.4, gathering);
    center += vec3(sin(phase * 1.31), cos(phase * 1.17), sin(phase * 0.91)) * 0.35;
    float thread = INSTANCE_CUSTOM.y * 6.283185 + elapsed * 0.16;
    float scatter = 0.035 + 0.18 * (1.0 - gathering);
    center += vec3(sin(thread), cos(thread * 1.7), cos(thread)) * scatter;
    presence *= smoothstep(1.0, 1.7, distance(center, head_position));
    float size = (0.009 + INSTANCE_CUSTOM.z * 0.007) * (0.8 + 0.2 * breath_fill);
    vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
    POSITION = PROJECTION_MATRIX * vec4(view_center + vec3(VERTEX.xy * size, 0.0), 1.0);
}
void fragment() {
    float edge = 1.0 - smoothstep(0.27, 0.5, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
    ALBEDO = COLOR.rgb;
    ALPHA = visibility * presence * edge * 0.32;
}
