shader_type spatial;
render_mode unshaded;
uniform float breath_scale = 1.0;
uniform float intensity = 1.0;
void vertex() { VERTEX *= breath_scale; }
void fragment() {
    float rim = pow(clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),0.6);
    ALBEDO = mix(vec3(0.7,0.30,0.06),vec3(1.0,0.85,0.48),rim)*intensity;
}
