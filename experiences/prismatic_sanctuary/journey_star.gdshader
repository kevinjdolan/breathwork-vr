shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform mat4 journey_frame;
uniform vec3 star_position;
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float phase_seconds = 0.0;
uniform float intensity = 1.0;
uniform float star_radius = 1.0;
varying vec3 tint;
varying float opacity;
void vertex() {
    float i = INSTANCE_CUSTOM.x;
    float a = INSTANCE_CUSTOM.y*6.283185;
    float r = pow(INSTANCE_CUSTOM.z,2.4)*.42;
    vec3 offset = vec3(cos(a)*r,sin(a)*r,0);
    float size = .42;
    opacity = .75;
    if (i>63.0) {
        float side = floor((i-64.0)/64.0);
        float t = mod(i-64.0,64.0)/63.0;
        float length = 1.65+breath_fill*.85;
        float ray_angle = side*1.57079633+.07*sin(elapsed*.09);
        float bend = sin(t*3.14159265)*(.10+breath_fill*.26);
        offset.xy = vec2(cos(ray_angle),sin(ray_angle))*t*length + vec2(-sin(ray_angle),cos(ray_angle))*bend;
        size = .28*(1.0-t*.65);
        opacity = .65*(1.0-t);
    }
    if (i<4.0) { offset = vec3(0); size = 3.8; opacity = .035; }
    offset *= star_radius;
    size *= star_radius;
    opacity *= step(.001,star_radius);
    vec3 world = star_position+mat3(journey_frame)*offset;
    vec3 view = (VIEW_MATRIX*vec4(world,1)).xyz;
    POSITION = PROJECTION_MATRIX*vec4(view+vec3(VERTEX.xy*size,0),1);
    tint = vec3(1.0);
    opacity *= intensity;
}
void fragment() {
    vec2 p = UV*2.0-1.0;
    ALBEDO = tint;
    ALPHA = exp(-dot(p,p)*4.0)*opacity;
}
