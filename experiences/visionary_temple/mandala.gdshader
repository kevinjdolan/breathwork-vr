shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A vast faint sigil turns slowly around the destination light; two instances crossfade passages.
uniform mat4 journey_frame;
uniform sampler2D sprite_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 star_position;
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float passage_mix = 0.0;
uniform float sprite_a = 0.0;
uniform float sprite_b = 0.0;
varying vec2 sprite_uv;
varying float opacity;
void vertex() {
    float which = INSTANCE_CUSTOM.x;
    float sprite = which < 0.5 ? sprite_a : sprite_b;
    opacity = (which < 0.5 ? 1.0 - passage_mix : passage_mix) * 0.42 * intensity;
    float spin = elapsed * (which < 0.5 ? 0.02 : -0.02);
    vec2 local = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * VERTEX.xy;
    float size = 15.0 * (1.0 + breath_fill * 0.18);
    vec3 world = star_position + mat3(journey_frame) * vec3(local * size, 0.0);
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
    vec2 corner = vec2(mod(sprite, 4.0), floor(sprite / 4.0));
    sprite_uv = (UV + corner) * vec2(0.25, 0.5);
}
void fragment() {
    vec4 sample = texture(sprite_sheet, sprite_uv);
    ALBEDO = sample.rgb;
    ALPHA = sample.a * opacity;
}
