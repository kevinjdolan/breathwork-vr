shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float breath_fill = 0.0;
uniform float seed = 0.0;
void vertex() {
    float fill = breath_fill * breath_fill * (3.0 - 2.0 * breath_fill);
    VERTEX.xy *= 1.0 - fill * 0.065;
    VERTEX.z += sin(VERTEX.x * 0.6 + elapsed * 0.09 + seed) * 0.16;
}
void fragment() {
    float tide = 0.84 + 0.12 * sin(elapsed * 0.07 + seed + VERTEX.x * 0.2);
    ALBEDO = COLOR.rgb * tide * intensity;
}
