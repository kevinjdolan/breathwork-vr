shader_type particles;
render_mode disable_force, disable_velocity;
uniform float time = 0.0;
uniform float breath = 0.0;
uniform float visibility = 1.0;
uniform vec3 head_position = vec3(0.0,1.4,0.0);
float hash(float n) { return fract(sin(n*127.1)*43758.5453); }
void start() { CUSTOM=vec4(hash(float(INDEX)+0.4),hash(float(INDEX)+13.7),hash(float(INDEX)+101.9),hash(float(INDEX)+211.3)); }
void process() {
    float lane = floor(CUSTOM.x*7.0);
    float u = fract(CUSTOM.y + time*(0.003+CUSTOM.w*0.003));
    float theta = (u-0.5)*2.75 + lane*1.029+0.22;
    float radius = 5.3+mod(lane,3.0)*2.7;
    float spread = (CUSTOM.z-0.5)*(0.9+(1.0-breath)*0.55);
    radius += spread + cos(u*6.8+lane+time*0.07)*0.45 + breath*0.35;
    float height = 0.7+sin(u*3.14159265)*(3.5+mod(lane,4.0)*0.8+breath*0.65);
    height += sin(u*7.1+time*0.13+lane*2.3)*0.4+sin(u*13.3-time*0.087+lane)*0.16;
    height += (CUSTOM.w-0.5)*0.7;
    vec3 position = vec3(sin(theta)*radius,height,-cos(theta)*radius);
    if (lane >= 5.0) {
        float angle = lane*1.029+0.22;
        float along = (u-0.5)*17.0;
        position = vec3(cos(angle)*along, 6.0+sin(u*3.14159265)*(2.1+breath*0.6), sin(angle)*along+sin(u*3.14159265)*0.35);
        position += vec3(spread,(CUSTOM.w-0.5)*0.7,spread*0.6);
    }
    float flicker = 0.65+0.35*sin(time*0.4+CUSTOM.w*30.0);
    float ends = smoothstep(0.0,0.1,u)*(1.0-smoothstep(0.9,1.0,u));
    float near_fade = smoothstep(0.7,1.4,distance(position,head_position));
    COLOR = vec4(mix(vec3(0.23,0.70,0.74),vec3(0.66,0.81,1.0),CUSTOM.z),visibility*ends*near_fade*flicker*0.62);
    float size = 0.014+CUSTOM.z*0.025;
    TRANSFORM = mat4(vec4(size,0,0,0),vec4(0,size,0,0),vec4(0,0,size,0),vec4(position,1));
}
