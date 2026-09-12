shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform float fade = 1.0;
void vertex() { POSITION = vec4(VERTEX.xy*2.0,1.0,1.0); }
void fragment() { ALBEDO=vec3(0.0); ALPHA=fade; }
