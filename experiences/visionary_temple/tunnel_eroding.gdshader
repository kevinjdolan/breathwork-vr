shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// The outgoing passage dissolves along its painted contours, ground first, behind a golden rim.
#include "res://experiences/visionary_temple/tunnel_common.gdshaderinc"
uniform float erosion = 0.0;

void fragment() {
    vec4 carved = texture(relief, uv_v);
    float edge = carved.a - (erosion * 1.08 - 0.04);
    if (edge < 0.0) {
        discard;
    }
    // A thin warm rim that fades before the last fragments go, so small islands never flash.
    float rim = (1.0 - smoothstep(0.0, 0.025, edge)) * smoothstep(0.0, 0.05, erosion) * (1.0 - smoothstep(0.5, 0.9, erosion));
    ALBEDO = shade_wall(carved, rim * 0.7);
}
