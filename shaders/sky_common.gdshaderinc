#include "res://shaders/palette.gdshaderinc"
uniform float time = 0.0;
uniform float aurora_intensity = 0.3;
uniform float aurora_saturation = 0.0;
uniform float fractal_mix = 0.0;
uniform vec4 fractal_params = vec4(0.82,0.62,0.0,0.0);
uniform float fractal_fold = 3.0;
uniform float breath_energy = 0.0;
uniform float breath_fill = 0.0;
uniform float release_wave = 0.0;
uniform int slab_samples = 4;

float sky_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float sky_noise(vec2 p) {
    vec2 cell=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(sky_hash(cell),sky_hash(cell+vec2(1,0)),f.x),mix(sky_hash(cell+vec2(0,1)),sky_hash(cell+vec2(1,1)),f.x),f.y);
}
float sky_fbm(vec2 p) {
    float sum=0.0; float amplitude=0.5;
    #ifdef LOW_QUALITY
    const int OCTAVES=2;
    #else
    const int OCTAVES=3;
    #endif
    for(int i=0;i<OCTAVES;i++) { sum+=amplitude*sky_noise(p); p=mat2(vec2(1.6,1.2),vec2(-1.2,1.6))*p+3.7; amplitude*=0.5; }
    return sum;
}
vec3 aurora_palette(float height) { return meditation_palette(height+aurora_saturation*0.22); }
vec3 sky_color(vec3 direction) {
    vec3 rd=normalize(direction);
    float elevation=max(rd.y,0.0);
    vec3 base=mix(vec3(0.013,0.026,0.042),vec3(0.003,0.006,0.023),smoothstep(0.0,0.65,elevation));
    vec2 star_uv=vec2(atan(rd.x,rd.z),asin(clamp(rd.y,-1.0,1.0)))*350.0;
    float star=pow(sky_hash(floor(star_uv)),160.0)*pow(max(0.0,1.0-length(fract(star_uv)-0.5)*2.0),5.0);
    base+=star*0.22*smoothstep(0.0,0.3,elevation);
    if(rd.y<=0.015) { return base; }
    #ifdef LOW_QUALITY
    int samples=3;
    #else
    int samples=slab_samples;
    #endif
    vec3 aurora=vec3(0.0);
    float drift=time*0.045;
    float azimuth=atan(rd.x,-rd.z);
    float altitude=asin(clamp(rd.y,0.0,1.0));
    // Separate flowing ribbons: a bright lower hem, vertical rays and a diffuse crown.
    // Use periodic angular coordinates so the panorama also joins behind the viewer.
    vec2 around=vec2(sin(azimuth),cos(azimuth));
    for(int i=0;i<3;i++) {
        float layer=float(i);
        float flow=drift*(0.7+layer*0.24)+layer*2.1;
        float fold=sin(azimuth*2.0+flow)*0.10+sin(azimuth*5.0-flow*0.63+layer)*0.045;
        float hem=0.22+layer*0.29+fold-breath_fill*0.045;
        float above=altitude-hem;
        float rays=sky_fbm(around*(18.0+layer*5.0)+vec2(flow*1.4,layer*9.0));
        float fine=sky_noise(around*85.0+vec2(flow*2.1,layer*17.0));
        float strands=0.22+0.95*rays+0.28*fine;
        float veil=smoothstep(-0.035,0.026,above)*exp(-max(0.0,above)*(5.5+layer));
        float edge=exp(-abs(above)*48.0)*0.23;
        float opening=0.58+0.42*sin(azimuth+layer*2.0+flow*0.35);
        vec3 lower=mix(vec3(0.10,0.86,0.56),vec3(0.08,0.55,0.94),layer*0.28);
        vec3 upper=vec3(0.49,0.14,0.72);
        vec3 ribbon=mix(lower,upper,smoothstep(0.03,0.34,above));
        ribbon=mix(ribbon,aurora_palette(layer*0.25+above),aurora_saturation*0.3);
        aurora+=ribbon*(veil*strands+edge)*opening*(0.88+0.20*breath_fill+0.06*release_wave);
    }
    aurora*=aurora_intensity*(1.0+min(breath_energy,3.0)*0.035)*1.7;
    if (fractal_mix < 0.001) {
        vec3 color = base+aurora;
        return clamp(color/(1.0+color*0.65),vec3(0.0),vec3(0.65));
    }
    // The same curtain domain dissolves geometry at zero; its influence
    // decreases continuously as the orbit-trap structure crystallizes.
    vec2 domain=vec2(atan(rd.x,-rd.z),asin(rd.y))*1.35;
    vec2 warp=vec2(sky_fbm(domain+drift),sky_fbm(domain+vec2(7.0,-drift)))-0.4;
    vec2 z=domain+warp*(1.0-fractal_mix)*3.0;
    float angle=atan(z.y,z.x); float radius=length(z);
    // Continuous cosine fold avoids seams when the animated fold is fractional.
    z=vec2(cos(angle*fractal_fold),abs(sin(angle*fractal_fold)))*radius;
    float trap=10.0;
    float structure=0.0;
    for(int j=0;j<6;j++) {
        z=abs(z)/max(dot(z,z),0.22)-fractal_params.xy;
        trap=min(trap,abs(length(z)-0.7));
        structure+=exp(-abs(length(z)-0.8)*3.0)/6.0;
    }
    float filaments=0.65*structure+0.35*(1.0-smoothstep(0.01,0.12+fwidth(trap)*2.0,trap));
    vec3 fractal=aurora_palette(0.5+0.35*sin(domain.x*1.4+domain.y*2.0+structure*2.0))*filaments*0.48;
    fractal*=smoothstep(0.03,0.2,elevation);
    float blend=fractal_mix*fractal_mix*(3.0-2.0*fractal_mix);
    vec3 color=base+mix(aurora,fractal,blend);
    // Soft radiance ceiling, with slow parameter motion supplied by Director.
    return clamp(color/(1.0+color*0.65),vec3(0.0),vec3(0.65));
}
