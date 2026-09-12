extends Node3D
## A native spatial selector with gaze dwell, pointer selection, and keyboard access.

var entries: Array = ExperienceCatalog.all()
var camera: XRCamera3D
var panel: Node3D
var cards: Array[MeshInstance3D] = []
var status: Label3D
var transition: ShaderMaterial
var cursor: Label3D
var selected: int = -1
var dwell: float = 0.0
var age: float = 0.0
var anchored: bool = false
var leaving: bool = false
var xr: OpenXRInterface
var off_axis: float = 0.0
var desktop_pointer: Vector2 = Vector2(-1, -1)

func _ready() -> void:
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--experience=") or arg.begins_with("--review-") or arg.begins_with("--capture="):
            get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
            return
    var world: WorldEnvironment = WorldEnvironment.new()
    world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR
    world.environment.background_color = Color(0.007, 0.012, 0.024)
    add_child(world)
    var origin: XROrigin3D = XROrigin3D.new()
    add_child(origin)
    camera = XRCamera3D.new()
    camera.current = true
    camera.near = 0.05
    origin.add_child(camera)
    xr = XRServer.find_interface("OpenXR") as OpenXRInterface
    if xr != null and xr.is_initialized():
        get_viewport().use_xr = true
        xr.pose_recentered.connect(_anchor)
        xr.session_focussed.connect(func() -> void: dwell = 0.0)
        xr.session_visible.connect(func() -> void: dwell = 0.0)
    else:
        origin.position.y = 1.4
    var curtain: MeshInstance3D = MeshInstance3D.new()
    curtain.mesh = QuadMesh.new()
    curtain.position.z = -0.1
    curtain.extra_cull_margin = 100.0
    transition = ShaderMaterial.new()
    transition.shader = load("res://shaders/fade.gdshader")
    transition.render_priority = 127
    curtain.material_override = transition
    camera.add_child(curtain)
    panel = Node3D.new()
    panel.visible = false
    add_child(panel)
    _label("B R E A T H W O R K", Vector3(0, 1.05, 0), 56, Color(0.91, 0.88, 0.77))
    _label("Eight worlds. Eight minutes. Your own pace.", Vector3(0, 0.93, 0), 25, Color(0.60, 0.69, 0.74))
    for index: int in range(entries.size()):
        var entry: Dictionary = entries[index]
        var center: Vector3 = Vector3(-0.57 if index % 2 == 0 else 0.57, 0.63 - float(index / 2) * 0.39, 0)
        var card: MeshInstance3D = MeshInstance3D.new()
        var mesh: QuadMesh = QuadMesh.new()
        mesh.size = Vector2(1.08, 0.34)
        card.mesh = mesh
        var material: StandardMaterial3D = StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color(0.045, 0.065, 0.085)
        card.material_override = material
        card.position = center
        panel.add_child(card)
        cards.append(card)
        var tint: Color = Color.from_string(entry["color"], Color.WHITE)
        _label(str(index + 1) + "  " + str(entry["title"]), center + Vector3(0, 0.077, 0.006), 34, tint)
        _label(str(entry["rhythm_label"]) + "   ·   8 min", center + Vector3(0, 0.007, 0.006), 22, Color(0.73, 0.78, 0.80))
        _label(ExperienceCatalog.rhythm_text(entry), center + Vector3(0, -0.062, 0.006), 20, Color(0.53, 0.61, 0.66))
    status = _label("Look at a world for 2.5 seconds to begin", Vector3(0, -0.81, 0), 26, Color(0.75, 0.80, 0.84))
    _label("Breathe comfortably; let any hold become a gentle pause.", Vector3(0, -0.91, 0), 21, Color(0.48, 0.57, 0.63))
    _label("Pause/end: wave a hand sideways, palm facing you. Desktop: M.", Vector3(0, -1.00, 0), 19, Color(0.48, 0.57, 0.63))
    cursor = Label3D.new()
    cursor.text = "·"
    cursor.font_size = 44
    cursor.pixel_size = 0.00035
    cursor.position.z = -0.8
    cursor.no_depth_test = true
    camera.add_child(cursor)
    _anchor()

