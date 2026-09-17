shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 head_position;
uniform float shell_index = 0.0;
uniform float shell_count = 6.0;
uniform float shell_delay = 1.8;
uniform float shell_scale = 1.0;
// 0 on even shells, 1 on odd: the composite stage's invert, applied every other shell.
uniform float inverted = 0.0;

varying vec3 local_dir;

void vertex() {
    local_dir = normalize(VERTEX);
}

void fragment() {
    float t = elapsed - shell_index * shell_delay;
    float draw = breath_fill;

    // Barely any warp and no yaw worth the name: a chapel has to stand still, so the
    // engine is run here only to keep the bays from being perfectly rigid.
    vec4 params = vec4(0.997 - 0.004 * draw, 1.08 + 0.10 * draw, 1.6 + 1.0 * draw, 0.004);
    vec3 p = md_step(local_dir, t * 0.12, params, 4.0);
    p = md_step(p, t * 0.12, params, 4.0);

    vec3 polar = md_polar(p);
    float k = 1.0 + 0.30 * shell_index;

    // Ten bays around the listener. The fold is MilkDrop's angular symmetry; here it is
    // simply the plan of an arcade.
    float sides = 14.0;
    float seg = 6.2831853 / sides;
    float x = md_fold(polar.y, sides) / (seg * 0.5);
    float v = polar.z;

    // A bay is a tall opening: narrow in azimuth, bounded in elevation, with a rounded
    // head. Everything outside it stays unpainted, which is what keeps five shells of
    // this behind one another still legible.
    float head = 0.46 - 0.30 * x * x;
    float window = (1.0 - smoothstep(0.26, 0.42, x))
                 * (1.0 - smoothstep(head - 0.06, head, v))
                 * smoothstep(-0.56, -0.48, v);

    // The figure inside the bay: stone courses crossed by a mullion.
    float courses = smoothstep(0.30, 0.86, 0.5 + 0.5 * cos(v * 15.0 * k - t * 0.05));
    float mullion = 1.0 - smoothstep(0.05, 0.16, x);
    float figure = clamp(courses * 0.85 + mullion * 0.45, 0.0, 1.0);

    // MilkDrop's composite stage again: even shells come through brightened, odd ones
    // are the same figure inverted and pushed down, so the stack alternates lit stone
    // and lit void and depth reads as a beat of light and dark.
    float positive = pow(figure, 0.75);
    float negative = pow(1.0 - figure, 1.35);
    float value = mix(positive, negative, inverted) * window;

    // Solarise at the breath: the fold point of the curve travels with the inhale, so
    // the whole chapel flips through itself once per cycle without anything moving.
    float solar = 1.0 - abs(2.0 * figure - (0.35 + 0.55 * draw));
    value *= 0.68 + 0.42 * clamp(solar, 0.0, 1.0);

    float echo = pow(0.90, shell_index);
    float alpha = value * echo * visibility * (0.26 + 0.14 * draw);

    // Cool blue-grey stone; the inverted shells return in its warm complement.
    vec3 cool = mix(vec3(0.42, 0.55, 0.72), vec3(0.66, 0.78, 0.92), figure);
    vec3 warm = mix(vec3(0.72, 0.56, 0.36), vec3(0.95, 0.80, 0.56), 1.0 - figure);
    ALBEDO = mix(cool, warm, inverted);
    ALPHA = clamp(alpha, 0.0, 1.0);
}
