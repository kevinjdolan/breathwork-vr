extends SceneTree
## Verify the visionary tunnel's passages, breath envelopes, source locking and gaze following.
const Layer = preload("res://experiences/visionary_temple/layer.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    check(is_zero_approx(Layer.travel_distance(0)), "Travel starts at rest")
    check(Layer.travel_distance(.1) < .001, "No sudden motion onset")
    check(absf(Layer.travel_distance(121) - Layer.travel_distance(120) - .55) < .0001, "Constant slow cruise speed")
    check(is_equal_approx(Layer.star_radius(4.0), 1.0) and is_equal_approx(Layer.star_radius(4.5), 1.9), "White core rays grow during the first 500 ms of the full hold")
    check(is_equal_approx(Layer.star_radius(8.0), 1.9) and is_zero_approx(Layer.star_radius(8.5)), "Rays collapse over the first 500 ms of the six-second exhale")
    check(is_zero_approx(Layer.star_radius(14.0)) and is_zero_approx(Layer.star_radius(15.99)) and is_zero_approx(Layer.star_radius(0)), "Rays stay absent through the two-second rest and wrap continuously")
    # Four two-minute passages with 24-second dissolves whose weights always sum to one.
    for second: int in range(0, 480):
        var state: Dictionary = Layer.passage_state(float(second))
        var weights: Vector4 = state["weights"]
        check(absf(weights.x + weights.y + weights.z + weights.w - 1.0) < .0001, "Passage weights are a partition of unity")
        check(int(state["index"]) == mini(second / 120, 3), "Passage index follows the two-minute schedule")
    check(is_zero_approx(Layer.passage_state(95.9)["mix"]) and is_equal_approx(Layer.passage_state(120.0)["mix"], 0.0), "Dissolves complete exactly at each passage boundary")
    check(absf(float(Layer.passage_state(108.0)["mix"]) - .5) < .001, "Dissolve midpoint at 108 seconds")
    check(is_zero_approx(Layer.passage_state(470.0)["mix"]), "The temple passage never dissolves into a fifth tile")
    for second: float in [100.0, 107.0, 119.0]:
        var earlier: Vector4 = Layer.passage_state(second)["weights"]
        var later: Vector4 = Layer.passage_state(second + .05)["weights"]
        check((later - earlier).length() < .02, "Passage weights move smoothly")
    var upright: Basis = Layer.journey_basis(Basis(Vector3.UP, deg_to_rad(40)))
    check(absf(upright.y.dot(Vector3.UP) - 1.0) < .001, "Turned journeys keep the temple floor toward the ground")
    var reclined: Basis = Basis(Vector3.RIGHT, deg_to_rad(80))
    check(Layer.journey_basis(reclined).z.angle_to(reclined.z) < .001, "Reclined journeys keep the gaze axis")
    var layer: Node3D = Layer.new()
    root.add_child(layer)
    check(layer.find_children("*", "Label3D").is_empty(), "No instructional text in the tunnel")
    check(layer.get_node("VioletOutflow").multimesh.instance_count == 32, "Sixteen outflow petals each carry a halo")
    check(layer.get_node("Sigils").multimesh.instance_count == 96, "Ninety-six drifting sigils")
    var tunnel: MeshInstance3D = layer.get_node("PaintedTunnel")
    check(tunnel.mesh.get_faces().size() / 3 == 65536 and tunnel.mesh.get_aabb().size.z >= 63.9, "One connected 64-meter tube within the mobile triangle budget")
    for name: String in Layer.PASSAGE_NAMES:
        var tile: Texture2D = load("res://experiences/visionary_temple/tiles/" + name + ".png")
        check(tile != null and tile.get_width() >= 1024 and tile.get_height() >= 1024, "Every passage has a baked ornament tile")
    var sheet: Texture2D = load("res://experiences/visionary_temple/tiles/sigils.png")
    check(sheet != null and sheet.get_width() == 1024, "Sigil sprite sheet is present")
    var basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(80))
    var head: Vector3 = Vector3(0, 1.4, 0)
    layer.update_experience({"head_position": head, "head_basis": basis, "elapsed": 30})
    check(layer.focal_position().distance_to(head - basis.z * 60) < .001, "Reclining start aligns the tunnel and light")
    head += Vector3(.25, .1, .3)
    for frame: int in range(960):
        layer.update_experience({"head_position": head, "head_basis": Basis.IDENTITY, "elapsed": 30.0 + float(frame + 1) / 60.0})
        if frame == 60:
            check(layer._journey.basis.z.angle_to(basis.z) < .15, "Large head turns have a slow onset")
    check(absf(layer.focal_position().distance_to(head) - 60) < .001, "Forward travel never approaches the light")
    check(layer._journey.basis.z.angle_to(Vector3.BACK) < .07, "Tunnel aligns to new gaze after sixteen seconds")
    var missing: int = 0
    for second: int in range(0, 480, 4):
        layer._journey = Transform3D(Basis.IDENTITY, head)
        var selected: int = layer.select_source(float(second), head, Basis.IDENTITY, 0.0)
        if selected < 0:
            missing += 1
        else:
            var present: Vector3 = Layer.object_center(selected, float(second), 0.0)
            var future: Vector3 = Layer.object_center(selected, float(second) + 6.0, 1.0)
            check(Vector3.FORWARD.dot(present.normalized()) > .87 and Vector3.FORWARD.dot(future.normalized()) > .82, "Selected sigil remains in the forward view for six seconds")
        for index: int in range(96):
            for fill: float in [0.0, .5, 1.0]:
                var center: Vector3 = Layer.object_center(index, float(second), fill)
                var shell: float = 3.05 * (1.0 - fill * .35)
                check(Vector2(center.x, center.y).length() + Layer.object_extent(index, fill) <= shell + .0001, "Sigils remain inside the contracting tunnel")
                check(Vector2(center.x, center.y).length() > .85, "Sigils never cross the central sightline")
    check(missing == 0, "Every sampled breathing cycle has a visible source sigil")
    layer.reset_journey()
    layer.update_experience({"elapsed": 32.0, "head_position": head, "head_basis": basis, "phase_seconds": 0.0})
    var locked: int = layer._source_index
    for frame: int in range(270):
        layer.update_experience({"elapsed": 32.0 + float(frame) / 60.0, "head_position": head, "head_basis": basis, "phase_seconds": float(frame) / 60.0})
        check(layer._source_index == locked, "Plasma never switches source while visible")
    var tunnel_material: ShaderMaterial = tunnel.material_override
    layer.update_experience({"elapsed": 250.0, "head_position": head, "head_basis": basis, "phase_seconds": 2.0})
    check((tunnel_material.get_shader_parameter("tile_a") as Texture2D).resource_path.ends_with("rings.png"), "Third passage paints the ring tile")
    check((tunnel_material.get_shader_parameter("tile_b") as Texture2D).resource_path.ends_with("temple.png"), "Third passage dissolves toward the temple tile")
    print("VISIONARY JOURNEY: ", "PASS" if failures == 0 else "FAIL")
    layer.free()
    quit(failures)
