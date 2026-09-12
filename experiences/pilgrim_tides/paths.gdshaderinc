// A family of gently warped loops; each plane presents its tiny walkers inward.
vec3 path_center(float group) {
    if (group > 7.5) {
        float az = (group-8.0)*2.399963;
        float y = 1.0-2.0*(group-7.5)/8.0;
        return vec3(cos(az)*sqrt(1.0-y*y),y,sin(az)*sqrt(1.0-y*y))*7.0+vec3(0,1.4,0);
    }
    if (group < 0.5) return vec3(0.0, -0.55, -4.8);
    if (group < 1.5) return vec3(0.0, 1.0, -8.5);
    if (group < 2.5) return vec3(0.0, 5.8, -0.6);
    if (group < 3.5) return vec3(-5.2, 2.1, -1.8);
    if (group < 4.5) return vec3(5.2, 2.5, -2.0);
    if (group < 5.5) return vec3(0.0, 8.5, -5.0);
    if (group < 6.5) return vec3(0.0, 0.0, 5.7);
    return vec3(0.0, 4.8, 6.0);
}
vec3 path_up(float group) {
    if(group > 7.5) return normalize(vec3(0,1.4,0)-path_center(group));
    if (group < 1.5 || (group > 5.5 && group < 6.5)) return vec3(0.0, 1.0, 0.0);
    if (group < 2.5 || group > 6.5) return vec3(0.0, -1.0, 0.0);
    if (group < 3.5) return normalize(vec3(1.0, -0.2, 0.0));
    if (group < 4.5) return normalize(vec3(-1.0, -0.2, 0.0));
    return normalize(vec3(0.0, -0.8, 0.6));
}
vec3 path_point(float group, float phase, float fill, float seconds) {
    vec3 up = path_up(group);
    vec3 axis = abs(up.x) > 0.8 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 side = normalize(cross(up, axis));
    float angle = phase * 6.2831853;
    float radius = group < 0.5 ? 3.6 : (group < 1.5 ? 4.4 : 3.5);
    float gather = 1.0 - 0.09 * fill;
    float ruffle = 1.0 + 0.09 * sin(angle * 3.0 + group * 1.7 + seconds * 0.027);
    float along = cos(angle);
    float across = sin(angle) * 0.7;
    // A loose infinity promenade and gently squared circuits vary the silhouettes.
    if (group > 0.5 && group < 1.5) across = sin(angle * 2.0) * 0.50;
    if (group > 2.5 && group < 4.5) {
        along = sign(along) * pow(abs(along), 0.72);
        across = sign(across) * pow(abs(across), 0.80);
    }
    if(group > 7.5) {
        float petal = 1.0+.18*cos(angle*(3.0+mod(group,3.0))+seconds*.023);
        along*=petal;
        across*=petal;
        radius=2.3;
    }
    return path_center(group) + gather * radius * ruffle * (axis * along + side * across)
        + up * (0.18 * sin(angle * 2.0 + seconds * 0.055 + group) + 0.08 * sin(seconds * 0.07 + group * 2.0));
}
