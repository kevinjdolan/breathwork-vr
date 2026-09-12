shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://shaders/particle_common.gdshaderinc"
uniform vec3 orb_velocity = vec3(0.0);
void start() {
    TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz+(hash3(NUMBER+RANDOM_SEED)-0.5)*0.12;
    VELOCITY = -orb_velocity*0.10;
    CUSTOM.x = 0.0;
    COLOR = vec4(1.0,0.65,0.22,0.0);
}
void process() {
    CUSTOM.x += DELTA;
    float t=clamp(CUSTOM.x/LIFETIME,0.0,1.0);
    TRANSFORM[3].xyz += VELOCITY*DELTA;
    COLOR.a = (1.0-t)*(1.0-t)*0.24;
    TRANSFORM = flowing_particle(TRANSFORM,VELOCITY,mix(0.020,0.004,t));
}
