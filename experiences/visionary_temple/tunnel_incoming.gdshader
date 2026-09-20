shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always, fog_disabled;
// The next passage waits behind the dissolving shell, wider and dimmer, turning its own way.
#include "res://experiences/visionary_temple/tunnel_common.gdshaderinc"

void fragment() {
    ALBEDO = shade_wall(texture(relief, uv_v), 0.0);
    ALPHA = 1.0;
}
