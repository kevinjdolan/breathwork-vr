shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 head_position;
uniform float shell_index = 0.0;
uniform float shell_count = 4.0;
uniform float shell_delay = 2.6;
// 0 newly born at the centre, 1 leaving the outer limit; advanced every frame.
uniform float shell_s = 0.0;

varying vec3 local_dir;

void vertex() {
    local_dir = normalize(VERTEX);
}

void fragment() {
    float s = shell_s;
    // Further out is further back: the delay follows the veil's place in the stack, so
    // the echo still reads as history even though nothing stands still.
    float t = elapsed - s * shell_count * shell_delay;
    float draw = breath_fill;

    // A stronger warp than the rosettes: these veils are meant to be pulled and
    // folded, and there is no fine motif here for the swirl to destroy.
    vec4 params = vec4(0.975 - 0.014 * draw, 1.30 + 0.28 * draw, 9.0 + 5.0 * draw, 0.022);
    vec3 p = md_step(local_dir, t * 0.16, params, 3.6);
    p = md_step(p, t * 0.16, params, 3.6);

    vec3 polar = md_polar(p);
    // A veil is seeded as close crossing folds and broadens as it travels, so the wash
    // opens out and passes the listener. Only a mild ramp: matching a wash's world size
    // to the radius would shatter the far veils into noise, and the point is that they
    // stay broad.
    float k = mix(2.85, 1.25, s);

    // Three crossing low frequencies, each shell turned to its own orientation, is the
    // cheapest thing that reads as a painted wash rather than a gradient.
    float turn = shell_index * 1.31;
    float a = polar.y + turn;
    float e = polar.z;
    float wash = sin(a * 2.7 * k + t * 0.07)
               + sin((e * 3.6 - a * 1.2) * k - t * 0.05 + turn)
               + sin((a * 1.3 + e * 2.4) * k + t * 0.09);
    wash *= 0.3333;

    // Only the crest of the wash is painted, so each veil leaves most of its sphere
    // open and four of them overlap without closing the room.
    float veil = smoothstep(0.22, 0.70, wash);
    // A brighter core where the wash peaks, so a veil has a lit fold and not one flat tone.
    float core = smoothstep(0.62, 0.98, wash);

    // Brush grain: streaks that follow the wash's own gradient, their spacing wobbled
    // by a slower sine so they read as bristle marks and not as a woven plaid. They
    // coarsen with the wash, which is most of what makes a veil read as approaching.
    float streak = sin((a * 23.0 + e * 7.5) * k + sin(e * 2.7 + t * 0.03) * 2.4);
    veil *= 0.58 + 0.44 * (streak * 0.5 + 0.5);
    // A ragged edge where the veil thins out, as vellum takes ink unevenly.
    veil *= 0.80 + 0.20 * sin(e * 9.0 * k - a * 3.0 + t * 0.02);

    // The wash arrives out of nothing and thins away at the far limit; the slow birth
    // is also what keeps the nearest veil from hazing over everything behind it.
    float birth = smoothstep(0.0, 0.28, s);
    float death = 1.0 - smoothstep(0.76, 1.0, s);
    float echo = pow(0.80, s * (shell_count - 1.0)) * birth * death;
    float alpha = (veil + core * 0.55) * echo * visibility * (0.38 + 0.16 * draw);

    // Parchment through ochre to rose; the far veils sit at the warmer end.
    float hue = clamp(0.04 + s * 0.40 + core * 0.45, 0.0, 1.0);
    vec3 parchment = vec3(1.00, 0.88, 0.60);
    vec3 ochre = vec3(1.00, 0.60, 0.20);
    vec3 rose = vec3(1.00, 0.42, 0.40);
    vec3 tint = hue < 0.5 ? mix(parchment, ochre, hue / 0.5) : mix(ochre, rose, (hue - 0.5) / 0.5);

    ALBEDO = tint;
    ALPHA = clamp(alpha, 0.0, 1.0);
}
