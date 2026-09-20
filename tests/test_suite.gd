extends SceneTree
## Verify catalog rhythms, exact session bounds, selector routes, and integration.

var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    run.call_deferred()

func check_breath_centers(director: MeditationDirector, id: String) -> void:
    for angles: Vector3 in [Vector3.ZERO, Vector3(1.4, .7, -.25)]:
        director.camera.get_parent().position = Vector3(.3, .65, -.2)
        director.camera.position = Vector3(.1, .2, .3)
        director.camera.rotation = angles
        director._push_visuals(.016)
        var head: Transform3D = director.camera.global_transform
        var center: Vector3 = director.breath_center.global_position
        check((head.affine_inverse() * center).is_equal_approx(Vector3(0, -.18, 0)), id + ": shared reference stays at the neck under head/rig translation, tilt, yaw and roll")
        var incoming: ShaderMaterial
        var outgoing: ShaderMaterial
        var offset: Vector3 = Vector3.ZERO
        if id == "aurora_lake":
            incoming = director.inhale.process_material
            outgoing = director.exhale.process_material
        elif id == "prismatic_sanctuary":
            incoming = director.experience_layer._beams.material_override
            outgoing = director.experience_layer._outflow.material_override
            offset = Vector3(0, -.14, -.12)
        elif id == "visionary_temple":
            incoming = director.experience_layer.get_node("InhalePlasma").material_override
            outgoing = director.experience_layer.get_node("VioletOutflow").material_override
        elif id in ThemeBreath.IDS:
            incoming = director._theme_breath.get_node("ThemedBreathFlow").material_override
            outgoing = incoming
        else:
            check(false, id + ": add the new experience's breath materials to the shared-center contract")
            return
        var target: Vector3 = incoming.get_shader_parameter("inhale_target")
        var origin: Vector3 = outgoing.get_shader_parameter("exhale_origin")
        check((head.basis.inverse() * (target - center)).is_equal_approx(offset), id + ": inhale destination derives from the common center and declared local offset")
        check(origin.is_equal_approx(center), id + ": exhale starts at the common center")
    if id != "aurora_lake":
        # A supplied anchor must win over any independently reconstructed head point.
        var supplied_center: Vector3 = Vector3(4.0, 2.0, -3.0)
        var basis: Basis = director.camera.global_basis
        var state: Dictionary = {"head_position": director.camera.global_position, "head_basis": basis, "breath_center": supplied_center, "elapsed": 120.0, "phase_seconds": 2.0, "breath_fill": .5, "intensity": 1.0, "orb_position": director.orb.global_position}
        if id == "prismatic_sanctuary":
            director.experience_layer.update_experience(state)
            var incoming: ShaderMaterial = director.experience_layer._beams.material_override
            var outgoing: ShaderMaterial = director.experience_layer._outflow.material_override
            check((outgoing.get_shader_parameter("exhale_origin") as Vector3).is_equal_approx(supplied_center), "Prismatic respects the supplied center")
            check((incoming.get_shader_parameter("inhale_target") as Vector3).is_equal_approx(supplied_center + basis * Vector3(0, -.14, -.12)), "Prismatic heart offset is relative to the supplied center")
        elif id == "visionary_temple":
            director.experience_layer.update_experience(state)
            var incoming: ShaderMaterial = director.experience_layer.get_node("InhalePlasma").material_override
            var outgoing: ShaderMaterial = director.experience_layer.get_node("VioletOutflow").material_override
            check((incoming.get_shader_parameter("inhale_target") as Vector3).is_equal_approx(supplied_center), "Visionary inhale respects the supplied neck center")
            check((outgoing.get_shader_parameter("exhale_origin") as Vector3).is_equal_approx(supplied_center), "Visionary exhale respects the supplied neck center")
        else:
            var cue: ThemeBreath = director._theme_breath
            cue.inhale_offset = Vector3(.03, -.04, -.05)
            cue.exhale_offset = Vector3(-.02, .01, -.03)
            cue.update_experience(state)
            var material: ShaderMaterial = cue.get_node("ThemedBreathFlow").material_override
            check((material.get_shader_parameter("inhale_target") as Vector3).is_equal_approx(supplied_center + basis * cue.inhale_offset), id + ": optional inhale offset uses the supplied reference")
            check((material.get_shader_parameter("exhale_origin") as Vector3).is_equal_approx(supplied_center + basis * cue.exhale_offset), id + ": optional exhale offset uses the supplied reference")
            cue.inhale_offset = Vector3.ZERO
            cue.exhale_offset = Vector3.ZERO
        director._push_visuals(.016)