func _label(text: String, point: Vector3, size: int, color: Color) -> Label3D:
    var label: Label3D = Label3D.new()
    label.text = text
    label.position = point
    label.font_size = size
    label.pixel_size = 0.0025
    label.modulate = color
    label.outline_size = 0
    panel.add_child(label)
    return label

func _anchor() -> void:
    if panel == null or camera == null:
        return
    panel.global_transform = camera.global_transform
    panel.global_position -= camera.global_basis.z * 2.5
    dwell = 0.0
    off_axis = 0.0

func _process(delta: float) -> void:
    if leaving or camera == null:
        return
    if get_viewport().use_xr and not ExperienceMath.xr_session_focused(xr):
        dwell = 0.0
        return
    age += delta
    if age > 0.8 and not anchored:
        _anchor()
        anchored = true
        panel.visible = true
        create_tween().tween_method(func(value: float) -> void: transition.set_shader_parameter("fade", value), 1.0, 0.0, 0.7)
    if not anchored:
        return
    var forward: Vector3 = -camera.global_basis.z
    var to_panel: Vector3 = (panel.global_position - camera.global_position).normalized()
    off_axis = off_axis + delta if forward.dot(to_panel) < 0.45 else 0.0
    if off_axis > 2.5:
        _anchor()
    var origin: Vector3 = camera.global_position
    if not get_viewport().use_xr and desktop_pointer.x >= 0:
        origin = camera.project_ray_origin(desktop_pointer)
        forward = camera.project_ray_normal(desktop_pointer)
    var local_origin: Vector3 = panel.to_local(origin)
    var local_direction: Vector3 = panel.global_basis.inverse() * forward
    var hovered: int = -1
    if absf(local_direction.z) > 0.001:
        var distance: float = -local_origin.z / local_direction.z
        var point: Vector3 = local_origin + local_direction * distance
        if distance > 0:
            for index: int in range(cards.size()):
                var offset: Vector3 = point - cards[index].position
                if absf(offset.x) < 0.54 and absf(offset.y) < 0.17:
                    hovered = index
    if hovered != selected:
        selected = hovered
        dwell = 0.0
    if selected >= 0:
        dwell += delta if get_viewport().use_xr and ExperienceMath.xr_session_focused(xr) else 0.0
        status.text = "%s  ·  %d%%" % [entries[selected]["title"], int(clampf(dwell / 2.5, 0, 1) * 100)] if get_viewport().use_xr else "Click to enter " + str(entries[selected]["title"])
        if dwell >= 2.5:
            _choose(selected)
    else:
        dwell = 0.0
        status.text = "Look at a world for 2.5 seconds to begin" if get_viewport().use_xr else "Click a world or press 1–8 to begin"
    for index: int in range(cards.size()):
        var tint: Color = Color.from_string(entries[index]["color"], Color.WHITE)
        (cards[index].material_override as StandardMaterial3D).albedo_color = Color(0.045, 0.065, 0.085).lerp(tint * 0.28, (0.6 + 0.4 * dwell / 2.5) if index == selected else 0.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        desktop_pointer = event.position
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and selected >= 0:
        _choose(selected)
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
            _choose(event.physical_keycode - KEY_1)
        elif event.physical_keycode == KEY_R:
            _anchor()

func _choose(index: int) -> void:
    if leaving:
        return
    leaving = true
    get_tree().root.set_meta("experience_id", entries[index]["id"])
    get_tree().root.set_meta("from_menu", true)
    var tween: Tween = create_tween()
    tween.tween_method(func(value: float) -> void: transition.set_shader_parameter("fade", value), 0.0, 1.0, 0.65)
    await tween.finished
    get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
