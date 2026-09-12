shader_type sky;
render_mode disable_fog;
#include "res://shaders/sky_common.gdshaderinc"
void sky() {
    // No lighting consumes the radiance map; skip its expensive evaluation.
    if (AT_CUBEMAP_PASS) { COLOR=vec3(0.0); }
    else { COLOR=sky_color(EYEDIR); }
}
