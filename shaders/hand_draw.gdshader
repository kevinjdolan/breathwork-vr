shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void vertex() {
    vec3 center=(VIEW_MATRIX*MODEL_MATRIX[3]).xyz;
    POSITION=PROJECTION_MATRIX*vec4(center+vec3(VERTEX.xy*0.003,0.0),1.0);
}
void fragment() {
    vec2 delta=UV*2.0-1.0;
    float dot_alpha=exp(-dot(delta,delta)*5.0)*(1.0-smoothstep(0.6,1.0,length(delta)));
    ALBEDO=COLOR.rgb;
    ALPHA=dot_alpha*COLOR.a;
}
