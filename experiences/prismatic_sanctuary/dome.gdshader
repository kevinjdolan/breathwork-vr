shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;
uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float breath_fill = 0.0;
void fragment() {
    vec3 dir = normalize(VERTEX);
    float mist = pow(max(0.0, sin(UV.x * 18.849 + sin(UV.y * 13.0 + elapsed * 0.01))), 5.0);
    ALBEDO = (vec3(0.0015,0.0018,0.007) + vec3(0.002,0.004,0.010) * mist) * intensity;
}
