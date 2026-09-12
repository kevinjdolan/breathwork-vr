class_name MeditationDirector
extends Node
## Owns session state, XR lifecycle, audio transport, and every visual uniform.

@export var aurora_intensity: float = 0.3
@export var aurora_saturation: float = 0.0
@export var fractal_mix: float = 0.0
@export var fractal_morph_rate: float = 0.2
@export var field_amount: float = 0.0
@export var field_radius: float = 40.0
@export var ripple_amp: float = 0.3
@export var exhale_reach: float = 0.4
@export var breath_particles_enabled: float = 0.0
@export var breath_lowpass: float = 6000.0
@export var fade: float = 1.0
@export var fractal_fold: float = 3.0

var session_menu: SessionMenu
var experience_id: String = "aurora_lake"
var experience: Dictionary
var experience_layer: Node3D
var _return_to_menu: bool = false

var elapsed: float = 0.0
var breath_energy: float = 0.0
var tier: Dictionary
var _started: bool = false
var _field_initialized: bool = false
var _exiting: bool = false
var _quitting: bool = false
var _exit_elapsed: float = 0.0
var _exit_initial_fade: float = 0.0
var _held: Dictionary = {}
var _morph: float = 0.0
var _burst: float = 0.0
var _sky_energy: float = 0.0
var _xr: OpenXRInterface
var _capture_time: float = -1.0
var _capture_frames: int = 0
var _capture_path: String = ""
var _test_mode: bool = false
var _gaze_direction: Vector3 = Vector3.FORWARD
var _review_path: String = ""
var _review_elapsed: float = 0.0
var _review_duration: float = 24.0
var _review_start: float = 28.0
var _review_next_frame: float = 0.0
var _review_turn: bool = false
var _review_recline: bool = false
var _perf_elapsed: float = 0.0
var _perf_frames: int = 0
var _perf_worst: float = 0.0
var _spatial_audio: Array[AudioStreamPlayer3D] = []
var _visual_materials: Array[ShaderMaterial] = []
var _ripple_origin: Vector2 = Vector2.ZERO
var _hand_materials: Array[ShaderMaterial] = []
var _hand_joints: Array[PackedVector4Array] = []
var _hand_confidence: Array[PackedFloat32Array] = []
var _hand_tracked: Array[bool] = [false, false]
var _mote_audio: Array[AudioStreamPlayer3D] = []
var _mote_cues: Array[int] = [-1, -1, -1, -1, -1]

@onready var ambient_motes: GPUParticles3D = get_node("../AmbientMotes")

@onready var orb: Node3D = get_node("../Orb")
@onready var movement_trail: GPUParticles3D = get_node("../Orb/MovementTrail")

