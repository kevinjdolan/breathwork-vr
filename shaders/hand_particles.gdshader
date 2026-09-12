shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform vec4 joints[26];
uniform float confidence[26];
uniform float session_time = 0.0;
uniform float visibility = 0.0;
uniform vec3 head_position = vec3(0.0);

void start() {
    CUSTOM=vec4(hash3(INDEX+901u),hash1(INDEX+3001u));
}

void process() {
    vec3 p;
    float tracked;
    float angle=CUSTOM.y*6.283185+session_time*(0.22+CUSTOM.w*0.18);
    if (INDEX<576u) {
        // Twenty-four skeletal links, with 24 small orbiting sparks per link.
        int joint=2+int(INDEX/24u);
        int parent=joint-1;
        if (joint==2 || joint==6 || joint==11 || joint==16 || joint==21) { parent=1; }
        float along=(float(INDEX%24u)+CUSTOM.x)/24.0;
        vec3 axis=normalize(joints[joint].xyz-joints[parent].xyz+vec3(0.000001));
        vec3 guide=abs(axis.y)>0.9 ? vec3(1.0,0.0,0.0) : vec3(0.0,1.0,0.0);
        vec3 side=normalize(cross(axis,guide));
        vec3 up=cross(axis,side);
        float radius=mix(joints[parent].w,joints[joint].w,along)*(0.55+0.45*CUSTOM.z);
        p=mix(joints[parent].xyz,joints[joint].xyz,along);
        p+=(side*cos(angle)+up*sin(angle))*radius;
        tracked=min(confidence[joint],confidence[parent]);
    } else {
        // A filled, softly stippled palm fan, rather than a skeletal wireframe.
        int wedge=int((INDEX-576u)/48u);
        int a=3;
        if (wedge>0) { a=7+(wedge-1)*5; }
        int b=7+wedge*5;
        float radial=sqrt(CUSTOM.x);
        vec3 edge=mix(joints[a].xyz,joints[b].xyz,CUSTOM.y);
        p=mix(joints[1].xyz,edge,radial);
        vec3 normal=normalize(cross(joints[a].xyz-joints[1].xyz,joints[b].xyz-joints[1].xyz)+vec3(0.000001));
        p+=normal*(CUSTOM.z-0.5)*0.014;
        tracked=min(confidence[1],min(confidence[a],confidence[b]));
    }
    // Millimetre-scale shimmer preserves hand shape; loss dissolves in place.
    p+=vec3(sin(angle*1.3),cos(angle*0.7),sin(angle+CUSTOM.z*6.28))*(0.0015+(1.0-tracked)*0.018);
    float near_fade=smoothstep(0.09,0.19,distance(p,head_position));
    float shimmer=0.8+0.2*sin(session_time*1.1+CUSTOM.w*6.283185);
    TRANSFORM[3].xyz=p;
    TRANSFORM=scaled_particle(TRANSFORM,0.0015+CUSTOM.w*0.0008);
    COLOR=vec4(mix(vec3(0.69,0.85,1.0),vec3(1.0,0.88,0.59),CUSTOM.z),tracked*visibility*near_fade*shimmer*0.30);
}
