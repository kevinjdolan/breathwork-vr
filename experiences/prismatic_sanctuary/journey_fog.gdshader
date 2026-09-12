shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform mat4 journey_frame;
uniform float elapsed;
uniform float intensity = 1.0;
varying vec2 uv;
varying float layer;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
    layer = INSTANCE_CUSTOM.x;
    vec3 point = vec3(VERTEX.xy*(21.0+layer*5.0),-26.0-layer*8.0);
    POSITION = PROJECTION_MATRIX*VIEW_MATRIX*journey_frame*vec4(point,1);
    uv = UV;
}
void fragment() {
    vec2 p = uv*2.0-1.0;
    float cloud = noise(p*3.0+vec2(elapsed*.012,layer*3.0))+noise(p*7.0-vec2(elapsed*.008,0))*.35;
    float veil = exp(-dot(p,p)*3.5)*(0.62+cloud*.30);
    ALBEDO = mix(vec3(.013,.033,.048),vec3(.043,.017,.067),cloud*.65);
    ALPHA = veil*intensity*.28;
}
