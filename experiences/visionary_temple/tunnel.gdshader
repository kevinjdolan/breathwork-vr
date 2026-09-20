shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// The current passage: a painted shell displaced along the contours of its own relief map.
#include "res://experiences/visionary_temple/tunnel_common.gdshaderinc"

void fragment() {
    ALBEDO = shade_wall(texture(relief, uv_v), 0.0);
}
