shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
#define LOW_QUALITY
#include "res://shaders/sky_common.gdshaderinc"
uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float ripple_amp = 0.3;
uniform float breath_phase = 0.0;
uniform float wave_height_scale = 4.0;
uniform float wave_cycle = 0.0;
uniform float breath_seconds = 0.0;
uniform vec2 breath_center = vec2(0.0);
uniform vec3 orb_position = vec3(0.0, 1.4, -3.66);
varying vec3 world_position;
varying float edge_alpha;
// Height and its analytic x/z derivatives keep displaced geometry and reflection coherent.
vec3 wave(vec2 p, vec2 direction, float frequency, float speed, float amplitude) {
    float phase = dot(p, direction)*frequency-time*speed;
    return vec3(sin(phase)*amplitude, cos(phase)*amplitude*frequency*direction);
}
vec3 surface(vec2 p) {
    // Incommensurate swells, drifting directions and long amplitude envelopes avoid a tiled beat.
    vec3 result=vec3(0.0);
    for(int i=0;i<8;i++) {
        float k=float(i);
        float angle=k*2.399963+0.24*sin(time*(0.013+k*0.003)+k);
        vec2 direction=vec2(cos(angle),sin(angle));
        float frequency=0.72*pow(1.40,k);
        float weight=(0.038*0.35/(1.0-pow(0.65,8.0)))*pow(0.65,k);
        float envelope=0.65+0.35*sin(time*(0.047+k*0.009)+k*1.83);
        result+=wave(p,direction,frequency,sqrt(frequency)*0.83,weight*envelope);
    }
    // Broad moving wind patches change local wave strength, including matching
    // derivatives so highlights travel with the actual displaced surface.
    float gust_phase=dot(p,vec2(0.31,-0.19))-time*0.11;
    float cross_phase=dot(p,vec2(0.17,0.27))+time*0.073;
    float gust=0.90+0.30*sin(gust_phase)+0.15*cos(cross_phase);
    vec2 gust_slope=0.30*cos(gust_phase)*vec2(0.31,-0.19)-0.15*sin(cross_phase)*vec2(0.17,0.27);
    result=vec3(result.x*gust,result.yz*gust+result.x*gust_slope);
    result+=wave(p,normalize(vec2(0.84,0.54)),0.33,0.21,0.010);
    result+=wave(p,normalize(vec2(0.40,-0.91)),0.48,0.29,0.006);
    vec2 offset=p-breath_center;
    float radius=max(length(offset),0.001);
    float angle=atan(offset.y,offset.x);
    float age=max(0.0,breath_seconds-6.0);
    float travel=0.6+age*(0.66+0.12*sin(wave_cycle*1.731));
    // Every release has a different broad wave packet, feathered out before the next cycle.
    float d=radius-travel;
    float frequency=4.1+0.7*sin(wave_cycle*2.17);
    float envelope=exp(-d*d*0.40)*smoothstep(0.0,0.9,age)*(1.0-smoothstep(5.5,8.0,age));
    float ripple=sin(d*frequency)*envelope*0.014;
    float slope=(cos(d*frequency)*frequency-sin(d*frequency)*0.8*d)*envelope*0.014;
    result+=vec3(ripple,offset/radius*slope);
    // 4x the former displacement ceiling; inhalation gathers the swells, exhalation releases rings.
    return result*(0.7+ripple_amp)*wave_height_scale*(0.70+0.30*breath_fill);
}

void vertex() {
    // Concentrate vertices near the seated viewer while retaining a 400 m horizon.
    vec2 unit = VERTEX.xz/200.0;
    VERTEX.xz = sign(unit)*unit*unit*200.0;
    VERTEX.y += surface(VERTEX.xz).x;
    world_position = (MODEL_MATRIX*vec4(VERTEX, 1.0)).xyz;
    edge_alpha = 1.0-smoothstep(140.0, 198.0, length(world_position.xz));
}
void fragment() {
    vec3 waves = surface(world_position.xz);
    vec2 micro = texture(ripple_normal, world_position.xz*0.27+vec2(time*0.018, -time*0.012)).rg*2.0-1.0;
    vec2 crossing=texture(ripple_normal,world_position.zx*0.43+vec2(-time*0.009,time*0.015)).rg*2.0-1.0;
    micro=micro*0.65+crossing*0.35;
    float detail = 1.0-smoothstep(12.0, 70.0, distance(world_position, CAMERA_POSITION_WORLD));
    vec3 normal = normalize(vec3(-waves.y+micro.x*0.055*detail, 1.0, -waves.z+micro.y*0.055*detail));
    vec3 incident = normalize(world_position-CAMERA_POSITION_WORLD);
    vec3 reflected = reflect(incident, normal);
    vec3 reflection = sky_color(reflected);
    float fresnel = 0.22+0.78*pow(1.0-max(0.0, dot(-incident, normal)), 3.0);
    // A reflected orb anchors its height and makes the moving wave facets readable.
    vec3 to_orb = normalize(orb_position-world_position);
    float glint = pow(max(0.0, dot(reflected, to_orb)), 280.0);
    float shimmer = pow(max(0.0, dot(reflected, to_orb)), 34.0)*0.08;
    ALBEDO = mix(vec3(0.007, 0.022, 0.034), reflection*0.92, fresnel);
    ALBEDO += vec3(1.0, 0.58, 0.16)*(glint*0.5+shimmer);
    // Keep water opaque so it cannot paint over transparent breath particles.
    ALBEDO = mix(sky_color(incident), ALBEDO, edge_alpha);
}
