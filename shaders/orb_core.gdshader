shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform float session_time = 0.0;
uniform float breath_scale = 1.0;
uniform float intensity = 1.0;
uniform float breath_fill = 0.0;
void start() { CUSTOM=vec4(hash3(INDEX+997u),hash1(INDEX+491u)); }
void process() {
    float turn=CUSTOM.x*6.283185+session_time*(0.10+CUSTOM.w*0.10);
    float vertical=CUSTOM.y*2.0-1.0;
    float petals=1.0+0.10*sin(turn*3.0+session_time*0.09)*(1.0-vertical*vertical);
    float radius=(0.040+0.095*sqrt(CUSTOM.z))*breath_scale*petals;
    float ring=sqrt(max(0.0,1.0-vertical*vertical));
    vec3 p=vec3(cos(turn)*ring,vertical,sin(turn)*ring)*radius;
    p.y+=sin(turn*2.0+CUSTOM.z*6.283185)*0.007;
    p.x*=1.0-0.07*breath_fill+0.035*sin(session_time*0.14);
    p.y*=1.0+0.13*breath_fill+0.045*sin(session_time*0.11+1.4);
    p.z*=1.0+0.055*sin(session_time*0.13+3.0);
    TRANSFORM[3].xyz=p;
    float twinkle=0.72+0.28*sin(session_time*(0.45+CUSTOM.z*0.30)+CUSTOM.x*6.28);
    float warmth=0.5+0.5*sin(session_time*0.075+CUSTOM.y*1.8+breath_fill*0.9);
    vec3 tint=mix(vec3(1.0,0.76,0.31),vec3(1.0,0.60,0.43),warmth*0.65);
    tint=mix(tint,vec3(1.0,0.9,0.65),CUSTOM.z*0.28);
    COLOR=vec4(tint,(0.12+CUSTOM.w*0.08)*twinkle*intensity);
    TRANSFORM=scaled_particle(TRANSFORM,(0.003+CUSTOM.w*0.003)*breath_scale);
}
