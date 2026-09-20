class_name SessionMenu
extends Node3D
## A palm-facing wave opens a reclining-aware confirmation with a gaze cursor.

signal opened
signal continued
signal return_requested

const CONFIRM_DWELL: float = 1.8
var camera: XRCamera3D
var available: bool = false
var is_open: bool = false
var dialog: Node3D
var buttons: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
var dwell: float = 0.0
var hovered: int = -1
var off_axis: float = 0.0
var pointer: Vector2 = Vector2(-1, -1)
var cursor: MeshInstance3D
var waves: Array[PalmWave] = [PalmWave.new(), PalmWave.new()]
var gesture_heads: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var last_head: Transform3D
var head_ready: bool = false
var xr: OpenXRInterface

func _ready() -> void:
    xr = XRServer.find_interface("OpenXR") as OpenXRInterface
    dialog = Node3D.new()
    add_child(dialog)
    _surface(dialog, Vector2(1.60, 0.70), Vector3(0, 0.06, -0.012))
    _label(dialog, "Return to menu?", Vector3(0, 0.27, 0.006), 42)
    _label(dialog, "Your session is paused", Vector3(0, 0.16, 0.006), 24)
    for index: int in range(2):
        var point: Vector3 = Vector3(-0.38 if index == 0 else 0.38, -0.01, 0)
        buttons.append(_surface(dialog, Vector2(0.67, 0.20), point))
        labels.append(_label(dialog, "Continue" if index == 0 else "End session", point + Vector3(0, 0, 0.006), 30))
    _label(dialog, "Look at your choice and hold your gaze", Vector3(0, -0.19, 0.006), 22)
    cursor = _surface(self, Vector2(0.024, 0.024), Vector3.ZERO)
    var cursor_shader: Shader = Shader.new()
    cursor_shader.code = "shader_type spatial; render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled; uniform float progress = 0.0; void fragment() { vec2 p = UV - 0.5; float r = length(p); float ring = smoothstep(0.46,0.42,r) * smoothstep(0.30,0.34,r); float dot = 1.0-smoothstep(0.065,0.10,r); float angle = mod(atan(p.x,-p.y)+6.283185,6.283185)/6.283185; vec3 col = mix(vec3(0.85,0.93,0.93),vec3(0.26,1.0,0.81),step(angle,progress)); ALBEDO = col; ALPHA = max(dot,ring*0.85); }"
    (cursor.material_override as ShaderMaterial).shader = cursor_shader
    (cursor.material_override as ShaderMaterial).render_priority = 120
    dialog.hide()
    cursor.hide()
    hide()

func _surface(parent: Node3D, size: Vector2, point: Vector3) -> MeshInstance3D:
    var surface: MeshInstance3D = MeshInstance3D.new()
    var quad: QuadMesh = QuadMesh.new()
    quad.size = size
    surface.mesh = quad
    var material: ShaderMaterial = ShaderMaterial.new()
    var shader: Shader = Shader.new()
    shader.code = "shader_type spatial; render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled; uniform vec3 tint = vec3(0.026,0.043,0.060); void fragment() { ALBEDO = tint; ALPHA = 0.98; }"
    material.shader = shader
    material.render_priority = 100
    surface.material_override = material
    surface.position = point
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(surface)
    return surface

func _label(parent: Node3D, text: String, point: Vector3, size: int) -> Label3D:
    var label: Label3D = Label3D.new()
    label.text = text
    label.font_size = size
    label.pixel_size = 0.0025
    label.outline_size = 0
    label.no_depth_test = true
    label.render_priority = 101
    label.modulate = Color(0.70, 0.80, 0.79)
    label.position = point
    parent.add_child(label)
    return label

func _anchor(target: Node3D, offset: Vector3) -> void:
    target.global_transform = camera.global_transform
    target.global_position = camera.global_transform * offset
    dwell = 0.0
    hovered = -1
    off_axis = 0.0

func _process(delta: float) -> void:
    visible = available
    if not available or camera == null:
        dwell = 0.0
        head_ready = false
        for wave: PalmWave in waves:
            wave.reset()
        return
    if get_viewport().use_xr and not ExperienceMath.xr_session_focused(xr):
        dwell = 0.0
        for wave: PalmWave in waves:
            wave.reset()
        return
    _sample_hands(delta)
    dialog.visible = is_open
    cursor.visible = is_open
    if not is_open:
        return
    var direction: Vector3 = (dialog.global_position - camera.global_position).normalized()
    off_axis = off_axis + delta if (-camera.global_basis.z).dot(direction) < 0.57 else 0.0
    if off_axis > 1.2:
        _anchor(dialog, Vector3(0, 0, -2.0))
    cursor.global_transform = camera.global_transform
    cursor.global_position = camera.global_transform * Vector3(0, 0, -0.8)
    if not get_viewport().use_xr and pointer.x >= 0:
        cursor.global_position = camera.project_position(pointer, 0.8)
    var next: int = _target_at_ray()
    if hovered != next:
        hovered = next
        dwell = 0.0
    if hovered >= 0:
        dwell += delta
    else:
        dwell = 0.0
    (cursor.material_override as ShaderMaterial).set_shader_parameter("progress", clampf(dwell / CONFIRM_DWELL, 0.0, 1.0))
    for index: int in range(2):
        var selected: bool = is_open and hovered == index
        var caption: String = "Continue" if index == 0 else "End session"
        labels[index].text = caption + (" %d%%" % int(dwell / CONFIRM_DWELL * 100.0) if selected else "")
        (buttons[index].material_override as ShaderMaterial).set_shader_parameter("tint", Vector3(0.055, 0.15, 0.16) if selected else Vector3(0.035, 0.065, 0.080))
    if hovered >= 0 and dwell >= CONFIRM_DWELL:
        _activate(hovered)

