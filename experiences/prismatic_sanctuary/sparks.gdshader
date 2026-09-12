shader_type particles;
render_mode disable_force, disable_velocity;
uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float breath_fill = 0.0;
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void start() { CUSTOM = vec4(hash(float(INDEX)+1.0),hash(float(INDEX)+99.0),hash(float(INDEX)+197.0),hash(float(INDEX)+397.0)); }
void process() {
    float angle = CUSTOM.x * 6.283185 + elapsed * 0.004;
    float elevation = CUSTOM.y * 1.65 - 0.25;
    float radius = 3.3 + CUSTOM.z * CUSTOM.z * 22.0;
    vec3 pos = vec3(cos(angle)*cos(elevation), sin(elevation),sin(angle)*cos(elevation))*radius;
    pos.y += 1.4;
    pos += vec3(sin(elapsed * 0.055 + CUSTOM.w * 14.0),cos(elapsed * 0.043 + CUSTOM.x * 13.0),sin(elapsed * 0.037 + CUSTOM.z * 12.0)) * 0.20;
    pos *= 1.0 - breath_fill * 0.018;
    float size = 0.009 + CUSTOM.w * 0.012;
    TRANSFORM = mat4(vec4(size,0,0,0),vec4(0,size,0,0),vec4(0,0,size,0),vec4(pos,1));
    vec3 color = mix(vec3(0.13,0.63,1.0),vec3(0.92,0.29,0.11),smoothstep(0.25,0.85,CUSTOM.w));
    float shimmer = 0.60 + 0.20*sin(elapsed * 0.19 + CUSTOM.y * 31.0);
    COLOR = vec4(color, shimmer * intensity * 0.55);
}
