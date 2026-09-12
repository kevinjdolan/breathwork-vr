shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float time = 0.0;
uniform float layer = 0.0;
uniform float breath_fill = 0.0;
uniform float release_wave = 0.0;
uniform float aurora_intensity = 0.3;
uniform float fractal_mix = 0.0;
varying float angle_world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
}
void vertex() {
    float angle=atan(VERTEX.z,VERTEX.x);
    angle_world=angle;
    float fold=sin(angle*3.0+time*0.085+layer)*0.65+sin(angle*7.0-time*0.043+layer*2.0)*0.28;
    vec2 radial=normalize(VERTEX.xz);
    VERTEX.xz+=radial*(fold*(0.5+UV.y)-breath_fill*(0.35+layer*0.08));
    VERTEX.y+=sin(angle*2.0+time*0.047+layer)*0.6+sin(angle*5.0-time*0.031)*0.24;
    VERTEX.y+=UV.y*breath_fill*0.8;
}
void fragment() {
    float drift=time*(0.075+layer*0.018);
    vec2 around=vec2(sin(angle_world),cos(angle_world));
    float filament=noise(around*(45.0+layer*11.0)+vec2(drift,layer*13.0));
    float wisps=noise(around*12.0+vec2(drift*0.4,UV.y*1.8));
    float crown=pow(1.0-UV.y,1.7)*smoothstep(0.0,0.045,UV.y);
    float fine=0.22+0.78*pow(filament,1.4);
    float broken=0.35+0.65*wisps;
    float pulse=0.82+0.18*breath_fill+release_wave*0.10*sin(angle_world*2.0-time*0.4+layer);
    vec3 jade=vec3(0.12,0.80,0.55);
    vec3 blue=vec3(0.15,0.46,0.86);
    vec3 violet=vec3(0.50,0.19,0.76);
    vec3 color=mix(mix(jade,blue,layer*0.32),violet,smoothstep(0.10,0.75,UV.y));
    float hem=exp(-abs(UV.y-0.06)*48.0)*0.12;
    ALBEDO=color;
    ALPHA=(crown*fine*broken+hem)*pulse*(0.20+aurora_intensity*0.23)*(1.0-fractal_mix*0.65);
}
