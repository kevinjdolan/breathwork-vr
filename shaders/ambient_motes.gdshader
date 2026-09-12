shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform float session_time = 0.0;
uniform vec3 head_position = vec3(0.0,1.4,0.0);
uniform float visibility = 0.0;
uniform vec3 cluster_centers[5];
uniform vec2 cluster_lives[5];
uniform vec3 cluster_colors[5];
float noise3(vec3 p) {
    vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
    vec3 stride=vec3(1.0,57.0,113.0);
    float n=dot(i,stride);
    vec4 a=fract(sin(vec4(n,n+1.0,n+57.0,n+58.0))*43758.5453);
    vec4 b=fract(sin(vec4(n+113.0,n+114.0,n+170.0,n+171.0))*43758.5453);
    return mix(mix(mix(a.x,a.y,f.x),mix(a.z,a.w,f.x),f.y),mix(mix(b.x,b.y,f.x),mix(b.z,b.w,f.x),f.y),f.z);
}
void start() { CUSTOM=vec4(hash3(INDEX+803u),hash1(INDEX+1201u)); }
vec3 constellation(float age, float duration, vec4 attributes) {
    float gather=smoothstep(0.0,4.5,age);
    float unravel=smoothstep(duration-6.0,duration-0.8,age);
    float turn=attributes.x*6.283185+age*(0.20+attributes.w*0.12)+(1.0-gather)*2.8+unravel*2.2;
    float vertical=attributes.y*2.0-1.0;
    float ring=sqrt(max(0.0,1.0-vertical*vertical));
    float nucleus=0.085+attributes.z*0.085;
    float radius=nucleus+(1.0-gather)*(0.22+attributes.w*0.22)+unravel*(0.32+attributes.z*0.26);
    float petals=1.0+0.18*sin(turn*3.0+attributes.y*6.28);
    vec3 p=vec3(cos(turn)*ring*petals,vertical*1.25,sin(turn)*ring)*radius;
    p.y+=unravel*attributes.w*0.32;
    vec3 seed=attributes.xyz*6.0;
    float t=session_time*0.12;
    vec3 drift=vec3(noise3(seed+vec3(t,0.0,0.0)),noise3(seed+vec3(0.0,t,7.0)),noise3(seed+vec3(9.0,0.0,t)))-0.5;
    return p+drift*0.04;
}
void process() {
    int cluster=int(INDEX%5u);
    float age=cluster_lives[cluster].x;
    float duration=cluster_lives[cluster].y;
    vec3 offset=constellation(age,duration,CUSTOM);
    vec3 p=cluster_centers[cluster]+offset;
    TRANSFORM[3].xyz=p;
    float appear=smoothstep(0.2+CUSTOM.y*0.7,2.5+CUSTOM.y*0.7,age);
    float disappear=1.0-smoothstep(duration-4.0-CUSTOM.z,duration-0.8-CUSTOM.z*0.4,age);
    float twinkle=0.72+0.28*sin(session_time*(0.35+CUSTOM.w*0.15)+CUSTOM.z*6.28);
    vec3 tint=mix(cluster_colors[cluster],vec3(0.9,0.88,1.0),CUSTOM.y*0.23);
    COLOR=vec4(tint,0.10*twinkle*appear*disappear*visibility);
    COLOR.a*=smoothstep(0.85,1.5,distance(p,head_position));
    TRANSFORM=scaled_particle(TRANSFORM,0.004+CUSTOM.w*0.003);
}
