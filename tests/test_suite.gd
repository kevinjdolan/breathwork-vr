extends SceneTree
## Verify catalog rhythms, exact session bounds, selector routes, and integration.

var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    # Exercise the real engine API even when desktop tests never enter XR mode.
    var interface: OpenXRInterface = OpenXRInterface.new()
    check(not ExperienceMath.xr_session_focused(interface), "Uninitialized XR session is not focused")
    check(not ExperienceMath.xr_session_running(interface), "Uninitialized XR session is not running")
    var entries: Array = ExperienceCatalog.all()
    check(entries.size() == 8, "Eight authored experiences")
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
            check(material.get_shader_parameter("mouth_position").distance_to(director.mouth.global_position)<.001, "Breath reaches the tracked mouth")
            check(material.get_shader_parameter("focus_position").distance_to(director.camera.global_position)>1.0, "Focal sculpture stays outside the face")
            var triangle_count: int = count_triangles(scene)
            check(triangle_count<900000, "Per-world geometry budget below 900k triangles")
            print("THEME BUDGET ",entry["id"]," triangles=",triangle_count)
        if entry["id"] == "aurora_lake":
            check(scene.get_node("WorldEnvironment").environment.background_mode == Environment.BG_SKY, "Lake sky survives returning from variants")
        if entry["id"] == "prismatic_sanctuary":
            director._start_session()
            await process_frame
            check(director.music.playing and director.breath.playing, "Prismatic starts its single score and breath guide")
            check(director.music.stream.resource_path == "res://assets/audio/prismatic_sanctuary.ogg", "Only the selected score is routed to music playback")
            for player: AudioStreamPlayer3D in director._spatial_audio:
                check(not player.playing, "Lake and mote audio cannot overlay the prismatic score")
        check(clock.settle_at() <= 480.0, "No partial final cycle")
        scene.queue_free()
        await process_frame
    root.remove_meta("experience_id")
    var menu: Node = load("res://scenes/startup.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    check(menu.cards.size() == 8, "All experiences are selectable")
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
