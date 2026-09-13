extends SceneTree
## Integration contracts for audio timing, timeline, scene budgets, and exits.

var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func close(actual: float, expected: float, message: String, tolerance: float = 0.002) -> void:
    check(absf(actual - expected) <= tolerance, message + ": got " + str(actual) + ", expected " + str(expected))

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var clock: BreathClock = BreathClock.new()
    var signals: Array[int] = [0, 0, 0]
    clock.inhale_started.connect(func() -> void: signals[0] += 1)
    clock.pause_started.connect(func() -> void: signals[1] += 1)
    clock.exhale_started.connect(func() -> void: signals[2] += 1)
    for seconds: float in [0.0, 3.999, 4.0, 5.999, 6.0, 13.999, 14.0, 18.0, 20.0, 27.999, 28.0]:
        var phase: float = fmod(seconds, 14.0)
        clock.update_from_position(phase, seconds)
        check(clock.is_inhale == (phase < 4.0), "4-second inhale boundary")
        check(clock.is_pause == (phase >= 4.0 and phase < 6.0), "2-second pause boundary")
        check(clock.is_exhale == (phase >= 6.0), "8-second exhale boundary")
        close(clock.phase, phase / 14.0, "Audio phase")
    check(signals == [3, 2, 2], "Signals fire once per distinct phase boundary")
    check(ExperienceMath.inhale_gate(1.0) > 0.99, "Inhale gently reaches full intensity")
    check(ExperienceMath.inhale_gate(3.5) > 0.2, "Incoming stream remains visible while tapering late in inhale")
    close(ExperienceMath.inhale_visibility(3.325), 0.5, "Long gentle fade into the pause")
    close(ExperienceMath.inhale_visibility(4.0), 0, "Pause has no incoming stream")
    for length: float in [12.0, 14.0]:
        close(ExperienceMath.inhale_visibility(length - 1.5, length), 0, "Lead-in begins at zero")
        check(ExperienceMath.inhale_visibility(length - 1.0, length) > 0, "Incoming particles gather before inhale cue")
        close(ExperienceMath.inhale_visibility(length - 0.0001, length), ExperienceMath.inhale_visibility(0.0, length), "Visibility continuous at inhale cue")
        close(ExperienceMath.inhale_front(length - 0.0001, length), ExperienceMath.inhale_front(0.0, length), "Reveal front continuous at inhale cue")
        check(ExperienceMath.inhale_front(length - 1.0, length) < 0.25, "Early lead-in stays near the orb")
        close(ExperienceMath.inhale_front(0.5, length), 1.14, "Full route visible early in inhale")
    close(ExperienceMath.exhale_gate(5.0), 0, "No exhale during pause")
    close(ExperienceMath.exhale_gate(7.0), 1, "Exhale open after pause")
    close(ExperienceMath.exhale_gate(13.0), 0.5, "Exhale final two-second ramp")
    close(ExperienceMath.exhale_gate(14.0), 0, "Exhale complete")
    clock.ratio_ramp = true
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    root.add_child(player)
    clock.configure(player)
    close(clock.loop_seconds, 12, "Optional ramp starts at 4/2/6")
    clock.update_from_position(6, 114)
    check(clock.cycle_index == 9 and clock.is_exhale, "Tenth short-cycle exhale")
    player.play()
    clock.sample(player, 120)
    close(clock.loop_seconds, 14, "Ramp switches to long loop")
    check(player.stream.resource_path.ends_with("breath_14s.wav"), "Actual audio stream switched")
    clock.update_from_position(0, 120)
    check(clock.cycle_index == 10 and clock.is_inhale, "First long cycle boundary")
    player.stop()
    player.stream = null
    player.queue_free()
    clock.free()
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    director.set_process(false)
    var arc: AnimationPlayer = director.get_node("AnimationPlayer")
    for entry: Array in [[0, 0.3, 0, 40, 0, 1], [180, 0.6, 0, 40, 0, 0], [300, 1.2, 0.35, 40, 0.3, 0], [420, 1.2, 1, 8, 1, 0], [480, 0.5, 0.3, 40, 0, 1]]:
        arc.seek(float(entry[0]), true)
        close(director.aurora_intensity, float(entry[1]), "Aurora at " + str(entry[0]))
        close(director.fractal_mix, float(entry[2]), "Fractal at " + str(entry[0]))
        close(director.field_radius, float(entry[3]), "Radius at " + str(entry[0]))
        close(director.field_amount, float(entry[4]), "Amount at " + str(entry[0]))
        close(director.fade, float(entry[5]), "Fade at " + str(entry[0]))
    arc.seek(90.0, true)
    check(director.aurora_intensity > 0.3 and director.aurora_intensity < 0.6, "Timeline interpolation")
    arc.seek(476, true)
    close(director.breath_particles_enabled, 0, "Final emission cutoff")
    var orb: Node3D = scene.get_node("Orb")
    check(orb.position.is_equal_approx(Vector3(0, 1.4, -ExperienceMath.ORB_DISTANCE)), "Initial orb placement")
    check(director.inhale.amount == 600 and director.exhale.amount == 1500 and director.halo.amount == 300, "Breath particle budgets")
    check(director.field.amount == (30000 if "--quest3" in OS.get_cmdline_user_args() else 12000), "Per-tier field count")
    check(ExperienceMath.tier_for("Meta Quest 3S")["field_count"] == 30000, "Q3S tier")
    check(ExperienceMath.tier_for("unknown")["sky_samples"] == 4, "Unknown hardware uses Q2")
    check(not director.exhale.local_coords, "Exhale lives in world space")
    # Simulate a translated, turned headset: targets must follow the tracked pose.
    director.camera.position = Vector3(0.35, 1.62, 0.2)
    director.camera.rotation.y = deg_to_rad(65.0)
    var initial_orb: Vector3 = orb.global_position
    director._follow_orb(1.0 / 90.0)
    check(orb.global_position.distance_to(initial_orb) < 0.05, "Orb does not snap on a head turn")
    for frame: int in range(540):
        director._follow_orb(1.0 / 90.0)
    var forward: Vector3 = -director.camera.global_basis.z.normalized()
    check((orb.global_position - director.camera.global_position).normalized().angle_to(forward) < deg_to_rad(4.0), "Orb catches up to gaze")
    close(orb.global_position.distance_to(director.camera.global_position), ExperienceMath.ORB_DISTANCE, "Orb settles at comfortable distance", 0.03)
    director.clock.update_from_position(7.0, 35.0)
    director._push_visuals(0.0)
    var exhale_material: ShaderMaterial = director.exhale.process_material
    check((exhale_material.get_shader_parameter("mouth_position") as Vector3).is_equal_approx(director.mouth.global_position), "Exhale starts at tracked world mouth")
    check((exhale_material.get_shader_parameter("mouth_basis") as Basis).is_equal_approx(director.mouth.global_basis), "Exhale follows tracked orientation")
    check(exhale_material.get_shader_parameter("exhale_active"), "Outgoing particles active during exhale")
    close(exhale_material.get_shader_parameter("exhale_visibility"), 1.0, "Exhale fully visible")
    director.clock.update_from_position(13.95, 41.95)
    director._push_visuals(0.0)
    check(float(exhale_material.get_shader_parameter("exhale_visibility")) < 0.01, "Exhale clears before inhale")
    director.clock.update_from_position(0.1, 42.1)
    director._push_visuals(0.0)
    check(not exhale_material.get_shader_parameter("exhale_active"), "Old exhale particles killed during inhale")
    close(exhale_material.get_shader_parameter("exhale_visibility"), 0.0, "No outgoing cloud during inhale")
    check((director.inhale.process_material.get_shader_parameter("mouth_target") as Vector3).is_equal_approx(director.mouth.global_position), "Inhale converges to tracked world mouth")
    director.clock.update_from_position(5.0, 33.0)
    director._push_visuals(0.0)
    check(director.clock.is_pause, "Hold phase exposed to all effects")
    close(director.inhale.process_material.get_shader_parameter("inhale_visibility"), 0.0, "Incoming stream invisible in pause")
    close(director.exhale.amount_ratio, 0.0, "No outgoing emission in pause")
    check(not exhale_material.get_shader_parameter("exhale_active"), "No lingering outgoing particles in pause")
    close(director.clock.breath_fill, 1.0, "Water and curtains hold expansion during pause")
    arc.seek(13.5, true)
    director.elapsed = 13.5
    director.clock.update_from_position(13.5, 13.5)
    director._push_visuals(0.0)
    check(float(director.inhale.process_material.get_shader_parameter("inhale_visibility")) > 0.2, "First visible inhale also has a lead-in")
    arc.seek(475, true)
    director.elapsed = 475.0
    director.clock.update_from_position(13.0, 475.0)
    director._push_visuals(0.0)
    close(director.inhale.process_material.get_shader_parameter("inhale_visibility"), 0.0, "Final settle does not cue an extra inhale")
    check(scene.get_node("NearAuroras").get_child_count() == 3, "Three finite-distance aurora layers")
    var orb_core: GPUParticles3D = scene.get_node("Orb/Core")
    check(orb_core.amount == 192 and orb_core.local_coords, "Orb core is a local particle cloud")
    close(orb_core.scale.x, 1.0, "Orb width remains unchanged")
    close(orb_core.scale.y, 1.6, "Orb is taller")
    close(ExperienceMath.ORB_DISTANCE, 1.8288, "Six-foot orb distance")
    for phase: float in [0.0, 4.0, 5.5, 10.0, 13.999]:
        director.clock.update_from_position(phase, 28.0 + phase)
        director._push_visuals(0.0)
        close(director.core_material.get_shader_parameter("breath_scale"), 1.0 - director.clock.breath_fill * 0.24, "Orb gives volume to inhale and recovers on exhale")
    var drift_min: Vector3 = Vector3.ONE
    var drift_max: Vector3 = -Vector3.ONE
    for step: int in range(1, 481):
        var drift: Vector3 = ExperienceMath.orb_drift(float(step))
        drift_min = drift_min.min(drift)
        drift_max = drift_max.max(drift)
        check(drift.length() < 0.37, "Orb wander remains near comfortable gaze distance")
        check(drift.distance_to(ExperienceMath.orb_drift(float(step) - 0.01)) < 0.0012, "Orb wanders without jerks")
    check((drift_max - drift_min).x > 0.2 and (drift_max - drift_min).y > 0.2 and (drift_max - drift_min).z > 0.2, "Orb drifts along all three axes")
    for cluster: int in range(5):
        var duration: float = 20.0 + float(cluster) * 2.3
        var epoch: int = (3 - cluster % 3) % 3
        var midpoint: float = (float(epoch) + 0.5) * duration - float(cluster) * 4.7
        var visit: Dictionary = ExperienceMath.mote_cluster(midpoint, cluster)
        var distance: float = (visit["position"] as Vector3).distance_to(Vector3(0, 1.4, 0))
        check(visit["visiting"] and distance >= 2.09 and distance <= 2.81, "Every mote group sometimes visits closer")
        var next: Dictionary = ExperienceMath.mote_cluster(midpoint + duration, cluster)
        check(visit["color"] != next["color"], "Mote colors vary between appearances")
        director._update_mote_audio(cluster, visit)
        check(director._mote_audio[cluster].global_position.is_equal_approx(visit["position"]), "Spatial voice follows its own mote cluster")
    check(director.ambient_motes.amount == 360, "Sparse ambient mote budget")
    check(director._spatial_audio.size() == 8 and director._mote_audio.size() == 5, "Three positional water beds and five independent mote voices")
    for index: int in range(3):
        var water_audio: AudioStreamPlayer3D = scene.get_node("Audio/Water" + str(index))
        check((water_audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Spatial water loops")
    for spatial_player: AudioStreamPlayer3D in director._spatial_audio:
        spatial_player.play()
    await physics_frame
    await physics_frame
    for cluster: int in range(5):
        var duration: float = 20.0 + float(cluster) * 2.3
        var boundary: float = duration * 3.0 - float(cluster) * 4.7
        var before: Dictionary = ExperienceMath.mote_cluster(boundary - 0.001, cluster)
        var after: Dictionary = ExperienceMath.mote_cluster(boundary + 0.001, cluster)
        check(float(before["visibility"]) < 0.001 and float(after["visibility"]) < 0.001, "Mote pockets change location only while invisible")
        check((before["position"] as Vector3).distance_to(after["position"]) > 0.25, "Motes reappear in a different location")
        var middle: Dictionary = ExperienceMath.mote_cluster(boundary + 8.0, cluster)
        var later: Dictionary = ExperienceMath.mote_cluster(boundary + 9.0, cluster)
        var drift: float = (middle["position"] as Vector3).distance_to(later["position"])
        check(drift > 0.005 and drift < 0.85, "Mote pockets drift and approach gradually")
        if cluster >= 2:
            check(((middle["position"] as Vector3) - Vector3(0, 1.4, 0)).normalized().y > 0.5, "Overhead motes cover a reclined viewer even on closer visits")
    director._on_unfocus()
    check(director._spatial_audio.all(func(player: AudioStreamPlayer3D) -> bool: return player.stream_paused), "Spatial ambience pauses with headset focus")
    director._on_focus()
    check(director._spatial_audio.all(func(player: AudioStreamPlayer3D) -> bool: return not player.stream_paused), "Spatial ambience resumes with headset focus")
    var stream: AudioStreamWAV = load("res://assets/audio/breath_14s.wav")
    close(stream.get_length(), 14, "Sample-exact breath loop")
    check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Breath loop enabled on import")
    close(director.music.stream.get_length(), 480, "Full music duration", 0.1)
    for time: float in [0, 60, 160, 300]:
        var transforms: Array[Transform3D] = ExperienceMath.ifs_transforms(time, clampf(time / 300.0, 0.0, 1.0))
        for index: int in range(30000):
            var point: Vector3 = ExperienceMath.ifs_point((index * 1048583 + 7919) & 16777215, transforms)
            check(point.is_finite() and point.length() < 3.0, "IFS bounded position")
    director._on_button_pressed(&"ax_touch", &"left_hand")
    check(director._held.is_empty(), "Capacitive touch does not request exit")
    director._on_button_pressed(&"ax_button", &"left_hand")
    director._on_tracker_removed(&"left_hand", XRServer.TRACKER_CONTROLLER)
    check(director._held.is_empty(), "Removed controller cannot leave an exit button held")
    director.fade = 0.0
    director._on_button_pressed(&"ax_button", &"left_hand")
    director._advance_exit(1.49)
    check(not director._exiting, "Short hold cannot exit")
    director._advance_exit(0.011)
    check(director._exiting, "1.5-second hold requests exit")
    close(director._exit_elapsed, 0, "Exit fade begins after hold threshold")
    director._advance_exit(1.0)
    close(director.fade, 0.5, "Two-second exit fade midpoint", 0.005)
    director.music.stop()
    director.breath.stop()
    director.music.stream = null
    director.breath.stream = null
    for spatial_player: AudioStreamPlayer3D in director._spatial_audio:
        spatial_player.stop()
        spatial_player.stream = null
    await create_timer(0.25).timeout
    print("SESSION CONTRACTS: ", "PASS" if failures == 0 else str(failures) + " FAILURES")
    scene.queue_free()
    await process_frame
    # Let the mixer thread release stopped playbacks before exit; the dummy audio
    # driver on a headless Linux runner otherwise reports the lake streams as leaked.
    await create_timer(0.3).timeout
    await process_frame
    quit(1 if failures else 0)
