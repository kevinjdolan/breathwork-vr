shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://experiences/pilgrim_tides/paths.gdshaderinc"
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float visibility = 1.0;
void vertex() {
    float group = UV2.x;
    vec3 center = path_point(group, UV.x, breath_fill, elapsed);
    vec3 forward = normalize(path_point(group, UV.x + 0.001, breath_fill, elapsed) - center);
    vec3 right = normalize(cross(path_up(group), forward));
    VERTEX = center + right * (UV.y - 0.5) * 0.44 - path_up(group) * 0.016;
}
void fragment() {
    float rim = smoothstep(0.38, 0.49, abs(UV.y - 0.5));
    float filament = pow(0.5 + 0.5 * sin(UV.x * 37.699 + elapsed * 0.11), 3.0);
    vec3 base = mix(vec3(0.025, 0.065, 0.075), vec3(0.16, 0.20, 0.24), UV2.x / 8.0);
    ALBEDO = (base + rim * vec3(0.22, 0.38, 0.40) * (0.7 + 0.3 * filament)) * visibility;
}
