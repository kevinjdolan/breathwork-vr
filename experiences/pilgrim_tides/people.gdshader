shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
#include "res://experiences/pilgrim_tides/paths.gdshaderinc"
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float visibility = 1.0;
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying vec3 person_color;
varying float face_light;
varying float distance_fade;
void vertex() {
    float group = floor(INSTANCE_CUSTOM.r * 8.0 + 0.01);
    float seed = INSTANCE_CUSTOM.g;
    float phase = seed + elapsed * (0.004 + 0.00017 * group);
    // Stable density waves gather the procession without changing walking speed abruptly.
    phase += 0.012 * breath_fill * sin(seed * 18.84956 + group);
    vec3 center = path_point(group, phase, breath_fill, elapsed);
    vec3 up = path_up(group);
    vec3 forward = normalize(path_point(group, phase + 0.001, breath_fill, elapsed) - center);
    vec3 right = normalize(cross(up, forward));
    float walk = elapsed * (1.1 + 0.21 * INSTANCE_CUSTOM.b) + seed * 97.0;
    vec3 local = VERTEX;
    if (local.y < 0.44) local.z += sin(walk + (local.x > 0.0 ? 3.14159 : 0.0)) * 0.075 * (1.0 - local.y / 0.44);
    if (abs(local.x) > 0.19 && local.y > 0.4 && local.y < 0.8) {
        local.z += sin(walk + (local.x > 0.0 ? 0.0 : 3.14159)) * 0.07;
        local.x *= 1.0 - 0.16 * breath_fill;
        local.y += 0.12 * breath_fill;
        local.z += 0.08 * breath_fill;
    }
    local.y += 0.012 * sin(walk * 2.0);
    float size = 0.30 + 0.08 * INSTANCE_CUSTOM.b;
    center += right * (INSTANCE_CUSTOM.a - 0.5) * 0.25;
    VERTEX = center + (right * local.x + up * local.y + forward * local.z) * size;
    face_light = 0.63 + 0.37 * max(dot(NORMAL, normalize(vec3(-0.5, 0.8, 0.7))), 0.0);
    person_color = COLOR.rgb;
    distance_fade = smoothstep(0.9, 1.7, distance(center, head_position));
}
void fragment() {
    ALBEDO = person_color * face_light * visibility * distance_fade * 0.82;
}
