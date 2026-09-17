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
// Where this shell stands on its journey out: 0 newly born at the centre, 1 about to
// leave the outer limit. The layer advances it every frame.
uniform float shell_s = 0.0;
// Fixed offset of this shell in the cycle, used only to keep the shells from sharing
// one seed when they all pass through the same value of shell_s.
uniform float shell_phase = 0.0;

varying vec3 local_dir;

void vertex() {
    // The shell is a sphere the listener stands inside; only its direction matters.
    local_dir = normalize(VERTEX);
}

void fragment() {
    float s = shell_s;
    // MilkDrop's video echo redrew the previous frame slightly larger every frame,
    // which is what produced the endless tunnel. Here that recursion is literal and it
    // moves: the shell climbs outward through the stack, showing a field that is older
    // the further out it has travelled, and is reborn at the centre when it leaves.
    float t = elapsed - s * shell_count * shell_delay;
    float draw = breath_fill;

    vec4 params = vec4(0.985 - 0.010 * draw, 1.22 + 0.24 * draw, 6.0 + 4.0 * draw, 0.030);
    vec3 p = md_step(local_dir, t * 0.30, params, 2.5);
    p = md_step(p, t * 0.30, params, 2.5);

    vec3 polar = md_polar(p);
    // Sixfold symmetry is the angular fold most presets applied before using `ang`.
    float fold = md_fold(polar.y, 6.0);

    // echo_zoom itself: the same figure redrawn larger every step. A shell is seeded
    // with a fine lattice and that lattice opens out as the shell travels, so rosettes
    // grow and sweep past instead of standing at one fixed size. The ramp is mild —
    // a full radius-ratio ramp would shatter the far shells into noise.
    float k = mix(2.55, 1.00, s);
    float cell_a = fold * 5.0 * k;
    float cell_e = (polar.z + 1.5708 + shell_phase * 0.7) * 3.2 * k;
    vec2 cell = vec2(fract(cell_a) - 0.5, fract(cell_e) - 0.5);
    float seed = floor(cell_a) * 17.0 + floor(cell_e) * 5.0;
    float reach = length(cell) * 2.0;

    float petals = 0.5 + 0.5 * cos(atan(cell.y, cell.x) * 6.0 + t * 0.20 + seed);
    // Roughly a tenth of each shell is painted, so six of them stack to a little
    // over half coverage and the gaps between them stay open.
    float body = 1.0 - smoothstep(0.06, 0.30, reach);
    float rosette = body * (0.35 + 0.65 * petals) * (0.6 + 0.4 * sin(reach * 9.0 - t * 0.5 + seed));
    rosette = max(0.0, rosette);

    // The fade is what makes the recycling invisible: a shell arrives out of nothing at
    // the centre and thins away at the outer limit, so nothing ever pops. The slow
    // birth also keeps the nearest shell from washing out everything behind it.
    float birth = smoothstep(0.0, 0.26, s);
    float death = 1.0 - smoothstep(0.80, 1.0, s);
    // Each step out is an older, fainter copy, exactly as echo_alpha decayed.
    float echo = pow(0.88, s * (shell_count - 1.0)) * birth * death;
    float alpha = rosette * echo * visibility * (0.40 + 0.30 * draw);

    ALBEDO = meditation_palette(clamp(0.08 + s * 0.62 + petals * 0.18, 0.0, 1.0));
    ALPHA = clamp(alpha, 0.0, 1.0);
}
