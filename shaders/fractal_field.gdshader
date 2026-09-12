shader_type particles;
render_mode disable_force, disable_velocity, keep_data;
#include "res://shaders/particle_common.gdshaderinc"
uniform mat4 transform_0;
uniform mat4 transform_1;
uniform mat4 transform_2;
uniform mat4 transform_3;
uniform float field_radius = 40.0;
uniform float field_amount = 0.0;
uniform vec3 head_position = vec3(0.0,1.4,0.0);
void start() {
    // Odd multiplication modulo 2^24 is a bijection: unique addresses, no
    // collisions, and all 24 bits remain exactly representable as float32.
    CUSTOM.x = float((INDEX*1048583u+7919u)&16777215u);
    CUSTOM.y = float(INDEX);
}
void process() {
    uint address = uint(CUSTOM.x);
    vec4 point = vec4(0.0,0.0,0.0,1.0);
    for (uint depth=0u; depth<12u; depth++) {
        uint branch = (address >> (depth*2u)) & 3u;
        if (branch == 0u) { point = transform_0*point; }
        else if (branch == 1u) { point = transform_1*point; }
        else if (branch == 2u) { point = transform_2*point; }
        else { point = transform_3*point; }
    }
    vec3 p = point.xyz*field_radius + vec3(0.0,2.0,0.0);
    TRANSFORM[3].xyz = p;
    float branch_color = float((address >> 22u)&3u)/3.0;
    COLOR.rgb = meditation_palette(branch_color);
    float reveal = smoothstep(hash1(uint(CUSTOM.y)+73u)*0.9,hash1(uint(CUSTOM.y)+73u)*0.9+0.1,field_amount);
    COLOR.a = reveal*smoothstep(0.8,1.4,distance(p,head_position))*field_amount*0.12;
    TRANSFORM = scaled_particle(TRANSFORM,0.009+0.012*hash1(address>>12u));
}
