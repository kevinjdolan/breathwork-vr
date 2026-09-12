class_name SessionArc
extends RefCounted
## Builds the single editable timeline; every ramp uses cubic smoothstep easing.

const KEYS: Dictionary = {
    "aurora_intensity": [[0, 0.3], [12, 0.3], [180, 0.6], [300, 1.2], [420, 1.2], [456, 0.5], [480, 0.5]],
    "aurora_saturation": [[0, 0.0], [180, 0.0], [300, 0.6], [420, 0.6], [456, 0.15], [480, 0.15]],
    "fractal_mix": [[0, 0.0], [180, 0.0], [300, 0.35], [420, 1.0], [456, 0.3], [480, 0.3]],
    "fractal_morph_rate": [[0, 0.2], [300, 0.2], [420, 1.0], [456, 0.2], [480, 0.2]],
    "field_amount": [[0, 0.0], [180, 0.0], [300, 0.3], [420, 1.0], [456, 0.0], [480, 0.0]],
    "field_radius": [[0, 40.0], [300, 40.0], [420, 8.0], [456, 40.0], [480, 40.0]],
    "ripple_amp": [[0, 0.3], [180, 0.3], [300, 0.6], [420, 0.6], [480, 0.6]],
    "exhale_reach": [[0, 0.4], [180, 0.4], [300, 0.8], [480, 0.8]],
    "breath_particles_enabled": [[0, 0.0], [12, 0.0], [12.5, 1.0], [475.9, 1.0], [476, 0.0], [480, 0.0]],
    "breath_lowpass": [[0, 6000.0], [180, 6000.0], [300, 2400.0], [420, 1000.0], [456, 3500.0], [480, 3500.0]],
    "fade": [[0, 1.0], [12, 0.0], [476, 0.0], [480, 1.0]],
    "fractal_fold": [[0, 3.0], [300, 3.0], [420, 7.0], [456, 3.0], [480, 3.0]],
}

static func create_animation() -> Animation:
    var animation: Animation = Animation.new()
    animation.resource_name = "arc"
    animation.length = 480.0
    for property: String in KEYS:
        var track: int = animation.add_track(Animation.TYPE_BEZIER)
        animation.track_set_path(track, NodePath(".:" + property))
        var keys: Array = KEYS[property]
        for index: int in range(keys.size()):
            var entry: Array = keys[index]
            var before: float = (float(entry[0]) - float(keys[index - 1][0])) / 3.0 if index > 0 else 0.0
            var after: float = (float(keys[index + 1][0]) - float(entry[0])) / 3.0 if index + 1 < keys.size() else 0.0
            animation.bezier_track_insert_key(track, float(entry[0]), float(entry[1]), Vector2(-before, 0), Vector2(after, 0))
    return animation
