shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
uniform sampler2D field_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D field_b : filter_linear_mipmap, repeat_disable;
uniform float field_mix;
uniform float elapsed;
uniform float visibility = 1.0;
uniform float breath_fill;
varying vec3 local_direction;
varying float relief;
void vertex() {
    vec3 d = normalize(VERTEX);
    float folds = sin(d.x*9.0+elapsed*.013)*sin(d.y*9.0-elapsed*.017)*sin(d.z*9.0);
    float radius = (12.0+folds*1.5+.7*cos(d.y*16.0+d.x*10.0))*(1.0+breath_fill*.045);
    VERTEX = d*radius;
    local_direction = d;
    relief = folds;
}
void fragment() {
    vec3 d = normalize(local_direction);
    vec3 ad = abs(d);
    vec2 p;
    float face;
    if (ad.z>=ad.x && ad.z>=ad.y) { p=d.xy/ad.z; face=0.0; }
    else if (ad.y>=ad.x) { p=d.xz/ad.y; face=1.0; }
    else { p=d.zy/ad.x; face=2.0; }
    float r=length(p);
    float angle=atan(p.y,p.x)+elapsed*.012;
    float sector=6.283185/8.0;
    float folded=abs(mod(angle+sector*.5,sector)-sector*.5);
    vec2 q=vec2(cos(folded),sin(folded))*r;
    float zoom=.68+.16*sin(elapsed*.009)+breath_fill*.018;
    vec2 uv=vec2(.20,.40)+q*zoom;
    uv=vec2(1.0)-abs(mod(uv,2.0)-1.0);
    vec3 data=mix(texture(field_a,uv).rgb,texture(field_b,uv).rgb,field_mix);
    float bands=data.r*18.0+data.g*1.2;
    vec3 palette=.5+.5*cos(6.283185*(vec3(0.0,.24,.57)+bands*.085+face*.06+elapsed*.002));
    float detail=1.0-smoothstep(.10,.7,fwidth(bands));
    float etched=.5+.5*cos(bands*6.283185)*detail;
    vec3 color=palette*(.16+.62*pow(etched,1.3));
    color=mix(color,vec3(.003,.008,.023),data.b*.90);
    float lace=pow(.5+.5*sin(data.g*50.0+bands*3.0),8.0);
    color+=lace*vec3(.19,.38,.45)*.18*detail;
    // Gold/cyan ribs define each mirrored vault and its real sculpted surface.
    float rib=pow(.5+.5*cos(angle*8.0),48.0)*smoothstep(.1,.8,r);
    color+=rib*vec3(.12,.30,.32)*.25;
    color*=.76+.24*relief;
    ALBEDO=color*visibility*.64;
}
