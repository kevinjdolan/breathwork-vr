shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void vertex() {
    float size = length(MODEL_MATRIX[0].xyz);
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size,INV_VIEW_MATRIX[2]*size,MODEL_MATRIX[3]);
}
void fragment() {
    vec2 p = abs(UV * 2.0 - 1.0);
    float diamond = 1.0 - smoothstep(0.25,1.0,p.x+p.y);
    ALBEDO = COLOR.rgb;
    ALPHA = diamond * COLOR.a;
}
