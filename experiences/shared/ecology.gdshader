shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/palette.gdshaderinc"
uniform int theme;
uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
varying float opacity;
varying vec3 tint;
void vertex() {
    float id=INSTANCE_CUSTOM.x;
    float group=floor(id/256.0);
    float a=INSTANCE_CUSTOM.y*6.283185;
    float b=INSTANCE_CUSTOM.z*6.283185;
    float y=1.0-2.0*(group+.5)/48.0;
    float az=group*2.399963;
    vec3 direction=vec3(cos(az)*sqrt(1.0-y*y),y,sin(az)*sqrt(1.0-y*y));
    vec3 right=normalize(cross(direction,vec3(.01,1,.01)));
    vec3 up=normalize(cross(right,direction));
    float cycle=elapsed/(24.0+mod(group,7.0))+group*.618;
    float age=fract(cycle);
    float life=smoothstep(0,.18,age)*(1.0-smoothstep(.76,1.0,age));
    float reveal=life;
    float radius=4.0+mod(group,4.0)*1.4;
    float visit=floor(cycle);
    float shift=sin(visit*2.4+group)*.18;
    direction=normalize(direction+right*shift+up*cos(visit*1.7+group)*.16);
    radius+=sin(visit*1.9+group)*.8;
    vec3 center=world_center+direction*radius;
    float size=.016;
    vec3 local;
    if(theme==0) {
        float r=.45+.13*cos(a*8.0+elapsed*.06);
        local=right*cos(a)*r+up*sin(a)*r+direction*sin(b)*.13;
    } else if(theme==1) {
        float wave=a+elapsed*.10;
        float r=.45+.22*sin(b*3.0+elapsed*.15);
        local=(right*cos(wave)+up*sin(wave))*r+direction*sin(a*4.0+elapsed*.2)*.38;
        size=.025;
    } else if(theme==2) {
        float r=.12+INSTANCE_CUSTOM.z*.65;
        float spin=a+elapsed*.09+r*4.0;
        local=(right*cos(spin)+up*sin(spin))*r+direction*sin(b)*.15;
        size=.032;
    } else if(theme==3) {
        float arm=floor(INSTANCE_CUSTOM.z*8.0)*.785398;
        float t=INSTANCE_CUSTOM.w;
        local=(right*cos(arm)+up*sin(arm))*(.2+t*.8)+direction*sin(t*8.0+group)*.20;
        life*=.3+.7*pow(.5+.5*cos(t*12.0-elapsed*1.6),4.0);
    } else if(theme==4) {
        float t=fract(INSTANCE_CUSTOM.w+elapsed*.035);
        vec2 p=vec2(cos(a),sin(a))/max(abs(cos(a)),abs(sin(a)));
        local=right*p.x*.75+up*p.y*.75+direction*(t-.5)*.6;
        life*=.25+.75*pow(.5+.5*cos(t*18.0-elapsed*1.4),4.0);
    } else {
        float t=fract(INSTANCE_CUSTOM.w+elapsed*.025);
        local=right*cos(a)*(.35+.25*breath_fill)+up*(t-.5)*1.4+direction*sin(a)*.25;
        life*=sin(t*3.14159);
        size=.012;
    }
    // Clusters materialize, drift, unravel and dissolve on staggered lifecycles.
    local*=1.0+(1.0-reveal)*.75;
    center+=local+vec3(sin(elapsed*.071+group),cos(elapsed*.063+group*2.0),sin(elapsed*.057+group*3.0))*.25;
    vec3 view=(VIEW_MATRIX*vec4(center,1)).xyz;
    POSITION=PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*size,0),1);
    tint=theme_color(theme,INSTANCE_CUSTOM.z);
    opacity=life*visibility*smoothstep(.7,1.5,distance(center,head_position))*.40;
    if(theme==2) opacity*=.35;
}
void fragment() {
    vec2 p=UV*2.0-1.0;
    float shape=exp(-dot(p,p)*3.6);
    if(theme==4 || theme==0) shape=1.0-smoothstep(.2,1,abs(p.x)+abs(p.y));
    ALBEDO=tint;
    ALPHA=shape*opacity;
}
