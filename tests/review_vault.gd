extends SceneTree
## Capture changing ornament in the complete scene and across the curved wall.
func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    root.set_meta("experience_id","prismatic_sanctuary")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    director.camera.get_parent().position.y = 1.4
    director.fade = 0.0
    for time: float in [34.0,112.0,260.0,400.0]:
        director.elapsed = time
        director.camera.rotation = Vector3.ZERO
        director.experience_layer.reset_journey()
        director.clock.update_from_position(2.0,time)
        director._push_visuals(.016)
        await process_frame
        RenderingServer.force_draw(false,0)
        root.get_texture().get_image().save_png("res://verification/vault_%d.png" % int(time))
        director.camera.rotation.y = PI/2.0
        await process_frame
        director._push_visuals(0.0)
        RenderingServer.force_draw(false,0)
        root.get_texture().get_image().save_png("res://verification/vault_side_%d.png" % int(time))
    quit()
