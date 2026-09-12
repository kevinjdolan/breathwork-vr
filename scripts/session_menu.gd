class_name SessionMenu
extends Node3D
## A stable gaze target opens a deliberate, reclining-aware return confirmation.

signal opened
signal continued
signal return_requested

const OPEN_DWELL: float = 1.2
const CONFIRM_DWELL: float = 1.8
var camera: XRCamera3D
var available: bool = false
var is_open: bool = false
var anchor_ready: bool = false
var pill: Node3D
var dialog: Node3D
var buttons: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
var pill_text: Label3D
var dwell: float = 0.0
var hovered: int = -1
var off_axis: float = 0.0
var pointer: Vector2 = Vector2(-1, -1)
var xr: OpenXRInterface

func _ready() -> void:
    xr = XRServer.find_interface("OpenXR") as OpenXRInterface
    pill = Node3D.new()
    add_child(pill)
    _surface(pill, Vector2(0.32, 0.13), Vector3.ZERO)
    pill_text = _label(pill, "Menu", Vector3(0, 0, 0.006), 24)
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
        return
    if get_viewport().use_xr and not ExperienceMath.xr_session_focused(xr):
        dwell = 0.0
        return
    if not anchor_ready:
        _anchor(pill, Vector3(0.62, -0.44, -2.0))
        anchor_ready = true
    pill.visible = not is_open
    dialog.visible = is_open
    var target: Node3D = dialog if is_open else pill
    var direction: Vector3 = (target.global_position - camera.global_position).normalized()
    off_axis = off_axis + delta if (-camera.global_basis.z).dot(direction) < 0.57 else 0.0
    if off_axis > 1.2:
        _anchor(target, Vector3(0, 0, -2.0) if is_open else Vector3(0.62, -0.44, -2.0))
    var next: int = _target_at_ray()
    if hovered != next:
        hovered = next
        dwell = 0.0
    if hovered >= 0:
        dwell += delta
    else:
        dwell = 0.0
    pill_text.text = "Menu" if hovered < 0 or is_open else "Menu %d%%" % int(dwell / OPEN_DWELL * 100.0)
    for index: int in range(2):
        var selected: bool = is_open and hovered == index
        var caption: String = "Continue" if index == 0 else "End session"
        labels[index].text = caption + (" %d%%" % int(dwell / CONFIRM_DWELL * 100.0) if selected else "")
        (buttons[index].material_override as ShaderMaterial).set_shader_parameter("tint", Vector3(0.055, 0.15, 0.16) if selected else Vector3(0.035, 0.065, 0.080))
    if hovered >= 0 and dwell >= (CONFIRM_DWELL if is_open else OPEN_DWELL):
        _activate(hovered)

func _target_at_ray() -> int:
    var origin: Vector3 = camera.global_position
    var direction: Vector3 = -camera.global_basis.z
    if not get_viewport().use_xr and pointer.x >= 0:
        origin = camera.project_ray_origin(pointer)
        direction = camera.project_ray_normal(pointer)
    var target: Node3D = dialog if is_open else pill
    var local_origin: Vector3 = target.to_local(origin)
    var local_direction: Vector3 = target.global_basis.inverse() * direction
    if absf(local_direction.z) < 0.001:
        return -1
    var distance: float = -local_origin.z / local_direction.z
    if distance <= 0:
        return -1
    var point: Vector3 = local_origin + local_direction * distance
    if not is_open:
        return 0 if absf(point.x) < 0.16 and absf(point.y) < 0.065 else -1
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
    pill.hide()
    dialog.show()
    print("VRMED SESSION MENU opened")
    opened.emit()

func _activate(index: int) -> void:
    if not is_open:
        open_menu()
        return
    is_open = false
    dwell = 0.0
    hovered = -1
    _anchor(pill, Vector3(0.62, -0.44, -2.0))
    dialog.hide()
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