func run() -> void:
    # Exercise the real engine API even when desktop tests never enter XR mode.
    var interface: OpenXRInterface = OpenXRInterface.new()
    check(not ExperienceMath.xr_session_focused(interface), "Uninitialized XR session is not focused")
    check(not ExperienceMath.xr_session_running(interface), "Uninitialized XR session is not running")
    var entries: Array = ExperienceCatalog.all()
    check(entries.size() == 9, "Nine authored experiences")
    # Revisit the lake after every variant to catch shared Environment mutation.
    entries.append(entries[0])
    for entry: Dictionary in entries:
        root.set_meta("experience_id", entry["id"])
        var scene: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(scene)
        await process_frame
        var director: MeditationDirector = scene.get_node("Director")
        var clock: BreathClock = director.clock
        var r: Array = entry["rhythm"]
        check(absf(director.music.stream.get_length() - 480.0) < 0.02, str(entry["id"]) + " exact eight-minute music")
        check(absf(director.breath.stream.get_length() - clock.loop_seconds) < 0.001, "Audio agrees with rhythm")
        clock.update_from_position(float(r[0]) * 0.5, 40.0)
        check(clock.is_inhale and not clock.is_pause and not clock.is_exhale, "Inhale classification")
        check(absf(clock.breath_fill - 0.5) < 0.001, "Inhale fill is smooth midpoint")
        clock.update_from_position(float(r[0]) + float(r[1]) + float(r[2]) * 0.5, 40.0)
        check(clock.is_exhale and not clock.is_pause and not clock.is_inhale, "Exhale classification")
        if r[1] > 0:
            clock.update_from_position(float(r[0]) + float(r[1]) * 0.5, 40.0)
            check(clock.is_pause and is_equal_approx(clock.breath_fill, 1.0), "Full hold retains fill")
        if r[3] > 0:
            clock.update_from_position(clock.loop_seconds - float(r[3]) * 0.5, 40.0)
            check(clock.is_pause and clock.is_empty_pause and is_zero_approx(clock.breath_fill), "Empty rest retains empty fill")
        clock.update_from_position(clock.loop_seconds - 0.0001, 40.0)
        var boundary: float = clock.incoming_visibility()
        clock.update_from_position(0.0, 40.0)
        check(absf(boundary - clock.incoming_visibility()) < 0.001, "Incoming pre-cue is continuous")
        director.elapsed = 120.0
        director.fade = 0.0
        director._push_visuals(0.016)
        check_breath_centers(director, entry["id"])
        check(director.experience_layer != null or entry["id"] == "aurora_lake", "Layer instantiated")
        if entry["id"] in ThemeBreath.IDS:
            var cue: ThemeBreath = director._theme_breath
            check(cue != null and cue.is_inside_tree(), "Theme cue is integrated")
            check(cue.theme == ThemeBreath.IDS.find(entry["id"]), "Every world selects its own visual breath language")
            check(not director.orb.visible and not director.exhale.visible, "Theme cue replaces the shared golden orb and blue outflow")
            check(cue.find_children("*", "Label3D").is_empty() and director.experience_layer.find_children("*", "Label3D").is_empty(), "World and breathing cues contain no words")
            director.camera.get_parent().position = Vector3(0.3,0.65,-0.2)
            director.camera.rotation.x = deg_to_rad(85)
            director._gaze_direction = -director.camera.global_basis.z
            director._follow_orb(10.0)
            director._push_visuals(.016)
            var material: ShaderMaterial = cue.get_node("ThemedBreathFlow").material_override
            check(material.get_shader_parameter("head_forward").distance_to(-director.camera.global_basis.z)<.001, "Breath paths use the reclined head basis")
            check(material.get_shader_parameter("inhale_target").distance_to(director.breath_center.global_position)<.001, "Inhale reaches the shared neck center")
            check(material.get_shader_parameter("exhale_origin").distance_to(director.breath_center.global_position)<.001, "Exhale starts at the shared neck center")
            check(material.get_shader_parameter("focus_position").distance_to(director.camera.global_position)>1.0, "Focal sculpture stays outside the face")
            var triangle_count: int = count_triangles(scene)
            check(triangle_count<900000, "Per-world geometry budget below 900k triangles")
            print("THEME BUDGET ",entry["id"]," triangles=",triangle_count)
        if entry["id"] == "aurora_lake":
            check(scene.get_node("WorldEnvironment").environment.background_mode == Environment.BG_SKY, "Lake sky survives returning from variants")
        if entry["id"] in MeditationDirector.JOURNEY_IDS:
            director._start_session()
            await process_frame
            check(director.music.playing and director.breath.playing, "Tunnel journeys start their single score and breath guide")
            check(director.music.stream.resource_path == "res://" + str(entry["music"]), "Only the selected score is routed to music playback")
            for player: AudioStreamPlayer3D in director._spatial_audio:
                check(not player.playing, "Lake and mote audio cannot overlay a journey score")
            check(not director.orb.visible and not director.exhale.visible, "Journeys replace the golden orb and blue outflow")
            check(float(director.tier["refresh_rate"]) == 72.0, "Journeys request the 72 Hz cadence")
            check(director.experience_layer.has_method("focal_position") and director.experience_layer.find_children("*", "Label3D").is_empty(), "Journey layers expose a wordless distant focal light")
        check(clock.settle_at() <= 480.0, "No partial final cycle")
        scene.queue_free()
        await process_frame
    root.remove_meta("experience_id")
    var menu: Node = load("res://scenes/startup.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    check(menu.cards.size() == 9, "All experiences are selectable")
    var camera: XRCamera3D = menu.camera
    camera.rotation.x = deg_to_rad(80)
    menu._anchor()
    check(menu.panel.global_position.distance_to(camera.global_position - camera.global_basis.z * 2.5) < 0.001, "Selector anchors in reclining gaze")
    current_scene = menu
    var key_event: InputEventKey = InputEventKey.new()
    key_event.keycode = KEY_6
    key_event.pressed = true
    menu._unhandled_input(key_event)
    await create_timer(0.9).timeout
    var selected_scene: Node = current_scene
    check(selected_scene != null and selected_scene.has_node("Director"), "Selector loads the experience scene")
    var selected_director: MeditationDirector = selected_scene.get_node("Director")
    check(selected_director.experience_id == "neural_constellation", "Selection routes to correct experience")
    await selected_director._finish_exit()
    await process_frame
    await process_frame
    check(current_scene != null and current_scene.get_script().resource_path == "res://scripts/startup_menu.gd", "Session completion returns to selector")
    current_scene.queue_free()
    await process_frame
    print("EXPERIENCE SUITE: ", "PASS" if failures == 0 else "FAIL")
    quit(failures)

func count_triangles(node: Node) -> int:
    var total: int = 0
    if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
        total += node.multimesh.mesh.get_faces().size()/3 * node.multimesh.instance_count
    elif node is MeshInstance3D and node.mesh != null:
        total += node.mesh.get_faces().size()/3
    for child: Node in node.get_children():
        total += count_triangles(child)
    return total
