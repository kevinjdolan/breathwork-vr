shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/palette.gdshaderinc"
uniform int theme;
uniform vec4 rhythm;
uniform float phase_seconds;
uniform float elapsed;
uniform float visibility;
uniform vec3 focus_position;
uniform vec3 mouth_position;
uniform vec3 head_position;
uniform vec3 head_right;
uniform vec3 head_up;
uniform vec3 head_forward;
varying vec3 tint;
varying float opacity;
void vertex() {
    float id=INSTANCE_CUSTOM.x;
    bool incoming=id<768.0;
    float u=fract(elapsed/3.8+INSTANCE_CUSTOM.y);
    float a=INSTANCE_CUSTOM.z*6.283185;
    float envelope;
    float loop=dot(rhythm,vec4(1));
    float lead=phase_seconds>loop-1.3 ? phase_seconds-loop : phase_seconds;
    float outgoing_start=rhythm.x+rhythm.y;
    if(incoming) envelope=smoothstep(-1.3,.5,lead)*(1.0-smoothstep(rhythm.x-.65,rhythm.x+.35,lead));
    else envelope=smoothstep(outgoing_start,outgoing_start+.7,phase_seconds)*(1.0-smoothstep(outgoing_start+rhythm.z-1.2,outgoing_start+rhythm.z,phase_seconds));
    if(elapsed>=480.0-1.3 && phase_seconds>loop-1.3) envelope=0.0;
    vec3 nose=head_position+head_up*(-.035)+head_forward*.085;
    vec3 start=incoming ? focus_position : mouth_position;
    vec3 end=incoming ? nose : focus_position+head_forward*2.0;
    float width=sin(u*3.14159)*(.12+.08*INSTANCE_CUSTOM.w);
    vec3 offset=(head_right*cos(a)+head_up*sin(a))*width;
    if(theme==0) offset*=1.0+.35*cos(u*18.84956);
    if(theme==1) offset+=head_up*sin(u*3.14159)*.20;
    if(theme==2) offset=(head_right*cos(a+u*6.0)+head_up*sin(a+u*6.0))*width*1.4;
    if(theme==3) offset+=head_right*sin(u*12.0+a)*width*.5;
    if(theme==4) offset=head_right*sign(cos(a))*width+head_up*sign(sin(a))*width*.5;
    if(theme==5 && !incoming) offset*=1.0+u*3.0;
    vec3 center=mix(start,end,u)+offset;
    float size=theme==2 ? .024 : .012;
    if(theme==5) size=.008;
    size*=mix(.22,1.0,smoothstep(.12,.65,distance(center,head_position)));
    vec3 view=(VIEW_MATRIX*vec4(center,1)).xyz;
    POSITION=PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*size,0),1);
    tint=theme_color(theme,incoming ? .15 : .9);
    opacity=envelope*smoothstep(0,.10,u)*(1.0-smoothstep(.93,1.0,u))*visibility;
    opacity*=smoothstep(.065,.13,distance(center,head_position))*.5;
    if(theme==2) opacity*=.35;
}
void fragment() {
    vec2 p=UV*2.0-1.0;
    float point=exp(-dot(p,p)*3.5);
    if(theme==4) point=(1.0-smoothstep(.5,.9,max(abs(p.x),abs(p.y))));
    ALBEDO=tint;
    ALPHA=point*opacity;
}
