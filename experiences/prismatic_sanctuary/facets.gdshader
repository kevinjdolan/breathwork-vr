shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float breath_fill = 0.0;
uniform float seed = 0.0;
varying vec3 local_position;
void vertex() {
    local_position = VERTEX;
    float fill = breath_fill * breath_fill * (3.0 - 2.0 * breath_fill);
    float twist = sin(elapsed * 0.036 + seed) * 0.11 + fill * 0.085;
    float c = cos(twist * VERTEX.y);
    float s = sin(twist * VERTEX.y);
    VERTEX.xz = mat2(vec2(c,s),vec2(-s,c)) * VERTEX.xz;
    VERTEX.xz *= 1.0 - fill * 0.075;
    VERTEX.y *= 1.0 + fill * 0.08;
}
void fragment() {
    float tide = 0.83 + 0.12 * sin(elapsed * 0.055 + seed + local_position.y * 1.1);
    vec3 hue = mix(COLOR.rgb, COLOR.rgb * vec3(1.10,0.91,1.05), 0.5 + 0.5 * sin(elapsed * 0.039 + seed));
    ALBEDO = hue * tide * intensity;
}
