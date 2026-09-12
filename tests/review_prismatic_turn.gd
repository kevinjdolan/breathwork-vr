extends SceneTree
## Render an integrated 90-degree gaze change and the tunnel's delayed response.
func _initialize() -> void:
    run.call_deferred()

func capture(label: String) -> void:
    RenderingServer.force_draw(false,0)
    root.get_texture().get_image().save_png("res://verification/prism_turn_"+label+".png")

func run() -> void:
    root.set_meta("experience_id","prismatic_sanctuary")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    director.camera.get_parent().position.y = 1.4
    director.fade = 0.0
    director.elapsed = 32.0
    director.clock.update_from_position(0,32)
    director._push_visuals(0.016)
    capture("level")
    director.camera.rotation.x = PI/2
    for frame: int in range(961):
        director.elapsed = 32.0+frame/60.0
        director.clock.update_from_position(fposmod(director.elapsed,16),director.elapsed)
        director._push_visuals(1.0/60.0)
        if frame in [0,240,480,960]:
            await process_frame
            capture(str(frame/60))
        await process_frame
    quit()
