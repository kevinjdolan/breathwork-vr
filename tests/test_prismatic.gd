extends SceneTree
## Verify geometric diversity, smooth travel, and a distant reclining-aware focal star.
const Layer = preload("res://experiences/prismatic_sanctuary/layer.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var fingerprints: Dictionary = {}
    var triangles: int = 0
    for kind: int in range(16):
        var mesh: ArrayMesh = PrismaticShapes.build(kind)
        var vertices: PackedVector3Array = mesh.get_faces()
        check(vertices.size() > 50, "Every family has real geometric depth")
        fingerprints[hash(vertices)] = true
        triangles += vertices.size()/3
        for vertex: Vector3 in vertices:
            check(vertex.is_finite() and vertex.length() < 1.17, "All shapes stay inside the near-pass size budget")
    check(fingerprints.size() == 16, "Sixteen distinct mesh families")
    check(triangles*8 < 80000, "Mobile object triangle budget")
    check(is_zero_approx(Layer.travel_distance(0)), "Travel starts at rest")
    check(Layer.travel_distance(.1) < .001, "No sudden motion onset")
    check(absf(Layer.travel_distance(121)-Layer.travel_distance(120)-.55) < .0001, "Constant slow cruise speed")
    check(is_equal_approx(Layer.star_radius(4.0),1.0) and is_equal_approx(Layer.star_radius(4.5),1.9), "White halo grows during first 500ms of full hold")
    check(is_equal_approx(Layer.star_radius(8.0),1.9) and is_zero_approx(Layer.star_radius(8.5)), "White halo shrinks to zero over first 500ms of outbreath")
    check(is_zero_approx(Layer.star_radius(15.99)) and is_zero_approx(Layer.star_radius(0)), "Halo remains absent through empty pause and wraps continuously")
    var layer: Node3D = Layer.new()
    root.add_child(layer)
    check(layer.get_node("RainbowOutflow").multimesh.instance_count == 32, "Sixteen distinct outflow beams each have a halo")
    check(layer.find_children("*", "Label3D").is_empty(), "No instructional text in the tunnel")
    var cloud: MultiMeshInstance3D = layer.get_node("ParticleVault")
    check(cloud.multimesh.instance_count == 98304, "Three dense cloud strata within the bounded particle budget")
    check(layer.get_node("VaultFilaments").multimesh.instance_count == 32768, "Fine detached filaments provide a separate depth scale")
    # The headless dummy backend does not retain MultiMesh instance buffers.
    if RenderingServer.get_rendering_device() != null:
        check(cloud.multimesh.get_instance_custom_data(32768).r == 32768.0 and cloud.multimesh.get_instance_custom_data(65536).r == 65536.0, "Particle addresses retain all three depth strata")
    var basis: Basis = Basis(Vector3.RIGHT,deg_to_rad(80))
    var head: Vector3 = Vector3(0,1.4,0)
    layer.update_experience({"head_position":head,"head_basis":basis,"elapsed":30})
    check(layer.focal_position().distance_to(head-basis.z*60) < .001, "Reclining start aligns the tunnel and star")
    head += Vector3(.25,.1,.3)
    for frame: int in range(960):
        layer.update_experience({"head_position":head,"head_basis":Basis.IDENTITY,"elapsed":30.0+float(frame+1)/60.0})
        if frame==60:
            check(layer._journey.basis.z.angle_to(basis.z)<.15, "Large head turns have a slow onset")
    check(absf(layer.focal_position().distance_to(head)-60) < .001, "Forward travel never approaches the star")
    check(layer._journey.basis.z.angle_to(Vector3.BACK)<.07, "Tunnel aligns to new gaze after sixteen seconds")
    var missing: int = 0
    for second: int in range(0,480,4):
        layer._journey = Transform3D(Basis.IDENTITY,head)
        var selected: int = layer.select_source(float(second),head,Basis.IDENTITY,0.0)
        if selected<0:
            missing += 1
        else:
            var present: Vector3 = Layer.object_center(selected,float(second),0.0)
            var future: Vector3 = Layer.object_center(selected,float(second)+6.0,1.0)
            check(Vector3.FORWARD.dot(present.normalized())>.87 and Vector3.FORWARD.dot(future.normalized())>.82, "Selected source remains in the forward view for six seconds")
        for index: int in range(128):
            for fill: float in [0.0,.5,1.0]:
                var center: Vector3 = Layer.object_center(index,float(second),fill)
                var w: float = fposmod(float(index)*.438579,1.0)
                var near: bool = fposmod(float(index)*.56984,1.0)<=.27
                var size: float = .24+w*.14 if near else .48+w*.56
                var extent: float = size*(1.0-fill*.40)*1.17*(1.0+fill*.075)
                check(Vector2(center.x,center.y).length()+extent <= 4.19*(1.0-fill*.40), "Complete moving objects remain inside the constricting tunnel")
    check(missing==0, "Every sampled breathing cycle has a visible source object")
    layer.reset_journey()
    layer.update_experience({"elapsed":32.0,"head_position":head,"head_basis":basis,"phase_seconds":0.0})
    var locked: int = layer._source_index
    for frame: int in range(270):
        layer.update_experience({"elapsed":32.0+float(frame)/60.0,"head_position":head,"head_basis":basis,"phase_seconds":float(frame)/60.0})
        check(layer._source_index==locked, "Plasma never switches source while visible")
    print("PRISMATIC JOURNEY: ", "PASS" if failures == 0 else "FAIL")
    layer.free()
    quit(failures)
