vec3 theme_color(int theme,float t) {
    if(theme==0) return mix(vec3(.10,.75,.80),vec3(.70,.22,.95),t);
    if(theme==1) return mix(vec3(.04,.42,.80),vec3(.28,.91,.85),t);
    if(theme==2) return mix(vec3(.70,.77,.93),vec3(.97,.57,.42),t);
    if(theme==3) return mix(vec3(.22,.75,.60),vec3(.84,.35,.62),t);
    if(theme==4) return mix(vec3(.07,.82,.64),vec3(1.0,.47,.12),t);
    return mix(vec3(.99,.61,.22),vec3(.47,.70,.93),t);
}
