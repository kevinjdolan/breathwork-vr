// Shared aurora/IFS palette; exhaled light uses the blue-to-red segment.
vec3 meditation_palette(float value) {
    float t=clamp(value,0.0,1.0);
    vec3 green=vec3(0.07,0.8,0.32);
    vec3 teal=vec3(0.06,0.65,0.6);
    vec3 blue=vec3(0.10,0.58,1.0);
    vec3 purple=vec3(0.46,0.12,0.8);
    vec3 red=vec3(0.85,0.08,0.23);
    if(t<0.25) { return mix(green,teal,t/0.25); }
    if(t<0.45) { return mix(teal,blue,(t-0.25)/0.2); }
    if(t<0.7) { return mix(blue,purple,(t-0.45)/0.25); }
    return mix(purple,red,(t-0.7)/0.3);
}
