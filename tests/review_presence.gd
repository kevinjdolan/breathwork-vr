extends SceneTree
## Renders the breath paths from the side without changing the tracked head pose.

var elapsed: float = 0.0
var frame: int = 0
var scene: Node
var director: MeditationDirector

func _initialize() -> void:
    call_deferred("setup")

func setup() -> void:
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    director = scene.get_node("Director")
    director.set_process(false)
    var spectator: Camera3D = Camera3D.new()
    scene.add_child(spectator)
    spectator.position = Vector3(3.5, 2.4, 1.0)
    spectator.look_at(Vector3(0, 1.3, -1.7))
    spectator.current = true
    director.fade_mesh.visible = false
    director.breath_particles_enabled = 1.0
    director.fade = 0.0
    var marker: MeshInstance3D = MeshInstance3D.new()
    marker.mesh = SphereMesh.new()
    (marker.mesh as SphereMesh).radius = 0.04
    (marker.mesh as SphereMesh).height = 0.08
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color.RED
    marker.material_override = material
    scene.add_child(marker)
    marker.global_position = director.breath_center.global_position

func _process(delta: float) -> bool:
    if director == null:
        return false
    elapsed += delta
    frame += 1
    director.elapsed = 28.0 + elapsed
    director.clock.update_from_position(fmod(elapsed, 14.0), director.elapsed)
    director._push_visuals(delta)
    if frame == 150 or frame == 510:
        capture.call_deferred(frame)
    if frame == 520:
        scene.free()
        quit()
    return false

func capture(index: int) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://verification/side_%d.png" % index)
