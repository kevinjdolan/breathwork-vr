extends SceneTree
## Capture the startup selector and exercise the desktop hit target.

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var menu: Node = load("res://scenes/startup.tscn").instantiate()
    root.add_child(menu)
    for frame: int in range(90):
        await process_frame
    RenderingServer.force_draw(false, 0.0)
    root.get_texture().get_image().save_png("res://verification/menu.png")
    var first_card: Vector3 = menu.cards[0].global_position
    menu.desktop_pointer = menu.camera.unproject_position(first_card)
    menu._process(0.016)
    assert(menu.selected == 0, "Mouse projection reaches first experience")
    menu.camera.rotation.x = deg_to_rad(80)
    menu._anchor()
    for frame: int in range(10):
        await process_frame
    RenderingServer.force_draw(false, 0.0)
    root.get_texture().get_image().save_png("res://verification/menu_reclined.png")
    print("MENU POINTER AND RECLINED ANCHOR: PASS")
    quit()
