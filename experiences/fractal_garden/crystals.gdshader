shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
varying vec3 tint;
void vertex() {
    float id=INSTANCE_CUSTOM.x;
    vec3 local=INSTANCE_CUSTOM.yzw*.65;
    vec3 center=MODEL_MATRIX[3].xyz-local;
    float spin=elapsed*.055+id;
    mat2 turn=mat2(vec2(cos(spin),sin(spin)),vec2(-sin(spin),cos(spin)));
    local.xz=turn*local.xz;
    local.yz=turn*local.yz;
    local*=1.0+breath_fill*.12;
    center+=vec3(sin(elapsed*.07+id),cos(elapsed*.09+id*2.0),sin(elapsed*.08+id*3.0))*.22;
    POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(center+local+VERTEX,1);
    tint=.5+.5*cos(6.283185*(vec3(.0,.25,.55)+id*.13+elapsed*.002));
}
void fragment() {
    ALBEDO=tint*.7;
    ALPHA=visibility*.65;
}
