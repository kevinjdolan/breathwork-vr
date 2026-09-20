shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// Modelled relics tumble along varied paths through the tunnel. Motion mirrors relics.gd exactly so the
// inhale plasma can follow a moving relic; surfaces take gemstone and gold looks from a matcap atlas.
uniform mat4 journey_frame;
uniform sampler2D matcaps : source_color, filter_linear, repeat_disable;
uniform sampler2D sprite_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 head_position;
uniform vec3 glow_color = vec3(1.0, 0.93, 0.78);
uniform float elapsed = 0.0;
uniform float breath_fill = 0.0;
uniform float intensity = 1.0;
uniform float hold_glow = 0.0;
uniform float source_index = -1.0;
uniform float beam_visibility = 0.0;
uniform float size_scale = 1.0;
uniform float sprite_cell = -1.0;
uniform bool sprite_cutout = false;
const float TAU_V = 6.283185307;
const float PASSAGE = 60.0;
const float PER_PASSAGE = 48.0;
const float SPEED = 0.55;
const float CONTRACTION = 0.35;
const float SHELL = 3.4;
varying vec2 uv_v;
varying vec3 tint_v;
varying flat float part_v;
varying flat vec2 materials_v;
varying float depth_v;
varying float near_v;
varying float chosen_v;
varying float shimmer_v;

float h(float g, float a) {
    return fract(g * a);
}

float travel_at(float t) {
    return t < 0.0 ? SPEED * t : SPEED * (t - 5.0 * (1.0 - exp(-t / 5.0)));
}

float arrival_time(float g) {
    float passage = floor(g / PER_PASSAGE);
    float slot = g - passage * PER_PASSAGE;
    return PASSAGE * passage - 15.0 + (slot + 0.5 + 0.8 * (h(g, 0.6180339) - 0.5)) * PASSAGE / PER_PASSAGE;
}

float z_kind(float g) {
    float kind = h(g, 0.7548777);
    return kind < 0.12 ? 2.0 : (kind < 0.24 ? 1.0 : 0.0);
}

float envelope(float g, float t) {
    float dt = t - arrival_time(g);
    float kind = z_kind(g);
    if (kind > 1.5) {
        return smoothstep(-20.0, -12.0, dt) * (1.0 - smoothstep(55.0, 65.0, dt));
    }
    return kind > 0.5 ? smoothstep(-75.0, -68.0, dt) : 1.0;
}

float depth_of(float g, float t) {
    float arrival = arrival_time(g);
    float kind = z_kind(g);
    float speed = kind > 1.5 ? -(0.95 + 0.10 * h(g, 0.5698403)) : (kind > 0.5 ? -(0.40 + 0.04 * h(g, 0.5698403)) : -0.06 + 0.24 * h(g, 0.5698403));
    float surge = 0.4 + h(g, 0.4385790);
    float rate = 0.12 + 0.18 * h(g, 0.3247179);
    float phase = h(g, 0.8793852) * TAU_V;
    return travel_at(t) - travel_at(arrival) + speed * (t - arrival) + surge * (sin(rate * t + phase) - sin(rate * arrival + phase));
}

vec3 relic_center(float g, float t, float squeeze, float size) {
    float depth = depth_of(g, t);
    float theta = h(g, 0.9212563) * TAU_V;
    float lane = h(g, 0.6823278);
    bool near = h(g, 0.2451223) <= 0.27;
    float r0 = near ? 1.15 + 0.35 * lane : 1.4 + 0.8 * lane;
    float omega = (0.04 + 0.16 * h(g, 0.1319764)) * (h(g, 0.3819660) < 0.5 ? -1.0 : 1.0);
    float phase_a = h(g, 0.5436890) * TAU_V;
    float phase_b = h(g, 0.7071068) * TAU_V;
    float wave = h(g, 0.2360680);
    float pattern = floor(h(g, 0.4142136) * 6.0);
    vec2 xy;
    if (pattern < 0.5) {
        xy = r0 * vec2(cos(theta + omega * t), sin(theta + omega * t));
    } else if (pattern < 1.5) {
        float r = r0 + 0.45 * sin(0.21 * t + phase_a);
        xy = r * vec2(cos(theta + omega * t), sin(theta + omega * t));
    } else if (pattern < 2.5) {
        float rate = 0.10 + 0.08 * wave;
        xy = r0 * vec2(cos(theta), sin(theta)) + vec2(0.75 * sin(rate * t + phase_a), 0.55 * sin(2.0 * rate * t + phase_b));
    } else if (pattern < 3.5) {
        vec2 normal = vec2(cos(theta), sin(theta));
        vec2 across = vec2(-normal.y, normal.x);
        xy = (1.05 + 0.45 * lane) * normal + 1.4 * sin((0.06 + 0.07 * wave) * t + phase_a) * across;
    } else if (pattern < 4.5) {
        float angle = theta + 0.35 * omega * t;
        xy = r0 * vec2(cos(angle), sin(angle)) + vec2(0.0, 0.8 * sin(0.15 * t + phase_a));
    } else {
        float angle = theta + 0.7 * sin(0.07 * t + phase_a) + 0.35 * sin(0.19 * t + phase_b);
        xy = (r0 + 0.35 * sin(0.11 * t + phase_b)) * vec2(cos(angle), sin(angle));
    }
    xy *= squeeze;
    float lowest = max(near ? 1.05 : 1.3, abs(depth) * 0.035 + size * 0.6);
    float highest = SHELL * squeeze - size * 0.6 - 0.16;
    float radius = length(xy);
    xy *= min(max(radius, lowest), highest) / max(radius, 0.0001);
    return vec3(xy, depth);
}

