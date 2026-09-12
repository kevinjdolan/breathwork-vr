shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled, fog_disabled;
#include "res://experiences/prismatic_sanctuary/vault_patterns.gdshaderinc"
uniform mat4 journey_frame;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float hold_glow;
uniform float intensity = 1.0;
varying vec2 surface_uv;
varying float opacity;
varying float relief;
void vertex() {
    float index = INSTANCE_CUSTOM.x;
    float band = floor(index/256.0);
    float a = (mod(index,256.0)+VERTEX.x*.99)/256.0*VAULT_TAU;
    float depth = mod(band*.5+travel,64.0)-56.0+VERTEX.y*.495;
    float material_z = depth-travel;
    float twist = .10*sin(material_z*.19634954+elapsed*.017);
    float angle = a+twist;
    float radius = vault_radius(a,material_z,elapsed,breath_fill);
    vec3 center = vec3(cos(angle)*radius,sin(angle)*radius,depth);
    POSITION = PROJECTION_MATRIX*VIEW_MATRIX*journey_frame*vec4(center,1);
    surface_uv = vec2(a/VAULT_TAU*12.0,material_z*.25);
    relief = (radius/(1.0-breath_fill*.40)-4.75)/3.0;
    opacity = (1.0-smoothstep(12.0,32.0,-depth))*smoothstep(-56.0,-47.0,depth)*(1.0-smoothstep(5.0,8.0,depth))*intensity;
}
void fragment() {
    if (opacity<.002) discard;
    vec2 cell = floor(surface_uv);
    vec2 p = fract(surface_uv)*2.0-1.0;
    float seed = vault_hash(cell);
    vec3 evolution = vault_weights(elapsed);
    float r = length(p);
    float a = atan(p.y,p.x);
    // Nested rosettes, fish-scale arches, woven diagonals and curling filigree.
    float petal = r*(1.0+.17*cos(a*6.0+evolution.z*.8));
    float rosette = abs(sin(petal*19.0+a*.65+evolution.z*1.1));
    float braid = abs(sin((p.x+p.y)*15.0+.9*sin((p.x-p.y)*7.0)));
    float scroll = abs(sin(16.0*r-a*3.0+2.0*sin(a*3.0)+elapsed*.018));
    float pattern = mix(rosette,scroll,evolution.z*.65);
    float fine = abs(sin(petal*53.0-a*2.0));
    float ink = 1.0-smoothstep(.12,.24,pattern);
    float lace = (1.0-smoothstep(.08,.17,braid))*.30;
    vec3 jewel = vault_palette(petal*.24+cell.x*.07+cell.y*.045,elapsed);
    vec3 color = mix(vec3(.008,.012,.03),jewel*.28,smoothstep(.16,.8,pattern));
    vec3 gold = vec3(.90,.57,.14);
    color += ink*mix(gold,jewel,.4)*.75+lace*jewel*.32;
    color += (1.0-smoothstep(.06,.13,fine))*jewel*.12;
    // Eyes emerge within selected cells, rather than filling every surface.
    float eye_amount = evolution.x*step(.70,seed);
    float eye_edge = abs(p.y)-.42*(1.0-p.x*p.x/.72);
    float eye_shape = max(eye_edge,abs(p.x)-.86);
    float eye_mask = 1.0-smoothstep(-.02,.025,eye_shape);
    float iris = length(p*vec2(1.0,1.1));
    vec3 eye = mix(vec3(.035,.13,.17),vault_palette(iris*.6+cell.y*.07,elapsed),.65);
    eye *= .58+.25*sin(atan(p.y,p.x)*22.0+iris*35.0);
    eye = mix(eye,vec3(.001,.005,.012),1.0-smoothstep(.10,.14,iris));
    float eye_rim = 1.0-smoothstep(.02,.055,abs(eye_shape));
    color = mix(color,eye,eye_mask*eye_amount);
    color += eye_rim*gold*eye_amount*.85;
    color += exp(-dot(p-vec2(-.06,.10),p-vec2(-.06,.10))*750.0)*eye_amount*.55;
    // Small gecko mosaics appear during separate, long evolving passages.
    float gecko_amount = evolution.y*step(seed,.23);
    if (gecko_amount>.005) {
    vec2 gp = p*1.12;
    if (mod(cell.x+cell.y,2.0)> .5) gp = -gp;
    float gecko = vault_gecko(gp);
    float gecko_mask = 1.0-smoothstep(-.005,.015,gecko);
    vec3 scales = mix(vec3(.035,.38,.20),vec3(.50,.85,.19),.5+.5*sin(gp.y*34.0+cos(gp.x*32.0)));
    color = mix(color,scales*.7,gecko_mask*gecko_amount);
    color += (1.0-smoothstep(.015,.04,abs(gecko)))*gold*gecko_amount*.7;
    float eyes = min(length(gp-vec2(.105,.48)),length(gp-vec2(-.105,.48)));
    color = mix(color,vec3(.005,.015,.01),(1.0-smoothstep(.022,.035,eyes))*gecko_amount);
    }
    // Relief shading and inlay borders keep the closely packed tiles legible.
    float bevel = smoothstep(0.0,.07,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
    color *= mix(.86,1.0,bevel)*(.58+.42*relief);
    color *= 1.0+hold_glow*(.22+.10*sin(elapsed*9.42477796));
    ALBEDO = color;
    ALPHA = opacity*.98;
}
