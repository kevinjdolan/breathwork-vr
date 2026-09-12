#include "res://shaders/palette.gdshaderinc"
uint hash_uint(uint x) {
    x = ((x >> 16u) ^ x) * 73244475u;
    x = ((x >> 16u) ^ x) * 73244475u;
    return (x >> 16u) ^ x;
}
float hash1(uint x) { return float(hash_uint(x) & 16777215u) / 16777216.0; }
vec3 hash3(uint x) { return vec3(hash1(x), hash1(x + 41u), hash1(x + 137u)); }
vec3 branch_palette(float t) { return meditation_palette(0.45+0.55*t); }
mat4 scaled_particle(mat4 source, float size) {
    source[0] = vec4(size,0.0,0.0,0.0);
    source[1] = vec4(0.0,size,0.0,0.0);
    source[2] = vec4(0.0,0.0,size,0.0);
    return source;
}

mat4 flowing_particle(mat4 source, vec3 direction, float size) {
    vec3 tangent=normalize(direction+vec3(0.000001));
    vec3 axis=abs(tangent.y)>0.95 ? vec3(1.0,0.0,0.0) : vec3(0.0,1.0,0.0);
    vec3 side=normalize(cross(tangent,axis));
    source[0]=vec4(tangent*size,0.0);
    source[1]=vec4(side*size,0.0);
    source[2]=vec4(cross(tangent,side)*size,0.0);
    return source;
}
