shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/prismatic_sanctuary/vault_patterns.gdshaderinc"
uniform mat4 journey_frame;
uniform float elapsed;
uniform float travel;
uniform float breath_fill;
uniform float intensity;
uniform float hold_glow;
varying vec3 tint;
varying float opacity;
void vertex() {
    float i = INSTANCE_CUSTOM.x;
    float band = floor(i/256.0);
    float a = mod(i,256.0)/256.0*VAULT_TAU;
    float depth = mod(band*.5+travel,64.0)-56.0;
    float mz = depth-travel;
    a += .035*sin(mz*.785+elapsed*.035+a*6.0);
    float radius = vault_radius(a,mz,elapsed,breath_fill)-(.16+.32*INSTANCE_CUSTOM.y)*(1.0-breath_fill*.40);
    float angle = a+.10*sin(mz*.19634954+elapsed*.017);
    vec3 world = (journey_frame*vec4(cos(angle)*radius,sin(angle)*radius,depth,1)).xyz;
    vec3 view = (VIEW_MATRIX*vec4(world,1)).xyz;
    POSITION = PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*(.018+.016*INSTANCE_CUSTOM.z),0),1);
    tint = mix(vec3(.3,.72,.86),vault_palette(a/VAULT_TAU+band*.027,elapsed),.6);
    opacity = (1.0-smoothstep(19.0,44.0,-depth))*smoothstep(-56.0,-47.0,depth)*(1.0-smoothstep(5.0,8.0,depth))*intensity*(.5+hold_glow*.2);
}
void fragment() {
    vec2 p = UV*2.0-1.0;
    ALBEDO = tint;
    ALPHA = exp(-dot(p,p)*4.0)*opacity;
}
