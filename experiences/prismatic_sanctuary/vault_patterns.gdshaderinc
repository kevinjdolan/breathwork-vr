// A moving material coordinate keeps ornament attached to the passing relief.
const float VAULT_TAU = 6.283185307;
float vault_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec3 vault_weights(float time) {
    float eyes = smoothstep(.25,.85,sin(time*.018-1.0));
    float geckos = smoothstep(.30,.90,sin(time*.016-3.0));
    float scrolls = .5+.5*sin(time*.011+.8);
    return vec3(eyes,geckos,scrolls);
}
float vault_radius(float angle,float material_z,float time,float fill) {
    float scroll = .5+.5*sin(time*.011+.8);
    float vaults = .5+.5*cos(angle*8.0+material_z*.19634954);
    float petals = .5+.5*cos(angle*12.0-material_z*.39269908+.22*sin(time*.018));
    float deep = mix(vaults*vaults,petals*petals,scroll);
    float ribs = .5+.5*sin(angle*4.0+material_z*.39269908+time*.027);
    // All relief remains outside the 4.19m conservative object shell.
    return (5.05+1.85*deep+.85*ribs*ribs+.30*cos(angle*24.0+material_z*.78539816))*(1.0-fill*.40);
}
vec3 vault_palette(float position,float time) {
    float drift = .24*sin(time*.009)+.12*sin(time*.023);
    return .5+.5*cos(VAULT_TAU*(vec3(0.0,.33,.67)+position+drift));
}
float vault_segment(vec2 p,vec2 a,vec2 b) {
    vec2 v = b-a;
    return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
float vault_gecko(vec2 p) {
    // Rounded body, tapered snout, four bent legs and a curling tail.
    float d = length(p/vec2(.16,.38))-1.0;
    d *= .16;
    d = min(d,(length((p-vec2(0,.43))/vec2(.20,.25))-1.0)*.20);
    d = min(d,vault_segment(p,vec2(0,-.30),vec2(.16,-.57))-.075);
    d = min(d,vault_segment(p,vec2(.16,-.57),vec2(.38,-.70))-.055);
    d = min(d,vault_segment(p,vec2(.38,-.70),vec2(.52,-.60))-.035);
    d = min(d,vault_segment(p,vec2(.52,-.60),vec2(.46,-.48))-.019);
    vec2 q = vec2(abs(p.x),p.y);
    for (int leg=0;leg<2;leg++) {
        float y = leg==0 ? .20 : -.20;
        float bend = leg==0 ? .12 : -.12;
        vec2 elbow = vec2(.34,y+bend);
        vec2 foot = vec2(.48,y-bend);
        d = min(d,vault_segment(q,vec2(.10,y),elbow)-.045);
        d = min(d,vault_segment(q,elbow,foot)-.037);
        for (int toe=0;toe<3;toe++) {
            vec2 tip = foot+vec2(.10,float(toe-1)*.065);
            d = min(d,vault_segment(q,foot,tip)-.017);
        }
    }
    return d;
}
