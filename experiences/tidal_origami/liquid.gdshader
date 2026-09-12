shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
uniform float time = 0.0;
uniform float breath = 0.0;
uniform float visibility = 1.0;
uniform float seed = 0.0;
uniform bool bead_mode = false;
varying vec3 surface_position;
varying float liquid_seed;
void vertex() {
    float tide = smoothstep(0.0,1.0,breath);
    float id = bead_mode ? INSTANCE_CUSTOM.y : seed;
    vec3 shape = VERTEX;
    if (bead_mode) {
        float angle = INSTANCE_CUSTOM.x*6.2831853 + time*(0.032+INSTANCE_CUSTOM.x*0.021) + id;
        float orbit = 0.87 - tide*0.22 + sin(time*0.07+angle*2.7)*0.09;
        vec3 dimension = vec3(1.0,1.15+0.12*sin(time*0.3+angle),1.0)*INSTANCE_CUSTOM.z;
        VERTEX *= dimension;
        NORMAL = normalize(NORMAL/dimension);
        VERTEX += vec3(cos(angle)*orbit, sin(angle*1.7+time*0.041)*0.28+0.18*tide, sin(angle)*orbit*0.63);
    } else {
        vec3 dimension = vec3(0.66-tide*0.085,0.14+tide*0.10,0.51-tide*0.05);
        float lobes = sin(shape.x*4.1+time*0.14+id)*sin(shape.z*3.6-time*0.11+id);
        VERTEX *= dimension*(1.0+lobes*0.11);
        NORMAL = normalize(NORMAL/dimension);
        VERTEX.y += sin(shape.x*4.7+shape.z*3.1-time*0.19+id)*0.055;
        VERTEX += vec3(sin(time*0.043+id)*0.11, tide*0.18+cos(time*0.057+id)*0.09, sin(time*0.061+id*2.0)*0.09);
    }
    surface_position = shape;
    liquid_seed = id;
}
void fragment() {
    vec3 normal = normalize(NORMAL);
    float facing = abs(dot(normal,normalize(VIEW)));
    float rim = pow(1.0-facing,2.3);
    float light = pow(max(0.0,dot(normal,normalize(vec3(-0.3,0.85,0.4)))),6.0);
    float flow = surface_position.x*17.0 + surface_position.z*13.0 + sin(surface_position.z*9.0-time*0.12)*2.0 - time*0.16;
    float web = sin(flow)*sin(surface_position.z*27.0+surface_position.x*11.0+sin(flow)*2.0+time*0.08);
    float caustic = pow(1.0-abs(web),22.0);
    vec3 body = mix(vec3(0.009,0.064,0.087),vec3(0.025,0.11,0.12),0.5+0.5*sin(liquid_seed*1.7));
    vec3 color = body*(0.5+facing*0.3) + vec3(0.38,0.65,0.71)*(rim*0.37+light*0.22+caustic*0.11);
    ALBEDO = color*visibility;
}
