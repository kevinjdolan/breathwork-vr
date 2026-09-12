shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void vertex() {
    float size = length(MODEL_MATRIX[0].xyz);
    vec3 center = (VIEW_MATRIX*MODEL_MATRIX[3]).xyz;
    MODELVIEW_MATRIX = mat4(vec4(size,0,0,0),vec4(0,size,0,0),vec4(0,0,size,0),vec4(center,1));
}
void fragment() {
    float r = length(UV*2.0-1.0);
    ALBEDO = COLOR.rgb;
    ALPHA = pow(max(0.0,1.0-r),1.8)*COLOR.a;
}
