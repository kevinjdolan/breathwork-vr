extends SceneTree
## Render the actual session control and both seated/reclined confirmations.

func _initialize() -> void:
    run.call_deferred()

func capture(name: String) -> void:
    RenderingServer.force_draw(false, 0.0)
    root.get_texture().get_image().save_png("res://verification/" + name + ".png")

func run() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    director.camera.get_parent().position.y = 1.4
    director.elapsed = 30.0
    director.arc.seek(30.0, true)
    director.fade = 0.0
    director.breath_particles_enabled = 1.0
    director.clock.update_from_position(2.0, 30.0)
    for frame: int in range(90):
        director._follow_orb(1.0 / 60.0)
        director._push_visuals(1.0 / 60.0)
        await process_frame
    director.session_menu.available = true
    await create_timer(0.1).timeout
    capture("session_unobstructed")
    director.session_menu.open_menu()
    await create_timer(0.1).timeout
    capture("session_menu_confirmation")
    director.session_menu._activate(0)
    director.camera.rotation.x = deg_to_rad(80)
    director.session_menu.open_menu()
    await create_timer(0.1).timeout
    capture("session_menu_reclined")
    quit()
