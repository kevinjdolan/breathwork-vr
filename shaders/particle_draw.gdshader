shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D soft_dot : source_color, filter_linear;
uniform float flow_stretch = 1.0;
void vertex() {
    float size = length(MODEL_MATRIX[0].xyz);
    vec3 center = (VIEW_MATRIX*MODEL_MATRIX[3]).xyz;
    float max_size = 80.0*max(0.01,-center.z)/(VIEWPORT_SIZE.y*PROJECTION_MATRIX[1][1]);
    size = min(size,max_size/flow_stretch);
    vec3 tangent = (VIEW_MATRIX*vec4(MODEL_MATRIX[0].xyz,0.0)).xyz;
    vec2 direction = length(tangent.xy)>0.00001 ? normalize(tangent.xy) : vec2(1.0,0.0);
    vec2 sideways = vec2(-direction.y,direction.x);
    MODELVIEW_MATRIX = mat4(vec4(direction*size*flow_stretch,0.0,0.0),vec4(sideways*size,0.0,0.0),vec4(0.0,0.0,size,0.0),vec4(center,1.0));
}
void fragment() {
    float softness = texture(soft_dot,UV).a;
    ALBEDO = COLOR.rgb;
    ALPHA = softness*COLOR.a;
}