@onready var clock: BreathClock = get_node("../BreathClock")
@onready var music: AudioStreamPlayer = get_node("../Audio/Music")
@onready var breath: AudioStreamPlayer = get_node("../Audio/Breath")
@onready var camera: XRCamera3D = get_node("../XROrigin3D/XRCamera3D")
@onready var mouth: Marker3D = get_node("../XROrigin3D/XRCamera3D/MouthTarget")
@onready var inhale: GPUParticles3D = get_node("../Orb/InhaleStream")
@onready var exhale: GPUParticles3D = get_node("../XROrigin3D/XRCamera3D/MouthTarget/ExhaleStream")
@onready var halo: GPUParticles3D = get_node("../Orb/Halo")
@onready var field: GPUParticles3D = get_node("../FractalField")
@onready var sky_material: ShaderMaterial = (get_node("../WorldEnvironment") as WorldEnvironment).environment.sky.sky_material
@onready var water_material: ShaderMaterial = (get_node("../Water") as MeshInstance3D).material_override
@onready var core_material: ShaderMaterial = (get_node("../Orb/Core") as GPUParticles3D).process_material
@onready var fade_mesh: MeshInstance3D = get_node("../Fade")
@onready var arc: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    # Each visit owns background state; returning to the lake restores its sky.
    var world: WorldEnvironment = get_node("../WorldEnvironment")
    world.environment = world.environment.duplicate()
    experience_id = str(get_tree().root.get_meta("experience_id", "aurora_lake"))
    _return_to_menu = bool(get_tree().root.get_meta("from_menu", false))
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--experience="):
            experience_id = arg.get_slice("=", 1)
        elif arg == "--test":
            _test_mode = true
        elif arg.begins_with("--capture="):
            _capture_time = float(arg.get_slice("=", 1))
        elif arg.begins_with("--capture-path="):
            _capture_path = arg.get_slice("=", 1)
        elif arg.begins_with("--review-path="):
            _review_path = arg.get_slice("=", 1)
        elif arg.begins_with("--review-duration="):
            _review_duration = float(arg.get_slice("=", 1))
        elif arg.begins_with("--review-start="):
            _review_start = float(arg.get_slice("=", 1))
        elif arg == "--review-recline":
            _review_recline = true
        elif arg == "--review-turn":
            _review_turn = true
    _visual_materials = [sky_material, water_material]
    for hand: Node in get_node("../ParticleHands").get_children():
        _hand_materials.append((hand as GPUParticles3D).process_material as ShaderMaterial)
        var joints: PackedVector4Array = PackedVector4Array()
        var confidence: PackedFloat32Array = PackedFloat32Array()
        joints.resize(XRHandTracker.HAND_JOINT_MAX)
        confidence.resize(XRHandTracker.HAND_JOINT_MAX)
        _hand_joints.append(joints)
        _hand_confidence.append(confidence)
    for child: Node in get_node("../NearAuroras").get_children():
        _visual_materials.append((child as MeshInstance3D).material_override as ShaderMaterial)
    for child: Node in get_node("../Audio").get_children():
        if child is AudioStreamPlayer3D:
            _spatial_audio.append(child as AudioStreamPlayer3D)
            if String(child.name).begins_with("MoteVoice"):
                _mote_audio.append(child as AudioStreamPlayer3D)
    tier = ExperienceMath.tier_for(OS.get_model_name())
    if "--quest3" in OS.get_cmdline_user_args():
        tier = ExperienceMath.tier_for("Quest 3")
    field.amount = int(tier["field_count"])
    for material: ShaderMaterial in [sky_material, water_material]:
        material.set_shader_parameter("slab_samples", int(tier["sky_samples"]))
    # All points are initialized together, then revealed by uniforms. With a
    # persistent lifetime, amount_ratio alone cannot reveal dormant addresses.
    field.amount_ratio = 1.0
    clock.exhale_started.connect(_on_exhale)
    _parent_fade.call_deferred()
    music.finished.connect(_on_music_finished)
    arc.play("arc")
    arc.pause()
    arc.seek(0.0, true)
    _configure_experience()
    clock.configure(breath)
    session_menu = SessionMenu.new()
    session_menu.camera = camera
    session_menu.opened.connect(_on_unfocus)
    session_menu.continued.connect(_on_focus)
    session_menu.return_requested.connect(_return_from_session_menu)
    add_child(session_menu)
    if _test_mode:
        set_process(false)
        return
    _xr = XRServer.find_interface("OpenXR") as OpenXRInterface
    if _xr != null and _xr.is_initialized():
        get_viewport().use_xr = true
        if ExperienceMath.xr_session_running(_xr):
            _on_session_begun.call_deferred()
        _xr.session_begun.connect(_on_session_begun)
        _xr.session_focussed.connect(_on_focus)
        _xr.session_visible.connect(_on_unfocus)
        _xr.pose_recentered.connect(_recenter)
        XRServer.tracker_added.connect(_on_tracker_added)
        XRServer.tracker_removed.connect(_on_tracker_removed)
        for tracker_name: StringName in XRServer.get_trackers(XRServer.TRACKER_CONTROLLER):
            _connect_tracker(tracker_name)
    else:
        (camera.get_parent() as XROrigin3D).position = Vector3(0, 1.4, 0)
        camera.position = Vector3.ZERO
        if _review_recline:
            camera.rotation.x = deg_to_rad(80.0)
            (camera.get_parent() as XROrigin3D).position.y = 0.65
        _start_session()

