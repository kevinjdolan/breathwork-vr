shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
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
float hash(float n) { return fract(sin(n*127.1)*43758.5453); }
vec3 path(float t,float id) {
    // Bounded random bends stay fixed through each exhalation and only change invisibly.
    float cycle = floor(elapsed/16.0);
    float seed = id+cycle*19.0;
    float angle = id*6.283185/16.0+(hash(seed)-.5)*.17;
    vec3 radial = head_right*cos(angle)+head_up*sin(angle);
    vec3 tangent = -head_right*sin(angle)+head_up*cos(angle);
    float reach = (4.5+hash(seed+6.0)*1.3)*(1.0-breath_fill*.40);
    vec3 end = exhale_origin+head_forward*(3.5+hash(seed+3.0)*1.8)+radial*reach;
    vec3 c1 = exhale_origin+head_forward*(1.1+hash(seed+7.0)*.4)+radial*.07;
    vec3 c2 = exhale_origin+head_forward*(3.8+hash(seed+9.0)) + radial*reach*.45 + tangent*(hash(seed+12.0)-.5)*1.7;
    float q = 1.0-t;
    return q*q*q*exhale_origin+3.0*q*q*t*c1+3.0*q*t*t*c2+t*t*t*end;
}
void vertex() {
    float t = VERTEX.x;
    float id = INSTANCE_CUSTOM.x;
    halo = INSTANCE_CUSTOM.y;
    vec3 center = path(t,id);
    vec3 tangent = normalize(path(min(.9999,t+.002),id)-path(max(.0001,t-.002),id));
    vec3 right = cross(tangent,head_up);
    if (length(right)<.01) right = head_right;
    right = normalize(right);
    vec3 up = normalize(cross(right,tangent));
    float radius = mix(.009,.030,halo)*mix(.2,1.0,smoothstep(.0,.40,t));
    center += (right*VERTEX.y+up*VERTEX.z)*radius;
    POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(center,1);
    // A leading front travels outward; the tail clears before the next green lead-in.
    float front = (phase_seconds-8.0)/1.65;
    float gate = smoothstep(8.0,8.65,phase_seconds)*(1.0-smoothstep(11.1,12.6,phase_seconds));
    opacity = gate*(1.0-smoothstep(front-.07,front+.07,t))*intensity;
    opacity *= smoothstep(.10,.32,distance(center,head_position));
    progress = t;
    tint = .52+.48*cos(6.283185*(vec3(0,.333,.667)+id/16.0+t*.30));
}
void fragment() {
    float wave = .5+.5*cos(progress*6.283185*3.0-elapsed*6.283185*.8);
    float packet = .26+.74*pow(wave,3.0);
    ALBEDO = mix(tint,tint*.65,halo);
    ALPHA = opacity*packet*mix(.70,.055,halo);
}
