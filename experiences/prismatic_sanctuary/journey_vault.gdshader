shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/prismatic_sanctuary/vault_patterns.gdshaderinc"
uniform mat4 journey_frame;
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_disable;
uniform float elapsed = 0.0;
uniform float tempo_bpm = 60.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float hold_glow;
uniform float intensity = 1.0;
varying vec3 tint;
varying float opacity;
varying float grain_shape;

void vertex() {
    // Three interleaved cloud strata: every vertex belongs to an independent grain.
    float index = INSTANCE_CUSTOM.x;
    float stratum = floor(index/32768.0);
    float sample_id = mod(index,32768.0);
    float band = floor(sample_id/256.0);
    float azimuth = mod(sample_id,256.0);
    float a = (azimuth+(INSTANCE_CUSTOM.y-.5)*.90+stratum*.31)/256.0*VAULT_TAU;
    float depth = mod(band*.5+stratum*.167+(INSTANCE_CUSTOM.z-.5)*.43+travel,64.0)-56.0;
    float mz = depth-travel;
    vec2 uv = vec2(a/VAULT_TAU*12.0,mz*.25);
    vec2 cell = floor(uv);
    vec2 p = fract(uv)*2.0-1.0;
    float seed = vault_hash(cell);
    vec3 evolution = vault_weights(elapsed);
    float r = length(p);
    float theta = atan(p.y,p.x);
    float petal = r*(1.0+.17*cos(theta*6.0+evolution.z*.8));
    float rosette = abs(sin(petal*19.0+theta*.65+evolution.z*1.1));
    float braid = abs(sin((p.x+p.y)*15.0+.9*sin((p.x-p.y)*7.0)));
    float scroll = abs(sin(16.0*r-theta*3.0+2.0*sin(theta*3.0)+elapsed*.018));
    float pattern = mix(rosette,scroll,evolution.z*.65);
    float ridge = 1.0-smoothstep(.06,.40,pattern);
    float lace = 1.0-smoothstep(.08,.40,braid);
    vec3 jewel = vault_palette(petal*.24+cell.x*.07+cell.y*.045,elapsed);
    tint = mix(jewel*.18,jewel*.80,ridge);
    tint += lace*jewel*.16;
    float raised = ridge*.44+lace*.14;
    float ornament = 0.0;
    float eye_amount = evolution.x*step(.70,seed);
    if(eye_amount>.002) {
        float edge = max(abs(p.y)-.42*(1.0-p.x*p.x/.72),abs(p.x)-.86);
        float eye = 1.0-smoothstep(-.035,.035,edge);
        float iris = length(p*vec2(1.0,1.1));
        float rim = 1.0-smoothstep(.025,.10,abs(edge));
        vec3 iris_color = vault_palette(iris*.6+cell.y*.07,elapsed);
        iris_color *= .40+.25*sin(theta*22.0+iris*35.0);
        iris_color *= smoothstep(.09,.16,iris);
        tint = mix(tint,iris_color,eye*eye_amount);
        tint += rim*vec3(.75,.48,.12)*eye_amount;
        raised += eye*eye_amount*.65;
        ornament = rim*eye_amount;
    }
    float gecko_amount = evolution.y*step(seed,.23);
    if(gecko_amount>.002) {
        vec2 gp=p*1.12;
        if(mod(cell.x+cell.y,2.0)>.5) gp=-gp;
        float gecko = vault_gecko(gp);
        float body = 1.0-smoothstep(-.02,.03,gecko);
        float edge = 1.0-smoothstep(.02,.08,abs(gecko));
        vec3 scales=mix(vec3(.02,.34,.18),vec3(.45,.73,.13),.5+.5*sin(gp.y*34.0+cos(gp.x*32.0)));
        tint=mix(tint,scales,body*gecko_amount);
        tint+=edge*vec3(.65,.42,.12)*gecko_amount;
        raised+=body*gecko_amount*.7;
        ornament=max(ornament,edge*gecko_amount);
    }
    // Relief becomes cloud volume, with darker recesses and lifted, granular ornament.
    float curl = sin(a*24.0+mz*.83+elapsed*.075);
    float flow = sin(a*11.0-mz*.51-elapsed*.057);
    float radius = vault_radius(a,mz,elapsed,0.0);
    radius += stratum*.44 + (INSTANCE_CUSTOM.w-.5)*.48 - raised;
    radius += .16*curl*flow;
    radius = max(4.55,radius)*(1.0-breath_fill*.40);
    float angle = a+.10*sin(mz*.19634954+elapsed*.017);
    angle += (.012+.008*stratum)*sin(mz*.73+elapsed*.055+a*16.0);
    depth += .13*sin(a*19.0+elapsed*.062+mz*.45);
    vec3 world = (journey_frame*vec4(cos(angle)*radius,sin(angle)*radius,depth,1)).xyz;
    vec3 view = (VIEW_MATRIX*vec4(world,1)).xyz;
    float size = (.34+.18*INSTANCE_CUSTOM.z)*(1.0-breath_fill*.40);
    size *= 1.0+.18*stratum+.14*flow;
    float spin=INSTANCE_CUSTOM.w*VAULT_TAU+elapsed*.018;
    vec2 point=mat2(vec2(cos(spin),sin(spin)),vec2(-sin(spin),cos(spin)))*VERTEX.xy;
    POSITION=PROJECTION_MATRIX*vec4(view+vec3(point*size,0),1);
    float distance_fade=(1.0-smoothstep(19.0,44.0,-depth))*smoothstep(-56.0,-47.0,depth)*(1.0-smoothstep(5.0,8.0,depth));
    float breathing_light=1.0+hold_glow*(.18+.07*sin(elapsed*6.28318531*tempo_bpm/60.0));
    tint*=breathing_light;
    // Slow, local density eddies never clear the entire enclosing cloud wall.
    float eddy=.83+.17*sin(mz*.41+a*7.0+elapsed*.08);
    opacity=distance_fade*intensity*(.64+.18*ridge+.10*ornament)*eddy;
    grain_shape=INSTANCE_CUSTOM.y;
}
void fragment() {
    ALBEDO=tint;
    ALPHA=texture(grain_texture,UV).a*opacity;
}
