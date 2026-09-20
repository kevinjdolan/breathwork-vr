extends SceneTree
## Verify the visionary tunnel's passages, breath envelopes, source locking and gaze following.
const Layer = preload("res://experiences/visionary_temple/layer.gd")
const Relics = preload("res://experiences/visionary_temple/relics.gd")
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
    # Eight one-minute passages; each dissolves over the final thirty seconds of its minute.
    check(Layer.PASSAGE_NAMES.size() == 8 and Layer.PASSAGE_NAMES[0] == "eyes" and Layer.PASSAGE_NAMES[7] == "temple", "Eight passages open with the eyes and arrive at the temple")
    for second: int in range(0, 480):
        var state: Dictionary = Layer.passage_state(float(second))
        check(int(state["index"]) == mini(second / 60, 7), "Passage index follows the one-minute schedule")
        check(int(state["next"]) == mini(second / 60 + 1, 7), "Each passage dissolves toward the following one")
        var expected: float = clampf((float(second % 60) - 30.0) / 30.0, 0.0, 1.0) if second < 420 else 0.0
        check(absf(float(state["progress"]) - expected) < .0001, "Dissolves span the final thirty seconds of each minute")
    check(is_zero_approx(Layer.passage_state(89.9)["progress"]) and Layer.passage_state(90.1)["progress"] > 0.0, "The second dissolve begins at ninety seconds")
    check(is_zero_approx(Layer.passage_state(470.0)["progress"]), "The temple passage never dissolves into a ninth tile")
    for index: int in range(7):
        var before: Dictionary = Layer.passage_state(60.0 * float(index + 1) - .001)
        var after: Dictionary = Layer.passage_state(60.0 * float(index + 1))
        check(int(after["index"]) == int(before["next"]), "The arriving passage becomes the current passage at the minute")
        check(absf(Layer.erosion_amount(float(before["progress"])) - 1.0) < .0001, "The outgoing shell is fully open before the swap")
        check(absf(Layer.arrival_scale(float(before["progress"])) - 1.0) < .001 and absf(Layer.arrival_brightness(float(before["progress"])) - 1.0) < .001, "The arriving shell reaches its resting size and brightness before the swap")
        var turning: float = Layer.TILE_MAPS[index].w
        var following: float = Layer.TILE_MAPS[index + 1].w
        check(not is_equal_approx(turning, following) and turning * following <= 0.0, "Neighbouring passages turn in different directions or one is still")
    check(is_zero_approx(Layer.erosion_amount(0.0)) and is_zero_approx(Layer.erosion_amount(.02)), "Dissolves start with a closed shell")
    var previous_erosion: float = 0.0
    var previous_scale: float = Layer.arrival_scale(0.0)
    for step: int in range(101):
        var progress: float = float(step) / 100.0
        check(Layer.erosion_amount(progress) >= previous_erosion - .00001 and Layer.arrival_scale(progress) <= previous_scale + .00001, "Erosion only opens and the arriving shell only settles")
        previous_erosion = Layer.erosion_amount(progress)
        previous_scale = Layer.arrival_scale(progress)
    # The arriving shell stays clear of the outgoing shell until that shell has dissolved.
    for index: int in range(7):
        var outer: float = 0.0
        var inner: float = 1000.0
        for sample: int in range(720):
            var angle: float = TAU * float(sample) / 720.0
            for turn_offset: float in [0.0, .013, .037]:
                outer = maxf(outer, Layer.RADIUS * Layer.profile(index, angle, angle / TAU + turn_offset))
                inner = minf(inner, Layer.RADIUS * Layer.profile(index + 1, angle, angle / TAU + turn_offset))
        var clearance: float = 1000.0
        for step: int in range(61):
            var progress: float = float(step) / 100.0
            if Layer.erosion_amount(progress) < 1.0:
                clearance = minf(clearance, inner * Layer.arrival_scale(progress) - Layer.SHAPE_DETAILS[index + 1].w - outer)
        check(clearance > .1, "Arriving %s shell clears the dissolving %s shell" % [Layer.PASSAGE_NAMES[index + 1], Layer.PASSAGE_NAMES[index]])
    var upright: Basis = Layer.journey_basis(Basis(Vector3.UP, deg_to_rad(40)))
    check(absf(upright.y.dot(Vector3.UP) - 1.0) < .001, "Turned journeys keep the temple floor toward the ground")
    var reclined: Basis = Basis(Vector3.RIGHT, deg_to_rad(80))
    check(Layer.journey_basis(reclined).z.angle_to(reclined.z) < .001, "Reclined journeys keep the gaze axis")
    var layer: Node3D = Layer.new()
    root.add_child(layer)
    check(layer.find_children("*", "Label3D").is_empty(), "No instructional text in the tunnel")
    check(layer.get_node("VioletOutflow").multimesh.instance_count == 32, "Sixteen outflow petals each carry a halo")
    var relic_nodes: Array[MultiMeshInstance3D] = layer.relic_nodes()
    check(relic_nodes.size() == Relics.TYPES.size() and Relics.TYPES.size() >= 24, "At least twenty-four modelled relic types")
    var instances: int = 0
    var per_passage: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
    for type: int in range(relic_nodes.size()):
        var node: MultiMeshInstance3D = relic_nodes[type]
        instances += node.multimesh.instance_count
        per_passage[int(Relics.TYPES[type]["passage"])] += 1
        check(node.multimesh.instance_count >= 4, "Every relic type appears several times in its passage")
        var mesh: Mesh = node.multimesh.mesh
        var faces: int = mesh.get_faces().size() / 3
        check(faces >= 8 and faces <= 1600, "Relic %s stays within the mobile triangle budget (%d)" % [Relics.TYPES[type]["name"], faces])
        var size: Vector3 = mesh.get_aabb().size
        check(minf(size.x, minf(size.y, size.z)) > .05 and maxf(size.x, maxf(size.y, size.z)) <= 1.4, "Relic %s is a solid model, not a flat card" % Relics.TYPES[type]["name"])
        var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
        check(normals.size() == mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), "Relic %s carries normals for matcap shading" % Relics.TYPES[type]["name"])
    check(instances == Relics.COUNT, "Every relic belongs to exactly one type")
    # The shader repeats the motion model, so its constants must match the script's.
    var relic_code: String = (load("res://experiences/visionary_temple/relic.gdshader") as Shader).code
    for constant: String in ["const float PASSAGE = %.1f;" % Relics.PASSAGE, "const float PER_PASSAGE = %.1f;" % float(Relics.PER_PASSAGE), "const float SPEED = %.2f;" % Relics.SPEED, "const float CONTRACTION = %.2f;" % Relics.CONTRACTION, "const float SHELL = %.1f;" % Relics.SHELL]:
        check(relic_code.contains(constant), "Relic shader shares the motion constant " + constant)
    for passage: int in range(8):
        check(per_passage[passage] >= 3, "Each passage has at least three relic types")
        var wall: float = 1000.0
        for sample: int in range(720):
            var angle: float = TAU * float(sample) / 720.0
            for turn_offset: float in [0.0, .013, .037]:
                wall = minf(wall, Layer.RADIUS * Layer.profile(passage, angle, angle / TAU + turn_offset) - Layer.SHAPE_DETAILS[passage].w)
        check(wall > Relics.SHELL + .2, "Relics never reach the %s walls" % Layer.PASSAGE_NAMES[passage])
    var patterns: Dictionary = {}
    var kinds: Dictionary = {}
    var wandering: int = 0
    for g: int in range(Relics.COUNT):
        patterns[int(Relics.h(g, .4142136) * 6.0)] = true
        kinds[Relics.z_kind(g)] = true
        var arrival: float = Relics.arrival_time(g)
        var a: Vector3 = Relics.object_center(g, arrival - 20.0, 0.0)
        var b: Vector3 = Relics.object_center(g, arrival, 0.0)
        if Vector2(a.x - b.x, a.y - b.y).length() > .3:
            wandering += 1
    check(patterns.size() == 6 and kinds.size() == 3, "Relics use six cross-section paths and three along-tunnel motions")
    check(wandering > Relics.COUNT * .75, "Most relics travel across the view, not only toward it")
    var tunnel: MeshInstance3D = layer.get_node("PaintedTunnel")
    var incoming: MeshInstance3D = layer.get_node("IncomingTunnel")
    var rings: Array[Vector2] = Layer.tunnel_rings()
    check(tunnel.mesh.get_faces().size() / 3 == 2 * Layer.AROUND * (rings.size() - 1) and tunnel.mesh.get_faces().size() / 3 <= 150000, "One connected tube within the per-shell triangle budget")
    check(tunnel.mesh.get_aabb().size.z >= 64.9 and incoming.mesh == tunnel.mesh, "Both shells share one 65-meter tube")
    var shared: int = 0
    for index: int in range(rings.size()):
        if rings[index].y < 0.0:
            shared += 1
            check(is_equal_approx(rings[index].x, Layer.BOUNDARY), "The static ring joins the near and far sections")
        elif index > 0:
            check(rings[index].x > rings[index - 1].x and rings[index].x - rings[index - 1].x <= Layer.FAR_SEGMENT + .0001, "Rings advance without gaps")
    check(shared == 1, "Exactly one static ring joins the sections")
    for index: int in range(rings.size() - 1):
        if rings[index].y > 0.0:
            # A travelling ring never passes its neighbour within one conveyor step.
            check(rings[index].x + absf(rings[index].y) <= rings[index + 1].x + .0001, "Conveyor rings stay ordered while they travel")
    for name: String in Layer.PASSAGE_NAMES:
        var tile: Texture2D = load("res://experiences/visionary_temple/tiles/" + name + ".png")
        check(tile != null and tile.get_width() >= 1024 and tile.get_height() >= 1024, "Every passage has a painted tile")
        var relief: Texture2D = load("res://experiences/visionary_temple/tiles/" + name + "_relief.png")
        check(relief != null and relief.get_width() * tile.get_height() == relief.get_height() * tile.get_width(), "Every passage has a relief map matching its painting")
    var sheet: Texture2D = load("res://experiences/visionary_temple/tiles/sigils.png")
    check(sheet != null and sheet.get_width() == 2048 and sheet.get_height() == 1024, "Sigil sprite sheet holds one sigil per passage")
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
    var crowd: int = 0
    for second: int in range(0, 480, 4):
        var time: float = float(second)
        layer._journey = Transform3D(Basis.IDENTITY, head)
        var selected: int = layer.select_source(time, head, Basis.IDENTITY, 0.0)
        if selected < 0:
            missing += 1
        else:
            var present: Vector3 = Relics.object_center(selected, time, 0.0)
            var future: Vector3 = Relics.object_center(selected, time + 6.0, 1.0)
            check(Vector3.FORWARD.dot(present.normalized()) > .87 and Vector3.FORWARD.dot(future.normalized()) > .82, "Selected relic remains in the forward view for six seconds")
        var active: int = 0
        for g: int in range(Relics.COUNT):
            var span: Vector2 = Relics.window(g)
            if time < span.x or time > span.y:
                check(Relics.growth(g, time) < .001, "Relic %d is invisible outside its drawing window" % g)
                continue
            active += 1
            for fill: float in [0.0, .5, 1.0]:
                var center: Vector3 = Relics.object_center(g, time, fill)
                var shell: float = Relics.SHELL * (1.0 - fill * .35)
                check(Vector2(center.x, center.y).length() + Relics.object_extent(g, fill) <= shell + .0001, "Relics remain inside the contracting shell")
                check(Vector2(center.x, center.y).length() > .85, "Relics never cross the central sightline")
        crowd = maxi(crowd, active)
    check(missing == 0, "Every sampled breathing cycle has a visible source relic")
    check(crowd <= 130, "At most 130 relics are drawn at once (%d)" % crowd)
    layer.update_experience({"elapsed": 200.0, "head_position": head, "head_basis": Basis.IDENTITY})
    var slots: int = 0
    for node: MultiMeshInstance3D in layer.relic_nodes():
        slots += node.multimesh.visible_instance_count if node.visible else 0
    check(slots == layer.drawn_relics() and slots > 20, "Relic instance slots hold exactly the drawable relics")
    layer.reset_journey()
    layer.update_experience({"elapsed": 32.0, "head_position": head, "head_basis": basis, "phase_seconds": 0.0})
    var locked: int = layer._source_index
    for frame: int in range(270):
        layer.update_experience({"elapsed": 32.0 + float(frame) / 60.0, "head_position": head, "head_basis": basis, "phase_seconds": float(frame) / 60.0})
        check(layer._source_index == locked, "Plasma never switches source while visible")
    layer.update_experience({"elapsed": 250.0, "head_position": head, "head_basis": basis, "phase_seconds": 2.0})
    var steady: ShaderMaterial = tunnel.material_override
    check((steady.get_shader_parameter("surface") as Texture2D).resource_path.ends_with("rings.png"), "The fifth passage paints the ring tile")
    check(steady.shader.resource_path.ends_with("tunnel.gdshader") and not incoming.visible, "A settled passage draws one solid shell")
    layer.update_experience({"elapsed": 285.0, "head_position": head, "head_basis": basis, "phase_seconds": 5.0})
    var dissolving: ShaderMaterial = tunnel.material_override
    var arriving: ShaderMaterial = incoming.material_override
    check(dissolving.shader.resource_path.ends_with("tunnel_eroding.gdshader") and incoming.visible, "A dissolve opens the ring shell over the arriving one")
    check((dissolving.get_shader_parameter("surface") as Texture2D).resource_path.ends_with("rings.png"), "The dissolving shell keeps the ring painting")
    check((arriving.get_shader_parameter("surface") as Texture2D).resource_path.ends_with("lotus.png"), "The lotus garden arrives behind the rings")
    check((arriving.get_shader_parameter("relief") as Texture2D).resource_path.ends_with("lotus_relief.png"), "The arriving shell carries its own relief")
    check(float(arriving.get_shader_parameter("shell_scale")) > 1.3 and float(dissolving.get_shader_parameter("erosion")) > .5, "Mid-dissolve the arriving shell waits wider while the rings open")
    layer.update_experience({"elapsed": 300.0, "head_position": head, "head_basis": basis, "phase_seconds": 12.0})
    check((tunnel.material_override as ShaderMaterial).shader.resource_path.ends_with("tunnel.gdshader") and not incoming.visible, "The lotus garden becomes the solid shell at the minute")
    check(((tunnel.material_override as ShaderMaterial).get_shader_parameter("surface") as Texture2D).resource_path.ends_with("lotus.png"), "The swap keeps the lotus painting in front")
    print("VISIONARY JOURNEY: ", "PASS" if failures == 0 else "FAIL")
    layer.free()
    quit(failures)
