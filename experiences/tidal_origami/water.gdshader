shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
uniform float time = 0.0;
uniform float breath = 0.0;
uniform float visibility = 1.0;
uniform float seed = 0.0;
uniform float angle = 0.0;
uniform float radius = 5.0;
uniform float arch_height = 4.0;
uniform float sheet_width = 0.6;
varying vec3 shape_position;
vec3 sheet(vec2 uv) {
    float u = uv.x;
    float v = uv.y * 2.0 - 1.0;
    float theta = (u - 0.5) * 2.75 + angle;
    float sway = sin(u*7.1 + time*0.13 + seed*2.3)*0.40 + sin(u*13.3-time*0.087+seed)*0.16;
    float reach = radius + cos(u*6.8 + seed + time*0.07)*0.45 + breath*0.35;
    float fold = u*6.9 + seed*1.7 + time*0.08 + breath*0.34;
    vec3 center = vec3(sin(theta)*reach, 0.7+sin(u*3.14159265)*(arch_height + breath*0.65)+sway, -cos(theta)*reach);
    if (seed >= 5.0 && seed < 9.0) {
        float along = (u-0.5)*17.0;
        center = vec3(cos(angle)*along, 6.0+sin(u*3.14159265)*(2.1+breath*0.6)+sway, sin(angle)*along+sin(u*3.14159265)*0.35);
    }
    if (seed >= 9.0) {
        // Suspended twisted loops place deep liquid structures overhead and behind.
        float turn = u * 6.283185;
        float r = 2.0 + mod(seed, 3.0) * .45;
        center = vec3(cos(turn) * r, 5.5 + sin(turn) * r * .6, sin(turn * 2.0) * .65);
        center.xz += vec2(cos(angle), sin(angle)) * (3.3 + sin(time*.043+seed)*.4);
        center.y += breath*.4 + sway*.3;
    }
    float taper = smoothstep(0.0,0.07,u)*(1.0-smoothstep(0.93,1.0,u));
    float width = sheet_width * (0.68+0.32*sin(u*3.14159265)) * taper;
    vec3 cross_axis = vec3(sin(theta)*cos(fold), sin(fold), -cos(theta)*cos(fold));
    center += cross_axis*v*width;
    // Rolled liquid edges change thickness as broad ripples cross the sheet.
    center.y += sin(v*3.7 + u*17.0 + time*0.2 + seed)*0.11;
    center += cross_axis * pow(abs(v), 6.0) * sin(u*11.7-time*0.12+seed) * 0.13;
    center.y += pow(abs(v), 8.0) * (0.08+0.08*sin(u*8.3+time*0.11+seed));
    return center;
}
void vertex() {
    VERTEX = sheet(UV);
    shape_position = VERTEX;
    vec3 a = sheet(UV + vec2(0.001,0.0)) - VERTEX;
    vec3 b = sheet(UV + vec2(0.0,0.001)) - VERTEX;
    NORMAL = normalize(cross(a,b));
}
void fragment() {
    float flow = UV.x*37.0 + sin(UV.x*15.0 + seed + time*0.13)*1.2 - time*0.15;
    float warp = sin(UV.x*51.0+UV.y*7.0-time*0.13) + 0.48*sin(UV.x*89.0-UV.y*13.0+time*0.19);
    float web = sin(UV.y*24.0 + warp*3.5 + flow*0.4) * sin(flow*1.4+UV.y*17.0-warp);
    float filaments = pow(1.0-abs(web), 24.0);
    float caustic = pow(0.5+0.5*sin(flow+UV.y*12.0+warp), 7.0);
    float border = pow(abs(UV.y*2.0-1.0), 18.0);
    float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
    vec3 teal = mix(vec3(0.006,0.046,0.069), vec3(0.047,0.17,0.16), 0.5+0.5*sin(seed*1.3+UV.x*3.0));
    vec3 silver = vec3(0.34,0.65,0.68);
    vec3 color = teal*(0.28+rim*0.8) + silver*(filaments*0.055 + caustic*0.13 + border*0.25);
    float ends = smoothstep(0.0,0.065,UV.x)*(1.0-smoothstep(0.935,1.0,UV.x));
    ALBEDO = color * ends * visibility;
}
