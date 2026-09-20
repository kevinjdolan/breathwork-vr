shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform vec3 inhale_target;
uniform vec3 orb_position = vec3(0.0,1.4,-1.8288);
uniform vec3 head_right = vec3(1.0,0.0,0.0);
uniform vec3 head_up = vec3(0.0,1.0,0.0);
uniform bool inhale_active = true;
uniform float inhale_visibility = 0.0;
uniform float inhale_seconds = 0.0;
uniform float inhale_front = 0.0;
void start() {
    // Continuous motion across the breath boundary; visibility reveals the route.
    CUSTOM = vec4((float(INDEX)+0.5)/600.0,hash1(INDEX+71u),hash1(INDEX+331u),hash1(INDEX+827u));
}
vec3 path(float progress, float lane, vec3 side) {
    // Ease toward the breath center throughout the trip; no phase-end acceleration.
    float t=1.0-pow(1.0-progress,1.5);
    float spread=sin(t*3.141593);
    vec3 p=mix(orb_position,inhale_target,t);
    p+=side*lane*spread-head_up*0.12*spread;
    return p;
}
void process() {
    float travel_seconds=4.8+CUSTOM.w*0.8;
    float progress=fract(CUSTOM.x+inhale_seconds/travel_seconds);
    float lane=(CUSTOM.y<0.5 ? -1.0 : 1.0)*(0.16+CUSTOM.z*0.06);
    vec3 side=normalize(head_right);
    vec3 p=path(progress,lane,side);
    vec3 tangent=path(min(progress+0.002,0.9999),lane,side)-path(max(0.0,progress-0.002),lane,side);
    float distance_to_center=distance(p,inhale_target);
    float envelope=smoothstep(0.0,0.10,progress)*(1.0-smoothstep(0.96,1.0,progress));
    float near_fade=smoothstep(0.018,0.055,distance_to_center);
    float lead_reveal=1.0-smoothstep(max(0.0,inhale_front-0.14),max(0.001,inhale_front),progress);
    TRANSFORM[3].xyz=p;
    COLOR=vec4(1.0,0.77+CUSTOM.y*0.10,0.32,0.20*envelope*near_fade*inhale_visibility*lead_reveal);
    // Keep the 600-point capacity, with a sparse visible subset in each ribbon.
    if (!inhale_active || CUSTOM.z>0.38) { COLOR.a=0.0; }
    float size=0.003+0.015*smoothstep(0.08,1.3,distance_to_center);
    TRANSFORM=flowing_particle(TRANSFORM,tangent,size);
}
