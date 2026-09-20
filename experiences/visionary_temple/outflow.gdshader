shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Sixteen violet-to-cyan petals leave the shared neck center over the six-second exhale.
uniform vec3 exhale_origin;
uniform vec3 head_position;
uniform vec3 head_right;
uniform vec3 head_up;
uniform vec3 head_forward;
uniform float elapsed;
uniform float phase_seconds;
uniform float breath_fill;
uniform float intensity = 1.0;
varying float opacity;
varying float halo;
varying float progress;
varying vec3 tint;
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
vec3 path(float t, float id) {
    // Bounded random bends stay fixed through each exhalation and only change invisibly.
    float cycle = floor(elapsed / 16.0);
    float seed = id + cycle * 19.0;
    float angle = id * 6.283185 / 16.0 + (hash(seed) - 0.5) * 0.17;
    vec3 radial = head_right * cos(angle) + head_up * sin(angle);
    vec3 tangent = -head_right * sin(angle) + head_up * cos(angle);
    float reach = (3.6 + hash(seed + 6.0) * 1.1) * (1.0 - breath_fill * 0.35);
    vec3 end = exhale_origin + head_forward * (3.6 + hash(seed + 3.0) * 1.8) + radial * reach;
    vec3 c1 = exhale_origin + head_forward * (1.1 + hash(seed + 7.0) * 0.4) + radial * 0.07;
    vec3 c2 = exhale_origin + head_forward * (3.8 + hash(seed + 9.0)) + radial * reach * 0.45 + tangent * (hash(seed + 12.0) - 0.5) * 1.7;
    float q = 1.0 - t;
    return q * q * q * exhale_origin + 3.0 * q * q * t * c1 + 3.0 * q * t * t * c2 + t * t * t * end;
}
void vertex() {
    float t = VERTEX.x;
    float id = INSTANCE_CUSTOM.x;
    halo = INSTANCE_CUSTOM.y;
    vec3 center = path(t, id);
    vec3 tangent = normalize(path(min(0.9999, t + 0.002), id) - path(max(0.0001, t - 0.002), id));
    vec3 right = cross(tangent, head_up);
    if (length(right) < 0.01) right = head_right;
    right = normalize(right);
    vec3 up = normalize(cross(right, tangent));
    float radius = mix(0.009, 0.030, halo) * mix(0.2, 1.0, smoothstep(0.0, 0.40, t));
    center += (right * VERTEX.y + up * VERTEX.z) * radius;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(center, 1.0);
    // The front travels outward over 2.2 s; everything clears before the 14.5 s lead-in.
    float front = (phase_seconds - 8.0) / 2.2;
    float gate = smoothstep(8.0, 8.65, phase_seconds) * (1.0 - smoothstep(12.6, 14.3, phase_seconds));
    opacity = gate * (1.0 - smoothstep(front - 0.07, front + 0.07, t)) * intensity;
    opacity *= smoothstep(0.10, 0.32, distance(center, head_position));
    progress = t;
    tint = mix(vec3(0.55, 0.20, 0.98), vec3(0.20, 0.85, 1.0), 0.5 + 0.5 * cos(id * 0.7854 + t * 3.0));
    tint = mix(tint, vec3(0.98, 0.45, 0.85), 0.5 + 0.5 * sin(id * 1.9));
}
void fragment() {
    float wave = 0.5 + 0.5 * cos(progress * 6.283185 * 3.0 - elapsed * 6.283185 * 0.8);
    float packet = 0.26 + 0.74 * pow(wave, 3.0);
    ALBEDO = mix(tint, tint * 0.65, halo);
    ALPHA = opacity * packet * mix(0.70, 0.055, halo);
}
