shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform mat4 journey_frame;
uniform vec3 head_position;
uniform float elapsed = 0.0;
uniform float travel = 0.0;
uniform float breath_fill = 0.0;
uniform float hold_glow;
uniform float intensity = 1.0;
varying vec3 tint;
varying float opacity;
void vertex() {
    float index = INSTANCE_CUSTOM.x;
    float band = floor(index/256.0);
    float a = mod(index,256.0)/256.0*6.283185;
    float depth = mod(band+travel,64.0)-56.0;
    float angle = a+depth*.058+.045*sin(elapsed*.06+band*.4);
    float weave = .64*cos(a*6.0+depth*.24+elapsed*.065)+.27*cos(a*11.0-depth*.18);
    float radius = (5.1+weave+mod(band,3.0)*.18)*(1.0-breath_fill*.40);
    vec3 center = vec3(cos(angle)*radius,sin(angle)*radius,depth);
    center.xy += .07*vec2(sin(elapsed*.16+a*4.0),cos(elapsed*.13+a*3.0));
    vec3 world = (journey_frame*vec4(center,1)).xyz;
    vec3 view = (VIEW_MATRIX*vec4(world,1)).xyz;
    float size = .11+INSTANCE_CUSTOM.y*.055;
    POSITION = PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*size,0),1);
    float color_wave = .5+.5*sin(a*3.0+band*.37+elapsed*.065);
    vec3 cyan = vec3(.025,.66,.95);
    vec3 violet = vec3(.64,.045,.91);
    vec3 orange = vec3(.97,.22,.035);
    tint = mix(mix(cyan,violet,smoothstep(.1,.55,color_wave)),orange,smoothstep(.65,.95,color_wave));
    float strands = .48+.34*pow(.5+.5*cos(a*12.0-band*.55),2.0);
    tint *= 1.0+hold_glow*(.28+.16*sin(elapsed*9.42477796));
    opacity = (1.0-smoothstep(12.0,32.0,-depth))*strands*smoothstep(-56.0,-47.0,depth)*(1.0-smoothstep(5.0,8.0,depth))*intensity;
}
void fragment() {
    vec2 p = UV*2.0-1.0;
    float diamond = 1.0-smoothstep(.30,1.0,abs(p.x)+abs(p.y));
    ALBEDO = tint;
    ALPHA = diamond*opacity;
}
