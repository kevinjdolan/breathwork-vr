shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 mouth_position;
uniform vec3 head_position;
uniform vec3 head_right;
uniform vec3 head_up;
uniform vec3 head_forward;
uniform float elapsed;
uniform float phase_seconds;
uniform float breath_fill;
uniform float intensity = 1.0;
varying float opacity;
varying vec3 tint;
void vertex() {
    float id = INSTANCE_CUSTOM.x;
    float direction = mod(id,4.0);
    float slot = floor(id/4.0);
    // Every point has a fixed emission time, and advances at the same unhurried rate.
    float birth = 8.0+slot/127.0*3.15;
    float age = phase_seconds-birth;
    float u = clamp(age/2.7,0.0,1.0);
    vec3 side = direction<1.0 ? head_right : (direction<2.0 ? -head_right : (direction<3.0 ? head_up : -head_up));
    vec3 forward = mouth_position+head_forward*(u*4.0);
    float spread = smoothstep(.28,1.0,u);
    vec3 center = forward+side*spread*(5.1*(1.0-breath_fill*.40));
    float scatter = .012+sin(u*3.141593)*.08;
    center += (head_right*sin(id*2.4+u*9.0)+head_up*cos(id*1.9+u*6.0))*scatter;
    vec3 view = (VIEW_MATRIX*vec4(center,1)).xyz;
    float size = .004+u*.027;
    POSITION = PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*size,0),1);
    float emission = smoothstep(8.0,8.55,birth)*(1.0-smoothstep(10.45,11.2,birth));
    opacity = emission*smoothstep(0.0,.12,age)*(1.0-smoothstep(2.05,2.7,age))*intensity;
    opacity *= smoothstep(.08,.18,distance(center,head_position));
    tint = mix(vec3(.055,.40,1.0),vec3(.13,.76,1.0),INSTANCE_CUSTOM.y);
}
void fragment() {
    vec2 p = UV*2.0-1.0;
    ALBEDO = tint;
    ALPHA = exp(-dot(p,p)*3.5)*opacity*.60;
}