func _on_session_begun() -> void:
    _recenter()
    if _xr.is_foveation_supported():
        _xr.foveation_level = 2
    var rates: Array = _xr.get_available_display_refresh_rates()
    if float(tier["refresh_rate"]) in rates:
        _xr.display_refresh_rate = float(tier["refresh_rate"])
    _start_session()

func _recenter() -> void:
    XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)

func _start_session() -> void:
    if _started:
        return
    _started = true
    _gaze_direction = -camera.global_basis.z.normalized()
    orb.global_position = camera.global_position + _gaze_direction * ExperienceMath.ORB_DISTANCE
    orb.global_position.y = maxf(0.45, orb.global_position.y)
    print("VRMED START model=", OS.get_model_name(), " tier=", tier, " head=", camera.global_position, " mouth=", mouth.global_position)
    _initialize_field.call_deferred()
    if not _review_path.is_empty():
        DirAccess.make_dir_recursive_absolute(_review_path)
        music.play(_review_start)
        breath.play(fmod(_review_start, clock.loop_seconds))
    elif _capture_time >= 0.0:
        music.play(_capture_time)
        breath.play(fmod(_capture_time, clock.loop_seconds))
    else:
        music.play()
        breath.play()
    if experience_id in ["aurora_lake", "tidal_origami"]:
        for index: int in range(3):
            (get_node("../Audio/Water" + str(index)) as AudioStreamPlayer3D).play(float(index) * 9.3)

func _on_focus() -> void:
    var paused: bool = session_menu != null and session_menu.is_open
    music.stream_paused = paused
    breath.stream_paused = paused
    for player: AudioStreamPlayer3D in _spatial_audio:
        player.stream_paused = paused

func _on_unfocus() -> void:
    (inhale.process_material as ShaderMaterial).set_shader_parameter("inhale_visibility", 0.0)
    (exhale.process_material as ShaderMaterial).set_shader_parameter("exhale_visibility", 0.0)
    (exhale.process_material as ShaderMaterial).set_shader_parameter("exhale_active", false)
    music.stream_paused = true
    breath.stream_paused = true
    for player: AudioStreamPlayer3D in _spatial_audio:
        player.stream_paused = true
    _held.clear()

func _on_tracker_added(tracker_name: StringName, _type: int) -> void:
    _connect_tracker(tracker_name)

func _connect_tracker(tracker_name: StringName) -> void:
    var tracker: XRPositionalTracker = XRServer.get_tracker(tracker_name) as XRPositionalTracker
    if tracker == null or tracker.type != XRServer.TRACKER_CONTROLLER:
        return
    var pressed: Callable = _on_button_pressed.bind(tracker_name)
    if not tracker.button_pressed.is_connected(pressed):
        tracker.button_pressed.connect(pressed)
        tracker.button_released.connect(_on_button_released.bind(tracker_name))

func _on_button_pressed(button: StringName, tracker: StringName) -> void:
    if String(button).ends_with("_touch"):
        return
    var source: XRPositionalTracker = XRServer.get_tracker(tracker) as XRPositionalTracker
    if source != null:
        var hand_path: StringName = &"/user/hand_tracker/left" if source.hand == XRPositionalTracker.TRACKER_HAND_LEFT else &"/user/hand_tracker/right"
        var hand: XRHandTracker = XRServer.get_tracker(hand_path) as XRHandTracker
        if hand != null and hand.has_tracking_data and hand.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER:
            # Optical pinch/grab input can emulate controller buttons. Merely
            # holding a hand pose must not terminate the meditation.
            return
    _held[String(tracker) + ":" + String(button)] = 0.0

