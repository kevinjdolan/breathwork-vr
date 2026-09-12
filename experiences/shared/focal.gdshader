shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/palette.gdshaderinc"
uniform int theme;
uniform float elapsed;
uniform float breath_fill;
uniform float visibility;
uniform vec3 focus_position;
uniform vec3 head_right;
uniform vec3 head_up;
uniform vec3 head_forward;
varying vec3 tint;
varying float opacity;
void vertex() {
    float id=INSTANCE_CUSTOM.x;
    float a=INSTANCE_CUSTOM.y*6.283185;
    float u=INSTANCE_CUSTOM.z;
    float b=INSTANCE_CUSTOM.w*6.283185;
    vec3 p;
    float size=.011;
    if(theme==0) {
        // Nested six-fold recursive iris: each ring unfurls with the inhale.
        float ring=floor(u*6.0);
        float r=(.13+ring*.047)*(1.0+breath_fill*.7);
        r*=1.0+.20*cos(a*6.0+ring*.7+elapsed*.09);
        p=vec3(cos(a)*r,sin(a)*r,sin(a*3.0+ring)*.07);
    } else if(theme==1) {
        // A liquid lotus: droplets climb open petals, then drain to the center.
        float petal=floor(u*8.0);
        float t=INSTANCE_CUSTOM.w;
        float r=sin(t*3.14159)*(.20+breath_fill*.23);
        float angle=petal*6.283185/8.0+.18*sin(t*3.14159);
        p=vec3(cos(angle)*r,(t-.5)*(.36+breath_fill*.34),sin(angle)*r);
        size=.014;
    } else if(theme==2) {
        // Soft cloud spiral expands, while smaller eddies condense and evaporate.
        float r=(.13+.16*u)*(1.0+breath_fill*.7);
        p=vec3(cos(a+elapsed*.12)*r,sin(a+elapsed*.12)*r,sin(b)*.11);
        p+=vec3(sin(b*3.0),cos(b*2.0),sin(a*4.0))*.05;
        size=.032;
    } else if(theme==3) {
        // A dendritic crown: convergent signals collect, then radiate along forks.
        float arm=floor(u*12.0);
        float t=INSTANCE_CUSTOM.w;
        float angle=arm*6.283185/12.0;
        float r=.07+t*(.22+.17*breath_fill);
        p=vec3(cos(angle)*r,sin(angle)*r,sin(t*8.0+arm)*.05);
        p.xy+=vec2(-sin(angle),cos(angle))*sin(t*14.0)*t*.035;
    } else if(theme==4) {
        // Layered square capacitor plates accumulate a visible charge.
        float ring=floor(u*7.0);
        vec2 square=vec2(cos(a),sin(a))/max(abs(cos(a)),abs(sin(a)));
        p=vec3(square*(.10+ring*.035),(.5-u)*.23);
        p.xy*=1.0+breath_fill*.30;
        size=.012;
    } else {
        // A small gathering of lantern-like figures rises and opens its arms.
        float person=floor(u*24.0);
        float angle=person*6.283185/24.0+elapsed*.022;
        vec3 base=vec3(cos(angle)*(.30-breath_fill*.10),sin(angle)*(.30-breath_fill*.10),0);
        float part=floor(INSTANCE_CUSTOM.w*5.0);
        float t=fract(INSTANCE_CUSTOM.w*5.0);
        vec2 figure=vec2(0,(t-.5)*.08);
        if(part<1.0) figure=vec2(cos(a),sin(a))*.014+vec2(0,.054);
        else if(part<3.0) figure=vec2((part<2.0 ? -1.0:1.0)*t*.043,.025+breath_fill*t*.037);
        else figure=vec2((part<4.0 ? -1.0:1.0)*t*.021,-t*.05);
        p=base+vec3(figure,0);
        size=.006;
    }
    vec3 world=focus_position+head_right*p.x+head_up*p.y+head_forward*p.z;
    vec3 view=(VIEW_MATRIX*vec4(world,1)).xyz;
    POSITION=PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*size,0),1);
    tint=theme_color(theme,INSTANCE_CUSTOM.w);
    float moving=.5+.5*sin(a*3.0-elapsed*.7);
    opacity=visibility*(.38+.24*breath_fill+.15*moving);
    if(theme==2) opacity*=.30;
}
void fragment() {
    vec2 p=UV*2.0-1.0;
    float shape=exp(-dot(p,p)*3.5);
    if(theme==0 || theme==4) shape=1.0-smoothstep(.2,1.0,abs(p.x)+abs(p.y));
    ALBEDO=tint;
    ALPHA=shape*opacity;
}