vec3 turn(vec3 v, vec3 axis, float angle) {
    return v * cos(angle) + cross(axis, v) * sin(angle) + axis * dot(axis, v) * (1.0 - cos(angle));
}

void vertex() {
    float g = INSTANCE_CUSTOM.r;
    materials_v = INSTANCE_CUSTOM.gb;
    float squeeze = 1.0 - breath_fill * CONTRACTION;
    bool near = h(g, 0.2451223) <= 0.27;
    float w = h(g, 0.1673097);
    float size = (near ? 0.26 + w * 0.12 : 0.6 + w * 0.55) * size_scale * squeeze;
    vec3 center = relic_center(g, elapsed, squeeze, size);
    depth_v = center.z;
    // Most relics tumble freely; the rest turn about their own axis while rocking, like hanging ornaments.
    vec3 axis_a = normalize(vec3(h(g, 0.1234567), h(g, 0.8765432), h(g, 0.3456789)) - 0.5 + vec3(0.0, 0.001, 0.0));
    float spin_a = (0.18 + 0.5 * h(g, 0.9876543)) * (h(g, 0.2718282) < 0.5 ? -1.0 : 1.0) * elapsed + h(g, 0.6931472) * TAU_V;
    vec3 v;
    vec3 n;
    if (h(g, 0.3010300) < 0.62) {
        vec3 axis_b = normalize(cross(axis_a, vec3(0.3, 1.0, 0.2)));
        float spin_b = (0.07 + 0.12 * h(g, 0.5772157)) * elapsed + h(g, 0.1414214) * TAU_V;
        v = turn(turn(VERTEX, axis_a, spin_a), axis_b, spin_b);
        n = turn(turn(NORMAL, axis_a, spin_a), axis_b, spin_b);
    } else {
        float rock = 0.45 * sin(0.4 * elapsed + h(g, 0.1414214) * TAU_V);
        v = turn(turn(VERTEX, vec3(0.0, 1.0, 0.0), spin_a), vec3(1.0, 0.0, 0.0), rock);
        n = turn(turn(NORMAL, vec3(0.0, 1.0, 0.0), spin_a), vec3(1.0, 0.0, 0.0), rock);
    }
    float grow = envelope(g, elapsed) * smoothstep(-44.0, -34.0, center.z) * (1.0 - smoothstep(4.0, 7.0, center.z));
    vec3 world_center = (journey_frame * vec4(center, 1.0)).xyz;
    vec3 world = world_center + mat3(journey_frame) * (v * size * grow);
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
    NORMAL = mat3(journey_frame) * n;
    uv_v = UV;
    tint_v = COLOR.rgb;
    part_v = COLOR.a;
    near_v = smoothstep(0.45, 0.85, distance(world_center, head_position) - size * 0.3);
    chosen_v = abs(g - source_index) < 0.5 ? beam_visibility : 0.0;
    shimmer_v = h(g, 0.8660254) * TAU_V;
}

vec3 matcap(float index, vec2 cap) {
    return texture(matcaps, (vec2(mod(index, 4.0), floor(index / 4.0)) + cap) * 0.25).rgb;
}

void fragment() {
    if (near_v < 0.999) {
        // Relics beside the face dissolve through interleaved gradient noise instead of clipping the eyes.
        float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
        if (near_v < noise) {
            discard;
        }
    }
    vec3 n = normalize(FRONT_FACING ? NORMAL : -NORMAL);
    vec2 cap = vec2(n.x, -n.y) * 0.48 + 0.5;
    vec3 primary = matcap(materials_v.x, cap);
    vec3 color = primary * tint_v;
    if (part_v < 0.125) {
        color = tint_v * 1.3 + primary * 0.3;
    } else if (part_v < 0.375) {
        bool inside = all(greaterThanEqual(uv_v, vec2(0.0))) && all(lessThanEqual(uv_v, vec2(1.0)));
        vec4 paint = inside && sprite_cell >= 0.0 ? texture(sprite_sheet, (vec2(mod(sprite_cell, 4.0), floor(sprite_cell / 4.0)) + uv_v) * vec2(0.25, 0.5)) : vec4(0.0);
        if (sprite_cutout && paint.a < 0.4) {
            discard;
        }
        float sheen = dot(primary, vec3(0.3, 0.5, 0.2));
        color = mix(color, paint.rgb * (0.7 + 0.5 * sheen), paint.a);
    } else if (part_v < 0.875) {
        color = matcap(materials_v.y, cap) * tint_v;
    }
    color *= 0.92 + 0.08 * sin(elapsed * 0.9 + shimmer_v) + hold_glow * 0.12;
    color = mix(color, vec3(1.0, 0.86, 0.45) * 1.35, chosen_v * 0.45);
    float far = smoothstep(22.0, 48.0, -depth_v);
    ALBEDO = mix(color, glow_color, far * far) * intensity;
}
