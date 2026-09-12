extends SceneTree
## Render plasma, full-hold light growth, outflow and the persistent destination core.
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
    for phase: float in [2.0,4.0,4.5,6.0,8.0,8.5,10.0,14.0]:
        director.elapsed = 32.0+phase
        director.clock.update_from_position(phase,director.elapsed)
        director._push_visuals(0.016)
        await process_frame
        RenderingServer.force_draw(false,0)
        root.get_texture().get_image().save_png("res://verification/breath_phase_%03d.png" % int(phase*10))
    quit()