func _on_button_released(button: StringName, tracker: StringName) -> void:
    _held.erase(String(tracker) + ":" + String(button))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and not event.is_echo():
        if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_SPACE:
            if event.pressed:
                _held["desktop"] = 0.0
            else:
                _held.erase("desktop")
    if event is InputEventJoypadButton:
        var key: String = "gamepad:" + str(event.device) + ":" + str(event.button_index)
        if event.pressed:
            _held[key] = 0.0
        else:
            _held.erase(key)

func request_exit() -> void:
    if not _exiting:
        _exiting = true
        _exit_initial_fade = fade
        _exit_elapsed = 0.0

func _on_music_finished() -> void:
    elapsed = 480.0
    fade = 1.0
    _push_visuals(0.0)
    _finish_exit()

func _process(delta: float) -> void:
    # Pose uploads run every render frame, including while the soundtrack pauses.
    session_menu.available = _started and fade < 0.9 and not _exiting
    _update_hands(delta)
    if not _started or music.stream_paused:
        return
    elapsed = clampf(music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency(), 0.0, 480.0)
    if _capture_time >= 0.0:
        elapsed = _capture_time
    if not _review_path.is_empty():
        _review_elapsed += delta
        elapsed = _review_start + _review_elapsed
        if _review_turn:
            camera.rotation.y = deg_to_rad(65.0) * ExperienceMath.smooth_unit((_review_elapsed - 5.0) / 2.0)
            camera.position.x = 0.25 * ExperienceMath.smooth_unit((_review_elapsed - 14.0) / 2.0)
    arc.seek(elapsed, true)
    if not _review_path.is_empty():
        clock.update_from_position(fmod(elapsed, clock.loop_seconds), elapsed)
    elif elapsed >= clock.settle_at():
        breath.stop()
        clock.update_from_position(clock.loop_seconds - 0.001, elapsed)
    else:
        clock.sample(breath, elapsed)
    if experience_layer != null:
        breath_particles_enabled = ExperienceMath.smooth_unit(elapsed / 3.0) * (1.0 - ExperienceMath.smooth_unit((elapsed - 476.0) / 4.0))
    _follow_orb(delta)
    breath_energy *= exp(-delta / 20.0)
    _sky_energy = move_toward(_sky_energy, breath_energy, delta * 0.18)
    _burst = 0.20 * pow(sin(PI * clock.inhale_t), 2.0) if clock.is_inhale else 0.0
    _morph += delta * fractal_morph_rate
    _advance_exit(delta)
    _push_visuals(delta)
    _record_performance(delta)
    if not _review_path.is_empty():
        if _review_elapsed >= _review_duration:
            _finish_exit()
        elif _review_elapsed >= _review_next_frame:
            _review_next_frame += 0.25
            _save_review_frame.call_deferred(int(round(_review_elapsed * 60.0)))
    if _capture_time >= 0.0:
        _capture_frames += 1
        if _capture_frames == 120:
            _save_capture.call_deferred()
    if elapsed >= 480.0:
        _finish_exit()

func _on_exhale() -> void:
    breath_energy += 1.0
    _ripple_origin = Vector2(camera.global_position.x, camera.global_position.z)

