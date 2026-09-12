shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform float session_time = 0.0;
uniform float burst = 0.0;
uniform float breath_fill = 0.0;
void start() {
    CUSTOM = vec4(hash3(INDEX+93u),hash1(INDEX+501u));
}
void process() {
    float angle = CUSTOM.x*6.283185 + session_time*(0.08+CUSTOM.z*0.1);
    float lobes=mix(sin(angle*2.0+session_time*0.09),sin(angle*3.0-session_time*0.07),0.5+0.5*sin(session_time*0.043));
    float radius = (0.17 + CUSTOM.y*0.18)*(1.0-0.20*breath_fill)*(1.0+lobes*0.12);
    float pulse = INDEX < 40u ? burst : 0.0;
    radius += pulse*0.025;
    float vertical=1.12+0.11*sin(session_time*0.08)+0.13*breath_fill;
    TRANSFORM[3].xyz = vec3(cos(angle)*radius, sin(angle*1.7+CUSTOM.z*6.28)*radius*vertical, sin(angle)*radius*(1.0+0.08*cos(session_time*0.065)));
    float warmth=0.5+0.5*sin(session_time*0.065+CUSTOM.z*2.0);
    vec3 tint=mix(vec3(1.0,0.72,0.29),vec3(1.0,0.58,0.48),warmth*0.6);
    COLOR = vec4(tint,0.05+pulse*0.02);
    TRANSFORM = scaled_particle(TRANSFORM,0.008+CUSTOM.w*0.014);
}
