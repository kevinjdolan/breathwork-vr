shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float cycle_angle = 0.0;
uniform vec3 neuron_centers[48];
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying vec3 tint;
varying float brightness;
void vertex() {
    vec4 a = INSTANCE_CUSTOM;
    vec3 p = MODEL_MATRIX[3].xyz;
    float life = 0.5 + 0.5 * sin(elapsed * 0.16 + a.x * 37.0);
    float gathering = smoothstep(0.07, 0.60, life);
    if (a.z < 0.3) {
        int index = clamp(int(round(a.x * 48.0)), 0, 47);
        vec3 center = neuron_centers[index];
        vec3 local = p - center;
        float angle = elapsed * 0.075 + a.x * 2.0;
        float lobe = 1.0 + 0.18 * sin(atan(local.z, local.x) * 3.0 + elapsed * 0.15 + a.x * 6.283);
        local.xz = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * local.xz * lobe;
        local.y *= 1.0 + 0.14 * sin(elapsed * 0.11 + a.x * 4.0);
        p = center + local;
    }
    float wave = pow(0.5 + 0.5 * sin(a.y * 5.0 - cycle_angle + a.x * 6.283), 5.0);
    vec3 drift = 0.045 * vec3(sin(elapsed * 0.11 + p.y), sin(elapsed * 0.087 + p.x), cos(elapsed * 0.096 + p.y));
    p += drift;
    if (a.z < 0.9) {
        float dissolve = 1.0 - gathering;
        p += dissolve * vec3(cos(a.y * 25.0 + elapsed * 0.1), sin(a.y * 21.0), sin(a.y * 17.0 + elapsed * 0.1)) * 0.30;
    }
    vec3 view_center = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
    float size = length(MODEL_MATRIX[0].xyz) * (1.0 + 0.25 * breath_fill);
    POSITION = PROJECTION_MATRIX * vec4(view_center + vec3(VERTEX.xy * size, 0.0), 1.0);
    tint = COLOR.rgb;
    brightness = mix((0.055 + 0.77 * gathering) * (0.65 + 0.35 * breath_fill), 0.05 + wave * (0.45 + breath_fill * 0.32), step(0.9, a.z));
    brightness *= intensity * smoothstep(1.3, 2.2, distance(p, head_position));
}
void fragment() {
    float radius = length(UV * 2.0 - 1.0);
    ALBEDO = tint;
    ALPHA = pow(max(0.0, 1.0 - radius), 1.4) * brightness;
}
