shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform float exhale_reach = 0.4;
uniform vec3 head_position = vec3(0.0,1.4,0.0);
uniform vec3 mouth_position = vec3(0.0,1.32,-0.06);
uniform mat3 mouth_basis;
uniform float exhale_visibility = 0.0;
uniform bool exhale_active = false;
void start() {
    vec3 random = hash3(NUMBER+RANDOM_SEED);
    float angle = random.x*6.283185;
    float spread = sqrt(random.y)*0.18;
    vec3 direction = normalize(vec3(cos(angle)*spread,sin(angle)*spread,-1.0));
    VELOCITY = mouth_basis*direction*mix(0.72,1.02,random.z);
    TRANSFORM[3].xyz = mouth_position;
    CUSTOM = vec4(0.0,random);
    COLOR = vec4(0.13,0.68,1.0,0.0);
}
void process() {
    CUSTOM.x += DELTA;
    float age = CUSTOM.x;
    VELOCITY.xz *= exp(-DELTA*0.24);
    VELOCITY.y += smoothstep(0.65,2.3,age)*(0.20+exhale_reach*0.16)*DELTA;
    vec3 p = TRANSFORM[3].xyz;
    // Curl into loosely braided wisps rather than expanding into a uniform spray.
    vec3 axis=normalize(vec3(VELOCITY.x,0.0,VELOCITY.z)+vec3(0.00001));
    vec3 side=cross(axis,vec3(0.0,1.0,0.0));
    float strand=floor(CUSTOM.y*3.0)*2.094395;
    float turn=age*1.25+strand;
    float spread=smoothstep(0.2,1.4,age)*(1.0-smoothstep(3.2,4.8,age));
    vec3 turbulence=(side*sin(turn)+vec3(0.0,cos(turn),0.0))*0.16*spread;
    turbulence+=side*sin(age*0.47+CUSTOM.z*6.28)*0.045;
    vec3 travel = VELOCITY+turbulence;
    TRANSFORM[3].xyz += travel*DELTA;
    float t = clamp(age/LIFETIME,0.0,1.0);
    COLOR.rgb = mix(vec3(0.12,0.64,1.0),vec3(0.46,0.24,0.88),smoothstep(0.4,1.0,t));
    COLOR.a = smoothstep(0.0,0.10,age)*(1.0-smoothstep(0.48,1.0,t))*0.34*exhale_visibility;
    COLOR.a *= smoothstep(0.10,0.20,distance(p,head_position));
    if (!exhale_active || age>=LIFETIME) { ACTIVE=false; }
    TRANSFORM = flowing_particle(TRANSFORM,travel,mix(0.016,0.034,t));
}