func _push_visuals(_delta: float) -> void:
    var release_wave: float = sin(clock.exhale_t * PI) if clock.is_exhale else 0.0
    for material: ShaderMaterial in _visual_materials:
        material.set_shader_parameter("time", elapsed)
        material.set_shader_parameter("aurora_intensity", aurora_intensity)
        material.set_shader_parameter("aurora_saturation", aurora_saturation)
        material.set_shader_parameter("fractal_mix", fractal_mix)
        material.set_shader_parameter("fractal_fold", fractal_fold)
        material.set_shader_parameter("fractal_params", Vector4(0.82 + sin(_morph * 0.018) * 0.05, 0.62 + cos(_morph * 0.014) * 0.05, 0, 0))
        material.set_shader_parameter("breath_energy", _sky_energy)
        material.set_shader_parameter("breath_fill", clock.breath_fill)
        material.set_shader_parameter("release_wave", release_wave)
    water_material.set_shader_parameter("ripple_amp", ripple_amp)
    water_material.set_shader_parameter("breath_phase", clock.phase)
    water_material.set_shader_parameter("breath_seconds", clock.seconds)
    water_material.set_shader_parameter("breath_center", _ripple_origin)
    water_material.set_shader_parameter("wave_cycle", float(clock.cycle_index))
    water_material.set_shader_parameter("orb_position", orb.global_position)
    inhale.amount_ratio = 1.0
    (inhale.process_material as ShaderMaterial).set_shader_parameter("mouth_target", mouth.global_position)
    (inhale.process_material as ShaderMaterial).set_shader_parameter("head_right", camera.global_basis.x.normalized())
    (inhale.process_material as ShaderMaterial).set_shader_parameter("head_up", camera.global_basis.y.normalized())
    var incoming_visibility: float = clock.incoming_visibility() * breath_particles_enabled
    if elapsed >= clock.settle_at() - 1.5:
        incoming_visibility = 0.0 # The final settle must not cue another breath.
    (inhale.process_material as ShaderMaterial).set_shader_parameter("inhale_active", incoming_visibility > 0.0)
    (inhale.process_material as ShaderMaterial).set_shader_parameter("inhale_visibility", incoming_visibility)
    (inhale.process_material as ShaderMaterial).set_shader_parameter("inhale_front", clock.incoming_front())
    (inhale.process_material as ShaderMaterial).set_shader_parameter("inhale_seconds", elapsed)
    (inhale.process_material as ShaderMaterial).set_shader_parameter("orb_position", orb.global_position)
    # Fade outgoing remnants completely before the next incoming breath starts.
    var exhale_visibility: float = 0.0 if not clock.is_exhale else ExperienceMath.smooth_unit((clock.outgoing_end() - clock.seconds - 0.65) / 1.35)
    exhale.amount_ratio = clock.outgoing_gate() * breath_particles_enabled * 0.32
    (exhale.process_material as ShaderMaterial).set_shader_parameter("exhale_active", clock.is_exhale)
    (exhale.process_material as ShaderMaterial).set_shader_parameter("exhale_visibility", exhale_visibility)
    (exhale.process_material as ShaderMaterial).set_shader_parameter("mouth_position", mouth.global_position)
    (exhale.process_material as ShaderMaterial).set_shader_parameter("mouth_basis", mouth.global_basis.orthonormalized())
    (exhale.process_material as ShaderMaterial).set_shader_parameter("exhale_reach", exhale_reach)
    (exhale.process_material as ShaderMaterial).set_shader_parameter("head_position", camera.global_position)
    var pulse: float = lerpf(1.0, 0.76, clock.breath_fill)
    core_material.set_shader_parameter("session_time", elapsed)
    core_material.set_shader_parameter("breath_scale", pulse)
    core_material.set_shader_parameter("breath_fill", clock.breath_fill)
    core_material.set_shader_parameter("intensity", lerpf(1.0, 0.86, clock.breath_fill))
    (halo.process_material as ShaderMaterial).set_shader_parameter("session_time", elapsed)
    (halo.process_material as ShaderMaterial).set_shader_parameter("burst", _burst)
    (halo.process_material as ShaderMaterial).set_shader_parameter("breath_fill", clock.breath_fill)
    field.amount_ratio = field_amount if _field_initialized else 1.0
    var field_material: ShaderMaterial = field.process_material
    field_material.set_shader_parameter("field_amount", field_amount)
    field_material.set_shader_parameter("field_radius", field_radius)
    field_material.set_shader_parameter("head_position", camera.global_position)
    var transforms: Array[Transform3D] = ExperienceMath.ifs_transforms(_morph, clampf((40.0 - field_radius) / 32.0, 0.0, 1.0))
    for index: int in range(4):
        field_material.set_shader_parameter("transform_" + str(index), Projection(transforms[index]))
    var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Breath"), 0)
    filter.cutoff_hz = breath_lowpass
    var motes: ShaderMaterial = ambient_motes.process_material
    var centers: PackedVector3Array = PackedVector3Array()
    var lives: PackedVector2Array = PackedVector2Array()
    var colors: PackedVector3Array = PackedVector3Array()
    for cluster: int in range(5):
        var state: Dictionary = ExperienceMath.mote_cluster(elapsed, cluster)
        centers.append(state["position"])
        lives.append(Vector2(state["age"], state["duration"]))
        var tint: Color = state["color"]
        colors.append(Vector3(tint.r, tint.g, tint.b))
        if experience_layer == null:
            _update_mote_audio(cluster, state)
    motes.set_shader_parameter("cluster_centers", centers)
    motes.set_shader_parameter("cluster_lives", lives)
    motes.set_shader_parameter("cluster_colors", colors)
    motes.set_shader_parameter("session_time", elapsed)
    motes.set_shader_parameter("head_position", camera.global_position)
    motes.set_shader_parameter("visibility", (1.0 - fade) * (1.0 - field_amount * 0.7))
    var audio_fade: float = linear_to_db(maxf(0.0001, 1.0 - fade))
    for player: AudioStreamPlayer3D in _spatial_audio:
        if player not in _mote_audio:
            var index: int = int(String(player.name).trim_prefix("Water"))
            var angle: float = float(index) * TAU / 3.0 + 0.14 * sin(elapsed * 0.053 + float(index) * 1.8)
            var radius: float = 4.6 + 0.5 * sin(elapsed * 0.071 + float(index) * 2.1)
            player.global_position = Vector3(cos(angle) * radius, 0.15, sin(angle) * radius)
            player.volume_db = (-14.0 + release_wave * 2.0 + 1.5 * sin(elapsed * 0.11 + float(index) * 2.2)) + audio_fade
    if experience_layer != null and experience_layer.is_inside_tree():
        experience_layer.update_experience({"elapsed": elapsed, "intensity": 1.0 - fade, "breath_fill": clock.breath_fill, "inhale_t": clock.inhale_t, "exhale_t": clock.exhale_t, "is_inhale": clock.is_inhale, "is_exhale": clock.is_exhale, "is_pause": clock.is_pause, "head_position": camera.global_position, "mouth_position": mouth.global_position, "orb_position": orb.global_position, "head_basis": camera.global_basis})
    (fade_mesh.material_override as ShaderMaterial).set_shader_parameter("fade", fade)

