shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float visibility = 1.0;
uniform float breath_fill = 0.0;
uniform vec3 seed_centers[5];
uniform vec3 head_position = vec3(0.0, 1.4, 0.0);
varying float shimmer;
varying float near_fade;
varying float unfurl;
void vertex() {
    vec3 original = MODEL_MATRIX[3].xyz;
    float growth = 0.62 + 0.57 * sin(elapsed * 0.043 + INSTANCE_CUSTOM.x * 14.4);
    unfurl = 0.27 + 0.73 * smoothstep(INSTANCE_CUSTOM.y - 0.17, INSTANCE_CUSTOM.y + 0.17, growth);
    vec3 center = original;
    center.xz *= 1.0 + 0.025 * breath_fill;
    center.x += 0.09 * sin(elapsed * 0.13 + original.y * 0.53 + original.z * 0.2);
    center.z += 0.075 * cos(elapsed * 0.11 + original.y * 0.47 + original.x * 0.2);
    center.y += 0.025 * sin(elapsed * 0.17 + original.x * 0.9);
    if (INSTANCE_CUSTOM.a < 0.5) {
        int group = int(INSTANCE_CUSTOM.x + 0.1);
        vec3 anchor = seed_centers[group];
        vec3 local = original - anchor;
        float age = elapsed * (0.10 + float(group) * 0.006) + float(group) * 1.85;
        float gathering = 0.5 + 0.5 * sin(age);
        float angle = (1.0 - gathering) * 2.0 + elapsed * 0.045;
        float c = cos(angle);
        float s = sin(angle);
        local.xz = mat2(vec2(c, -s), vec2(s, c)) * local.xz;
        local *= 0.55 + gathering * 0.72 + breath_fill * 0.08;
        local += (1.0 - gathering) * 0.17 * vec3(sin(INSTANCE_CUSTOM.y * 6.28 + age), cos(INSTANCE_CUSTOM.z * 6.28 + age * 0.7), sin(INSTANCE_CUSTOM.z * 9.0 - age));
        center = anchor + local + 0.13 * vec3(sin(age * 0.47), cos(age * 0.33), sin(age * 0.39));
        // The entire compact form gathers into a legible tetrahedral fern seed.
        // Dissolution redistributes points locally before the next soft gathering.
        unfurl = 0.35 + 0.65 * smoothstep(0.03, 0.68, gathering);
    }
    shimmer = 0.84 + 0.16 * sin(elapsed * 0.31 + original.y * 0.8 + original.x * 0.43);
    near_fade = smoothstep(0.7, 1.4, distance(center, head_position));
    float size = length(MODEL_MATRIX[0].xyz) * (1.0 + 0.22 * breath_fill);
    vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
    MODELVIEW_MATRIX = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size * 1.45, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(view_center, 1.0));
}
void fragment() {
    vec2 q = UV * 2.0 - 1.0;
    float seed = exp(-dot(q, q) * 3.8) * (1.0 - smoothstep(0.65, 1.0, length(q)));
    ALBEDO = mix(COLOR.rgb * 1.10, COLOR.rgb * vec3(1.13, 1.02, 0.92), breath_fill);
    ALPHA = seed * COLOR.a * visibility * shimmer * near_fade * unfurl;
}