func _sample_hands(delta: float) -> void:
    var head: Transform3D = camera.global_transform
    var head_moved: bool = head_ready and (head.origin.distance_to(last_head.origin) > 0.05 or head.basis.get_rotation_quaternion().angle_to(last_head.basis.get_rotation_quaternion()) > 0.12)
    last_head = head
    head_ready = true
    var origin: XROrigin3D = camera.get_parent() as XROrigin3D
    if origin == null:
        return
    var tracking_to_world: Transform3D = origin.global_transform * XRServer.get_reference_frame()
    for index: int in range(2):
        if waves[index].samples == 0:
            gesture_heads[index] = head
        var anchor: Transform3D = gesture_heads[index]
        var stable_head: bool = anchor.origin.distance_to(head.origin) < 0.18 and anchor.basis.get_rotation_quaternion().angle_to(head.basis.get_rotation_quaternion()) < 0.45
        if head_moved or not stable_head:
            waves[index].reset()
        var tracker: XRHandTracker = XRServer.get_tracker("/user/hand_tracker/left" if index == 0 else "/user/hand_tracker/right") as XRHandTracker
        var valid: bool = tracker != null and not is_open and not head_moved and stable_head
        if valid:
            valid = tracker.has_tracking_data and tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED and tracker.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
        var point: Vector3 = Vector3.ZERO
        var facing: float = 0.0
        if valid:
            var flags: int = tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM)
            valid = (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0 and (flags & XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID) != 0
        if valid:
            var palm: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
            var world: Vector3 = tracking_to_world * (palm.origin * XRServer.world_scale)
            # Measure motion in the pose at sweep start so head motion cannot fake a wave.
            point = anchor.affine_inverse() * world
            # XRHandTracker uses Godot's humanoid axes: +Z is out of the palm.
            # The OpenXR extension converts raw joint bases before exposing them.
            var normal: Vector3 = (tracking_to_world.basis * palm.basis.z).normalized()
            facing = normal.dot((head.origin - world).normalized())
        if waves[index].sample(point, facing, valid, delta):
            print("VRMED PALM WAVE hand=", "left" if index == 0 else "right")
            open_menu()

func _target_at_ray() -> int:
    var origin: Vector3 = camera.global_position
    var direction: Vector3 = -camera.global_basis.z
    if not get_viewport().use_xr and pointer.x >= 0:
        origin = camera.project_ray_origin(pointer)
        direction = camera.project_ray_normal(pointer)
    if not is_open:
        return -1
    var target: Node3D = dialog
    var local_origin: Vector3 = target.to_local(origin)
    var local_direction: Vector3 = target.global_basis.inverse() * direction
    if absf(local_direction.z) < 0.001:
        return -1
    var distance: float = -local_origin.z / local_direction.z
    if distance <= 0:
        return -1
    var point: Vector3 = local_origin + local_direction * distance
    for index: int in range(2):
        var offset: Vector3 = point - buttons[index].position
        if absf(offset.x) < 0.335 and absf(offset.y) < 0.10:
            return index
    return -1

func open_menu() -> void:
    if is_open or not available:
        return
    is_open = true
    _anchor(dialog, Vector3(0, 0, -2.0))
    for wave: PalmWave in waves:
        wave.disarm()
    dialog.show()
    cursor.show()
    print("VRMED SESSION MENU opened")
    opened.emit()

func _activate(index: int) -> void:
    if not is_open:
        return
    is_open = false
    dwell = 0.0
    hovered = -1
    for wave: PalmWave in waves:
        wave.disarm()
    dialog.hide()
    cursor.hide()
    if index == 0:
        print("VRMED SESSION MENU continued")
        continued.emit()
    else:
        available = false
        hide()
        print("VRMED SESSION MENU return requested")
        return_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
    if not available:
        return
    if event is InputEventMouseMotion:
        pointer = event.position
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var target: int = _target_at_ray()
        if target >= 0:
            _activate(target)
            get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_M or event.physical_keycode == KEY_M):
        if is_open:
            _activate(0)
        else:
            open_menu()
        get_viewport().set_input_as_handled()