func _update_mote_audio(cluster: int, state: Dictionary) -> void:
    var player: AudioStreamPlayer3D = _mote_audio[cluster]
    player.global_position = state["position"]
    player.volume_db = -18.0 + linear_to_db(maxf(0.0001, (1.0 - fade) * (1.0 - field_amount * 0.6)))
    var cue: int = state["cue_id"]
    var age: float = state["cue_age"]
    if _started and not _test_mode and age >= 0.0 and cue != _mote_cues[cluster]:
        _mote_cues[cluster] = cue
        # Starting partway through a session must not replay old appearance cues.
        if age < player.stream.get_length() and fade < 0.95:
            player.play(age)

func _save_capture() -> void:
    await RenderingServer.frame_post_draw
    var path: String = _capture_path if not _capture_path.is_empty() else "res://verification/frame_" + str(int(_capture_time)) + ".png"
    get_viewport().get_texture().get_image().save_png(path)
    print("Captured ", path)
    _finish_exit()

func _initialize_field() -> void:
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    _field_initialized = true

func _parent_fade() -> void:
    fade_mesh.reparent(camera, false)
    fade_mesh.position = Vector3(0, 0, -0.1)

func _finish_exit() -> void:
    if _quitting:
        return
    _quitting = true
    set_process(false)
    music.stop()
    breath.stop()
    music.stream = null
    breath.stream = null
    for player: AudioStreamPlayer3D in _spatial_audio:
        player.stop()
        player.stream = null
    # Allow the mixer to release its playback references before tree teardown.
    await get_tree().create_timer(0.25).timeout
    if _return_to_menu and _review_path.is_empty() and _capture_time < 0.0:
        get_tree().change_scene_to_file("res://scenes/startup.tscn")
    else:
        get_tree().quit()

