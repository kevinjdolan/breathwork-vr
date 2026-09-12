shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 source_position;
uniform vec3 nose_position;
uniform vec3 head_position;
uniform vec3 head_right;
uniform vec3 head_up;
uniform vec3 head_forward;
uniform float elapsed;
uniform float beam_visibility;
uniform float beam_front;
uniform float intensity = 1.0;
varying float opacity;
varying float halo;
varying float progress;
vec3 path(float t, float side) {
    vec3 c1 = mix(source_position,nose_position,.35)+head_right*side*.72+head_up*.10;
    vec3 c2 = nose_position+head_forward*.62+head_right*side*.20;
    float q = 1.0-t;
    return q*q*q*source_position+3.0*q*q*t*c1+3.0*q*t*t*c2+t*t*t*nose_position;
}
void vertex() {
    float t = VERTEX.x;
    float side = INSTANCE_CUSTOM.x*2.0-1.0;
    halo = INSTANCE_CUSTOM.y;
    vec3 center = path(t,side);
    vec3 tangent = normalize(path(min(.9999,t+.002),side)-path(max(.0001,t-.002),side));
    vec3 right = cross(tangent,head_up);
    if (length(right)<.01) right = head_right;
    right = normalize(right);
    vec3 up = normalize(cross(right,tangent));
    float radius = mix(.004,.018,halo)*(0.85+.15*sin(t*33.0-elapsed*3.0));
    radius *= mix(1.0,.35,smoothstep(.82,1.0,t));
    center += (right*VERTEX.y+up*VERTEX.z)*radius;
    POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(center,1);
    opacity = beam_visibility*intensity*(1.0-smoothstep(beam_front-.06,beam_front+.06,t));
    opacity *= smoothstep(.055,.09,distance(center,head_position));
    progress = t;
}
void fragment() {
    // Broad packets move along source -> nose; the underlying plasma stays continuous.
    float wave = .5+.5*cos(progress*6.283185*3.0-elapsed*6.283185*.8);
    float filament = .28+.72*pow(wave,3.0);
    ALBEDO = mix(vec3(.18,1.0,.20),vec3(.025,.70,.065),halo);
    ALPHA = opacity*mix(.8,.075,halo)*filament;
}
