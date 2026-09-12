extends SceneTree
## Capture the sixteen real mesh silhouettes together for visual inspection.
func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var scene: Node3D = Node3D.new()
    root.add_child(scene)
    var camera: Camera3D = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.0
    camera.position.z = 12
    scene.add_child(camera)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    for kind: int in range(16):
        var mesh: MeshInstance3D = MeshInstance3D.new()
        mesh.mesh = PrismaticShapes.build(kind)
        mesh.material_override = material
        mesh.position = Vector3((kind%4-1.5)*3.3,(1.5-kind/4)*2.35,0)
        mesh.rotation = Vector3(.28,.4,.1)
        scene.add_child(mesh)
        var label: Label3D = Label3D.new()
        label.text = "%02d  %s" % [kind+1,PrismaticShapes.NAMES[kind]]
        label.font_size = 22
        label.pixel_size = .006
        label.position = mesh.position+Vector3(0,-1.12,.1)
        scene.add_child(label)
    await create_timer(.3).timeout
    RenderingServer.force_draw(false,0)
    root.get_texture().get_image().save_png("res://verification/prismatic_shapes.png")
    quit()