func _on_tracker_removed(tracker_name: StringName, _type: int) -> void:
    for key: String in _held.keys():
        if key.begins_with(String(tracker_name) + ":"):
            _held.erase(key)

func _update_hands(delta: float) -> void:
    var tracking_to_world: Transform3D = (camera.get_parent() as XROrigin3D).global_transform * XRServer.get_reference_frame()
    for index: int in range(2):
        var path: StringName = &"/user/hand_tracker/left" if index == 0 else &"/user/hand_tracker/right"
        var tracker: XRHandTracker = XRServer.get_tracker(path) as XRHandTracker
        _upload_hand(index, tracker, tracking_to_world, delta)

func _upload_hand(index: int, tracker: XRHandTracker, tracking_to_world: Transform3D, delta: float) -> void:
    var available: bool = tracker != null and tracker.has_tracking_data and tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED
    if available:
        available = (tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0
    if available != _hand_tracked[index]:
        _hand_tracked[index] = available
        print("VRMED HAND ", "left" if index == 0 else "right", " tracked=", available)
    var points: PackedVector4Array = _hand_joints[index]
    var confidence: PackedFloat32Array = _hand_confidence[index]
    for joint: int in range(XRHandTracker.HAND_JOINT_MAX):
        var valid: bool = available and (tracker.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0
        if valid:
            # Joint transforms are absolute tracking-space poses, not palm-relative.
            # Match XRPose: scale translations, apply recenter, then the XR origin.
            var point: Vector3 = tracking_to_world * (tracker.get_hand_joint_transform(joint).origin * XRServer.world_scale)
            valid = point.is_finite() and point.distance_to(camera.global_position) < 3.0
            if valid:
                var radius: float = clampf(tracker.get_hand_joint_radius(joint), 0.004, 0.025) * XRServer.world_scale
                points[joint] = Vector4(point.x, point.y, point.z, radius)
        # Briefly retain the last valid pose while dissolving; never jump to zero.
        confidence[joint] = move_toward(confidence[joint], 1.0 if valid else 0.0, delta / (0.3 if valid else 0.16))
    _hand_joints[index] = points
    _hand_confidence[index] = confidence
    var material: ShaderMaterial = _hand_materials[index]
    material.set_shader_parameter("joints", points)
    material.set_shader_parameter("confidence", confidence)
    material.set_shader_parameter("session_time", elapsed)
    material.set_shader_parameter("head_position", camera.global_position)
    material.set_shader_parameter("visibility", (1.0 - fade) if not music.stream_paused else 0.0)

func _advance_exit(delta: float) -> void:
    var was_exiting: bool = _exiting
    for button: String in _held:
        _held[button] = float(_held[button]) + delta
        if float(_held[button]) >= 1.5:
            request_exit()
    if _exiting:
        if was_exiting:
            _exit_elapsed += delta
        fade = lerpf(_exit_initial_fade, 1.0, ExperienceMath.smooth_unit(_exit_elapsed / 2.0))
        music.volume_db = linear_to_db(maxf(0.0001, 1.0 - fade))
        breath.volume_db = -18.0 + music.volume_db
        if _exit_elapsed >= 2.0:
            _finish_exit()

func _follow_orb(delta: float) -> void:
    # Two gentle response stages let the viewer see the orb travel after a turn.
    var forward: Vector3 = -camera.global_basis.z.normalized()
    if _gaze_direction.angle_to(forward) > deg_to_rad(3.0):
        _gaze_direction = _gaze_direction.slerp(forward, 1.0 - exp(-delta / 0.75)).normalized()
    var target: Vector3 = camera.global_position + _gaze_direction * ExperienceMath.ORB_DISTANCE
    target += ExperienceMath.orb_drift(elapsed)
    target.y = maxf(0.45, target.y)
    orb.quaternion = orb.quaternion.slerp(camera.global_basis.get_rotation_quaternion(), 1.0 - exp(-delta / 0.85))
    var previous: Vector3 = orb.global_position
    orb.global_position = orb.global_position.lerp(target, 1.0 - exp(-delta / 0.85))
    var velocity: Vector3 = (orb.global_position - previous) / maxf(delta, 0.00001)
    movement_trail.amount_ratio = smoothstep(0.035, 0.65, velocity.length())
    (movement_trail.process_material as ShaderMaterial).set_shader_parameter("orb_velocity", velocity)

func _save_review_frame(frame: int) -> void:
    # Explicit redraw prevents queued screenshots from all capturing a later frame
    # when macOS throttles an obscured review window.
    RenderingServer.force_draw(false, 0.0)
    get_viewport().get_texture().get_image().save_png(_review_path.path_join("frame_%05d.png" % frame))
    var snapshot: Dictionary = {
        "seconds": elapsed, "inhale": clock.is_inhale, "pause": clock.is_pause, "exhale": clock.is_exhale, "breath_fill": clock.breath_fill,
        "head": str(camera.global_transform), "mouth": str(mouth.global_position),
        "orb": str(orb.global_position), "trail": movement_trail.amount_ratio,
        "orb_scale": core_material.get_shader_parameter("breath_scale"),
        "mote_cues": _mote_cues,
        "inhale_bounds": str(inhale.capture_aabb()), "exhale_bounds": str(exhale.capture_aabb()),
        "exhale_visibility": (exhale.process_material as ShaderMaterial).get_shader_parameter("exhale_visibility"),
        "inhale_visibility": (inhale.process_material as ShaderMaterial).get_shader_parameter("inhale_visibility"),
        "mote_cluster_0": ExperienceMath.mote_cluster(elapsed, 0),
        "mote_bounds": str(ambient_motes.capture_aabb())
    }
    var output: FileAccess = FileAccess.open(_review_path.path_join("frame_%05d.json" % frame), FileAccess.WRITE)
    output.store_string(JSON.stringify(snapshot))

func _record_performance(delta: float) -> void:
    _perf_elapsed += delta
    _perf_frames += 1
    _perf_worst = maxf(_perf_worst, delta)
    if _perf_elapsed >= 10.0:
        print("VRMED FRAME SAMPLE fps=", snappedf(float(_perf_frames) / _perf_elapsed, 0.1), " worst_ms=", snappedf(_perf_worst * 1000.0, 0.1), " head=", camera.global_position, " mouth_distance=", snappedf(camera.global_position.distance_to(mouth.global_position), 0.001))
        _perf_elapsed = 0.0
        _perf_frames = 0
        _perf_worst = 0.0

func _configure_experience() -> void:
    experience = ExperienceCatalog.find(experience_id)
    experience_id = experience["id"]
    if experience_id == "aurora_lake":
        return
    clock.custom_pattern = true
    clock.pattern = experience["rhythm"]
    clock.custom_stream = load("res://assets/audio/breath_" + experience_id + ".wav") as AudioStreamWAV
    clock.custom_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    clock.custom_stream.loop_begin = 0
    clock.custom_stream.loop_end = int(clock.custom_stream.get_length() * clock.custom_stream.mix_rate)
    music.stream = load("res://" + str(experience["music"])) as AudioStream
    for path: String in ["Water", "NearAuroras", "FractalField", "AmbientMotes"]:
        var visual: Node3D = get_node("../" + path)
        visual.hide()
        if visual is GPUParticles3D:
            visual.emitting = false
            visual.amount = 1
    var environment: Environment = (get_node("../WorldEnvironment") as WorldEnvironment).environment
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = ExperienceCatalog.background(experience_id)
    environment.fog_enabled = false
    experience_layer = load("res://experiences/" + experience_id + "/layer.gd").new()
    get_parent().add_child.call_deferred(experience_layer)
    print("VRMED EXPERIENCE ", experience_id, " rhythm=", clock.pattern)

func _return_from_session_menu() -> void:
    _return_to_menu = true
    _on_focus()
    request_exit()
