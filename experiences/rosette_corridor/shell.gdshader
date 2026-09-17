shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://experiences/shared/milkdrop.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform float elapsed;
uniform float visibility;
uniform float breath_fill;
uniform vec3 world_center;
uniform vec3 head_position;
uniform float shell_index = 0.0;
uniform float shell_count = 6.0;
uniform float shell_delay = 1.6;
// Radius ratio of this shell to the innermost one.
uniform float shell_scale = 1.0;

varying vec3 local_dir;

void vertex() {
    // The shell is a sphere the listener stands inside; only its direction matters.
    local_dir = normalize(VERTEX);
}

void fragment() {
    // MilkDrop's video echo redrew the previous frame slightly larger every frame,
    // which is what produced the endless tunnel. Here that recursion is literal: this
    // shell sits further out and shows the field as it stood shell_index delays ago,
    // so the receding scales the original faked are real distance the head can parallax
    // against.
    float t = elapsed - shell_index * shell_delay;
    float draw = breath_fill;

    vec4 params = vec4(0.985 - 0.010 * draw, 1.22 + 0.24 * draw, 6.0 + 4.0 * draw, 0.030);
    vec3 p = md_step(local_dir, t * 0.30, params, 2.5);
    p = md_step(p, t * 0.30, params, 2.5);

    vec3 polar = md_polar(p);
    // Sixfold symmetry is the angular fold most presets applied before using `ang`.
    float fold = md_fold(polar.y, 6.0);

    // A shell that paints everywhere hides every shell behind it, and the stack reads
    // as one smeared surface. Discrete rosettes with real gaps between them keep each
    // shell mostly open, so the depth the echo now occupies is actually visible.
    // Holding the motif's world size constant across shells is echo_zoom itself: the
    // same figure redrawn larger each step. A further shell therefore shows more, finer
    // rosettes, and the stack recedes instead of sitting at one flat scale.
    float cell_a = fold * 5.0 * shell_scale;
    float cell_e = (polar.z + 1.5708) * 3.2 * shell_scale;
    vec2 cell = vec2(fract(cell_a) - 0.5, fract(cell_e) - 0.5);
    float seed = floor(cell_a) * 17.0 + floor(cell_e) * 5.0;
    float reach = length(cell) * 2.0;

    float petals = 0.5 + 0.5 * cos(atan(cell.y, cell.x) * 6.0 + t * 0.20 + seed);
    // Roughly a tenth of each shell is painted, so six of them stack to a little
    // over half coverage and the gaps between them stay open.
    float body = 1.0 - smoothstep(0.06, 0.30, reach);
    float rosette = body * (0.35 + 0.65 * petals) * (0.6 + 0.4 * sin(reach * 9.0 - t * 0.5 + seed));
    rosette = max(0.0, rosette);

    // Each shell further out is an older, fainter copy, exactly as echo_alpha decayed.
    float echo = pow(0.90, shell_index) * mix(0.45, 1.0, shell_index / max(shell_count - 1.0, 1.0));
    float alpha = rosette * echo * visibility * (0.34 + 0.26 * draw);

    ALBEDO = meditation_palette(clamp(0.08 + shell_index / shell_count * 0.62 + petals * 0.18, 0.0, 1.0));
    ALPHA = alpha;
}
